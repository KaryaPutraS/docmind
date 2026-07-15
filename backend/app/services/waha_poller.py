# ============================================================
# DocMind — WAHA polling fallback
#
# Webhook dari WAHA sering gagal/terlambat karena konfigurasi dashboard,
# proxy, atau signature. Poller ini membuat DocMind tetap bisa mendeteksi
# foto/file WhatsApp dengan menarik pesan terbaru langsung dari WAHA API.
# ============================================================
import asyncio
import logging
from typing import Any

import httpx

from app.schemas import WAHAFile, WAHAMessage
from app.services.pipeline import process_document
from app.settings_store import get_settings, get_waha_api_key

logger = logging.getLogger(__name__)

_processed_message_ids: set[str] = set()
_running = False


def _headers() -> dict[str, str]:
    key = get_waha_api_key()
    headers = {"Accept": "application/json"}
    if key:
        headers["X-Api-Key"] = key
    return headers


def _media_from_message(msg: dict[str, Any]) -> WAHAFile | None:
    media = msg.get("media") if isinstance(msg.get("media"), dict) else None
    data = msg.get("_data") if isinstance(msg.get("_data"), dict) else {}
    media_data = media.get("_data") if isinstance(media, dict) and isinstance(media.get("_data"), dict) else {}

    url = None
    if media:
        url = media.get("url") or media.get("downloadUrl") or media.get("link")
    url = url or data.get("mediaUrl") or data.get("deprecatedMms3Url") or media_data.get("url")

    mimetype = None
    if media:
        mimetype = media.get("mimetype") or media.get("mimeType")
    mimetype = mimetype or data.get("mimetype") or data.get("MimeType") or data.get("mediaType")

    filename = None
    if media:
        filename = media.get("filename") or media.get("fileName")
    filename = filename or data.get("filename") or data.get("FileName")

    size = None
    if media:
        size = media.get("size") or media.get("fileSize")
    size = size or data.get("size") or data.get("fileSize")

    if not (url or mimetype or filename):
        return None
    return WAHAFile(mimetype=mimetype, filename=filename, url=url, size=size)


def _message_from_raw(raw: dict[str, Any], chat_id: str | None = None) -> tuple[WAHAMessage, WAHAFile | None, bool]:
    data = raw.get("_data") if isinstance(raw.get("_data"), dict) else {}
    msg_id = raw.get("id") or data.get("id") or raw.get("key", {}).get("id") or "unknown"
    resolved_chat = raw.get("chatId") or raw.get("from") or chat_id or data.get("remote") or data.get("chatId") or "unknown"
    sender = raw.get("from") or data.get("notifyName") or data.get("author") or "unknown"
    msg_type = (raw.get("type") or data.get("type") or data.get("MediaType") or "").lower()
    has_media = bool(raw.get("hasMedia") or data.get("hasMedia") or msg_type in {"image", "document", "video", "audio", "ptt"})
    media = _media_from_message(raw)

    if media and not media.filename:
        ext = "bin"
        if media.mimetype:
            ext = media.mimetype.split("/")[-1].split(";")[0].replace("jpeg", "jpg")
        media.filename = f"wa_{msg_id}.{ext}"
    if media and not media.mimetype and msg_type == "image":
        media.mimetype = "image/jpeg"

    return WAHAMessage(
        id=str(msg_id),
        from_=str(sender),
        chatId=str(resolved_chat),
        body=raw.get("body") or raw.get("caption") or data.get("body") or "",
        type=msg_type,
        hasMedia=has_media,
        media=media,
        timestamp=raw.get("timestamp") or data.get("t"),
    ), media, has_media


async def _fetch_json(client: httpx.AsyncClient, url: str) -> Any | None:
    try:
        resp = await client.get(url, headers=_headers())
        if resp.status_code in (401, 403):
            logger.warning("WAHA API unauthorized [%s] for %s — cek WAHA API key di Settings", resp.status_code, url)
            return None
        resp.raise_for_status()
        return resp.json()
    except Exception as exc:
        logger.warning("WAHA poll request failed %s: %s", url, exc)
        return None


async def _list_chats(client: httpx.AsyncClient, base: str, session: str) -> list[dict[str, Any]]:
    urls = [
        f"{base}/api/{session}/chats?limit=50",
        f"{base}/api/chats?session={session}&limit=50",
    ]
    for url in urls:
        data = await _fetch_json(client, url)
        if isinstance(data, list):
            return data
        if isinstance(data, dict):
            for key in ("data", "chats", "items"):
                if isinstance(data.get(key), list):
                    return data[key]
    return []


async def _list_messages(client: httpx.AsyncClient, base: str, session: str, chat_id: str) -> list[dict[str, Any]]:
    urls = [
        f"{base}/api/{session}/chats/{chat_id}/messages?limit=20",
        f"{base}/api/messages?session={session}&chatId={chat_id}&limit=20",
    ]
    for url in urls:
        data = await _fetch_json(client, url)
        if isinstance(data, list):
            return data
        if isinstance(data, dict):
            for key in ("data", "messages", "items"):
                if isinstance(data.get(key), list):
                    return data[key]
    return []


async def poll_once() -> int:
    settings = get_settings()
    base = settings.waha_api_url.rstrip("/")
    session = settings.waha_session or "default"
    if not base:
        return 0

    processed = 0
    async with httpx.AsyncClient(timeout=25.0) as client:
        chats = await _list_chats(client, base, session)
        if not chats:
            logger.debug("WAHA poll: no chats returned")
            return 0

        whitelist = set(settings.waha_group_whitelist or [])
        for chat in chats:
            chat_id = chat.get("id") or chat.get("chatId") or chat.get("_id")
            if isinstance(chat.get("_data"), dict):
                chat_id = chat_id or chat["_data"].get("id")
            if not chat_id:
                continue
            chat_id = str(chat_id)
            # Fokus grup, kecuali user memakai whitelist eksplisit.
            if whitelist and chat_id not in whitelist:
                continue
            if not whitelist and not chat_id.endswith("@g.us"):
                continue

            for raw in await _list_messages(client, base, session, chat_id):
                msg, media, has_media = _message_from_raw(raw, chat_id=chat_id)
                if msg.id in _processed_message_ids:
                    continue
                if not has_media and media is None:
                    _processed_message_ids.add(msg.id)
                    continue
                _processed_message_ids.add(msg.id)
                logger.info("WAHA poll detected media message %s from chat %s", msg.id, msg.chatId)
                asyncio.create_task(process_document(msg, media or WAHAFile()))
                processed += 1
    return processed


async def run_poller() -> None:
    global _running
    if _running:
        return
    _running = True
    logger.info("WAHA poller started")
    while True:
        try:
            settings = get_settings()
            interval = max(10, int(settings.waha_polling_interval_seconds or 30))
            await poll_once()
            await asyncio.sleep(interval)
        except asyncio.CancelledError:
            logger.info("WAHA poller stopped")
            raise
        except Exception:
            logger.exception("WAHA poller loop error")
            await asyncio.sleep(30)


def processed_cache_size() -> int:
    return len(_processed_message_ids)


def clear_processed_cache() -> None:
    _processed_message_ids.clear()
