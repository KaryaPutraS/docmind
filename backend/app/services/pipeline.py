# ============================================================
# DocMind — Core pipeline orchestrator
# Called by the webhook router after validating the incoming message.
# Performs: download → OCR filter → AI classify → MinIO upload → DB write
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
from app.models import Document
from app.schemas import GeminiClassification, WAHAFile, WAHAMessage
from app.services.ai_service import classify_document, generate_embedding
from app.services.ocr_service import contains_keywords, ocr_extract

logger = logging.getLogger(__name__)
settings = get_settings()

# Allowed MIME types that this pipeline will process
ALLOWED_MIMES = {"image/jpeg", "image/png", "image/webp", "application/pdf"}

# Maximum file size in bytes (default: 20 MB)
MAX_FILE_SIZE = 20 * 1024 * 1024


def _sanitize_path_segment(segment: str) -> str:
    """Remove path traversal patterns and other unsafe chars from AI-generated paths."""
    # Strip leading/trailing whitespace and dots
    segment = segment.strip().strip(".")
    # Replace path traversal sequences
    segment = re.sub(r"\.{2,}", "", segment)
    # Replace any slash (Unix + Windows) with underscore — they'd create sub-keys
    segment = re.sub(r"[/\\]", "_", segment)
    # Collapse multiple underscores/spaces
    segment = re.sub(r"[_\s]+", "_", segment)
    # Strip leading/trailing underscores
    segment = segment.strip("_")
    # Limit segment length
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

    # ── 1. Triage: only accept certain file types ──────────────
    # TODO: Validate magic bytes against declared Content-Type for defense-in-depth.
    #       The current check relies on the MIME string alone, which a malicious
    #       WAHA instance (or MITM) could lie about.
    if mime not in ALLOWED_MIMES:
        return {"status": "skipped", "reason": f"unsupported-mime:{mime}"}

    # ── 2. Download the file from WAHA ─────────────────────────
    file_bytes = await _download_file(media.url)
    if file_bytes is None:
        return {"status": "error", "reason": "download-failed"}

    if len(file_bytes) > MAX_FILE_SIZE:
        logger.warning("File %s exceeds size limit (%d bytes)", media.filename, len(file_bytes))
        return {"status": "skipped", "reason": "file-too-large"}

    # ── 3. OCR & keyword filter ─────────────────────────────────
    ocr_text = ocr_extract(file_bytes, mime)
    if not contains_keywords(ocr_text):
        return {"status": "skipped", "reason": "no-keywords-matched"}

    # ── 4. AI classification (Gemini) ──────────────────────────
    classification = await classify_document(ocr_text, media.filename or "unknown")
    embedding = await generate_embedding(ocr_text[:4000] or classification.summary)

    # ── 5. Upload to storage ────────────────────────────────────
    ext = Path(media.filename or "doc").suffix or ".bin"

    # Sanitize AI-generated path segments to prevent traversal/pollution
    folder_segments = [
        _sanitize_path_segment(s) for s in classification.folder_structure.split("/")
    ]
    safe_folder = "/".join(s for s in folder_segments if s) or "Unsorted"
    safe_filename = _sanitize_path_segment(classification.new_filename)

    object_key = f"{safe_folder}/{safe_filename}"
    if not object_key.endswith(ext):
        object_key += ext

    # Write to temp file, explicitly closing the handle before upload
    # (required for Windows where open handles block subsequent file access)
    tmp = tempfile.NamedTemporaryFile(suffix=ext, delete=False)
    try:
        tmp.write(file_bytes)
        tmp.flush()
        tmp_path = tmp.name
    finally:
        tmp.close()

    try:
        provider, stored_ref = upload_file(tmp_path, object_key, content_type=mime)
    finally:
        Path(tmp_path).unlink(missing_ok=True)

    # ── 6. Persist metadata to PostgreSQL ──────────────────────
    doc = await _save_metadata(msg, media, ocr_text, classification, embedding, object_key, provider=provider)

    logger.info("Document processed: %s → %s", media.filename, classification.new_filename)
    return {"status": "processed", "document_id": str(doc.id)}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
async def _download_file(url: str | None) -> bytes | None:
    """Download file bytes from the WAHA media URL with a size limit."""
    if not url:
        return None
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.get(url)
            resp.raise_for_status()
            return resp.content
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
    provider: str = "minio",
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
                minio_bucket=env.minio_bucket,
                minio_object=object_key,
                storage_provider=provider,
                firebase_url=object_key if provider == "firebase" else None,
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
            # Already exists — fetch the existing row
            sel = select(Document).where(Document.wa_message_id == msg.id)
            result = await session.execute(sel)
            doc = result.scalar_one()

        await session.commit()
        return doc
