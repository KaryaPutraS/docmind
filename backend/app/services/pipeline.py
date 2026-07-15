# ============================================================
# DocMind — Core pipeline orchestrator
# Called by the webhook router after validating the incoming message.
# Performs: download → OCR filter → AI classify → Google Drive upload → DB write
# ============================================================
import logging
import re
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path

import httpx
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.config import get_settings
from app.database import AsyncSessionLocal
from app.minio_client import upload_file, get_download_url
# Google Drive is the only storage backend; minio_client.py wraps it for
# backward-compatible import naming.
from app.models import Document
from app.schemas import GeminiClassification, WAHAFile, WAHAMessage
from app.services.ai_service import classify_document, generate_embedding
from app.services.ocr_service import contains_keywords, ocr_extract
from app.settings_store import get_settings as get_dynamic_settings, get_waha_api_key

logger = logging.getLogger(__name__)
config = get_settings()  # env-based config (database, secrets, etc.)

# Allowed MIME types that this pipeline will process
ALLOWED_MIMES = {"image/jpeg", "image/png", "image/webp", "application/pdf"}


def _sanitize_path_segment(segment: str) -> str:
    """Remove path traversal patterns and other unsafe chars from AI-generated paths."""
    segment = segment.strip().strip(".")
    segment = re.sub(r"\.{2,}", "", segment)
    segment = re.sub(r"[/\\]", "_", segment)
    segment = re.sub(r"[_\s]+", "_", segment)
    segment = segment.strip("_")
    if len(segment) > 100:
        segment = segment[:100]
    return segment or "unknown"


# ---------------------------------------------------------------------------
# Pipeline entry point
# ---------------------------------------------------------------------------
async def process_document(msg: WAHAMessage, media: WAHAFile) -> dict:
    """
    Run the full document pipeline for a single WhatsApp message.

    Returns a dict with status and document_id for the API response.
    """
    mime = (media.mimetype or msg.type or "").lower()

    async def reply(text: str):
        await _send_waha_reply(msg.chatId, text, reply_to=msg.id)

    # ── 1. Triage ──────────────────────────────────────
    # Allow generic types to pass triage, we will re-verify after download
    if mime not in ALLOWED_MIMES and mime not in ("image", "document", "documentmessage", "video", "audio", "ptt", ""):
        await reply(f"❌ Dokumen diabaikan karena tipe file tidak didukung ({mime}).")
        return {"status": "skipped", "reason": f"unsupported-mime:{mime}"}

    await reply("⏳ File diterima. Memulai pengunduhan...")

    # ── 2. Download the file from WAHA ─────────────────
    download_result = await _download_file(msg.id, media.url)
    if download_result is None:
        await reply("❌ Gagal mengunduh file dari server WAHA.")
        return {"status": "error", "reason": "download-failed"}
        
    file_bytes, fetched_mime = download_result
    
    if not media.mimetype and fetched_mime:
        mime = fetched_mime.split(";")[0].strip().lower()
        media.mimetype = mime
        
    if mime not in ALLOWED_MIMES:
        await reply(f"❌ File diabaikan setelah diunduh karena tipe tidak didukung ({mime}).")
        return {"status": "skipped", "reason": f"unsupported-mime-after-download:{mime}"}

    dyn = get_dynamic_settings()
    max_size = dyn.max_file_size_mb * 1024 * 1024
    if len(file_bytes) > max_size:
        logger.warning("File %s exceeds size limit (%d bytes)", media.filename, len(file_bytes))
        await reply("❌ File ditolak karena ukurannya terlalu besar.")
        return {"status": "skipped", "reason": "file-too-large"}

    # ── 3. OCR & keyword filter ────────────────────────
    await reply("⏳ Mengurai isi dokumen (OCR)...")
    ocr_text = ocr_extract(file_bytes, mime)
    is_image = mime.startswith("image/")
    
    if is_image and dyn.ocr_enabled and dyn.ocr_keywords:
        if not contains_keywords(ocr_text, keywords=dyn.ocr_keywords):
            await reply("❌ Gambar tidak relevan (tidak mengandung kata kunci surat/dokumen).")
            return {"status": "skipped", "reason": "no-keywords-matched"}

    # ── 4. AI classification ──────────────────────────
    await reply("⏳ Meminta AI Gemini untuk menganalisis dan mengategorikan...")
    classification = await classify_document(
        ocr_text,
        media.filename or "unknown"
    )
    embedding = await generate_embedding(
        ocr_text[:4000] or classification.summary,
        provider=dyn.ai_provider,
        api_key=dyn.ai_api_key,
    )

    # ── 5. Upload to Google Drive ──────────────────────
    ext = Path(media.filename or "doc").suffix or ".bin"

    folder_segments = [
        _sanitize_path_segment(s) for s in classification.folder_structure.split("/")
    ]
    safe_folder = "/".join(s for s in folder_segments if s) or "Unsorted"
    safe_filename = _sanitize_path_segment(classification.new_filename)

    object_key = f"{safe_folder}/{safe_filename}"
    if not object_key.endswith(ext):
        object_key += ext

    tmp = tempfile.NamedTemporaryFile(suffix=ext, delete=False)
    try:
        tmp.write(file_bytes)
        tmp.flush()
        tmp_path = tmp.name
    finally:
        tmp.close()

    try:
        drive_file_id = upload_file(tmp_path, object_key, content_type=mime)
    finally:
        Path(tmp_path).unlink(missing_ok=True)

    # ── 6. Persist metadata ────────────────────────────
    doc = await _save_metadata(msg, media, ocr_text, classification, embedding, object_key, drive_file_id=drive_file_id)

    logger.info("Document processed: %s → %s", media.filename, classification.new_filename)
    await reply(f"✅ Berhasil diproses!\n📂 Kategori: {classification.category}\n📄 Disimpan sebagai: {classification.new_filename}")
    return {"status": "processed", "document_id": str(doc.id)}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
async def _send_waha_reply(chat_id: str, text: str, reply_to: str | None = None):
    dyn = get_dynamic_settings()
    base_url = dyn.waha_api_url.rstrip("/")
    session = dyn.waha_session
    api_key = get_waha_api_key()
    
    url = f"{base_url}/api/sendText"
    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["X-Api-Key"] = api_key
        
    payload = {"session": session, "chatId": chat_id, "text": text}
    if reply_to:
        payload["reply_to"] = reply_to
        
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            await client.post(url, json=payload, headers=headers)
    except Exception as e:
        logger.warning(f"Failed to send WAHA reply: {e}")

async def _download_file(msg_id: str, url: str | None) -> tuple[bytes, str | None] | None:
    """Download file bytes from the WAHA media URL with a size limit."""
    dyn_settings = get_dynamic_settings()
    if not url:
        base_url = dyn_settings.waha_api_url.rstrip("/")
        session_name = dyn_settings.waha_session
        url = f"{base_url}/api/{session_name}/messages/{msg_id}/download"

    headers = {}
    api_key = get_waha_api_key()
    if api_key:
        headers["X-Api-Key"] = api_key

    # Rewrite localhost URLs using the configured WAHA API URL
    if url and ("localhost" in url or "127.0.0.1" in url):
        try:
            from urllib.parse import urlparse, urlunparse
            base_url = dyn_settings.waha_api_url.rstrip("/")
            parsed = urlparse(url)
            if parsed.hostname in ("localhost", "127.0.0.1"):
                base_parsed = urlparse(base_url)
                url = urlunparse(parsed._replace(
                    netloc=base_parsed.netloc,
                    scheme=base_parsed.scheme,
                ))
        except Exception:
            pass

    # If waha_internal_host is configured, rewrite the download URL
    if config.waha_internal_host:
        base = config.waha_internal_host.rstrip("/")
        try:
            from urllib.parse import urlparse, urlunparse
            parsed = urlparse(url)
            url = urlunparse(parsed._replace(
                netloc=base.replace("http://", "").replace("https://", ""),
                scheme=base.split("://")[0] if "://" in base else parsed.scheme,
            ))
        except Exception:
            pass
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.get(url, headers=headers)
            resp.raise_for_status()
            return resp.content, resp.headers.get("content-type")
    except Exception as exc:
        logger.error("Download failed from %s: %s", url, exc)
        return None


async def _save_metadata(
    msg: WAHAMessage,
    media: WAHAFile,
    ocr_text: str,
    classification: "GeminiClassification",
    embedding: list[float],
    object_key: str,
    drive_file_id: str = "",
) -> Document:
    """Insert (or upsert on wa_message_id) a document row."""
    async with AsyncSessionLocal() as session:
        stmt = (
            pg_insert(Document)
            .values(
                id=uuid.uuid4(),
                wa_message_id=msg.id,
                wa_chat_id=msg.chatId,
                wa_sender=msg.from_,
                original_filename=media.filename or "unknown",
                new_filename=classification.new_filename,
                category=classification.category,
                folder_path=classification.folder_structure,
                mime_type=media.mimetype,
                file_size=media.size,
                minio_object=object_key,
                drive_file_id=drive_file_id,
                ocr_text=ocr_text,
                ai_summary=classification.summary,
                ai_metadata=classification.model_dump(),
                embedding=embedding if embedding else None,
                processed_at=datetime.now(timezone.utc),
            )
            .on_conflict_do_nothing(constraint="idx_documents_wa_msg")
            .returning(Document)
        )
        result = await session.execute(stmt)
        doc = result.scalar_one_or_none()

        if doc is None:
            sel = select(Document).where(Document.wa_message_id == msg.id)
            result = await session.execute(sel)
            doc = result.scalar_one()

        await session.commit()
        return doc
