# ============================================================
# DocMind — Webhook router (WAHA → pipeline trigger)
#
# SECURITY NOTES:
# 1. HMAC signature verification is SKIPPED when WAHA_WEBHOOK_SECRET
#    is unset or set to "change_me" — this is intentional for local
#    development. Set a strong random secret in production and
#    configure the same value in WAHA's WEBHOOK_SECRET.
# 2. No rate limiting is applied. An attacker who bypasses (or skips)
#    the HMAC check can flood this endpoint with fake payloads.
#    TODO: Add slowapi or similar rate limiting (e.g. 30 req/min per IP).
# 3. There is no authentication beyond the optional HMAC signature.
#    TODO(auth): Consider API-key or mTLS for the webhook endpoint.
# ============================================================
import hmac
import logging
from hashlib import sha256

from fastapi import APIRouter, BackgroundTasks, Header, HTTPException, Request

from app.schemas import WAHAWebhook, WAHAFile
from app.services.pipeline import process_document
from app.settings_store import get_settings as get_dynamic_settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/webhook", tags=["webhook"])


async def _background_with_logging(msg, media):
    """Wrapper around process_document that logs and never raises.

    IMPORTANT: FastAPI/Starlette already runs async background callables on the
    active event loop. Do not call asyncio.run() here; it creates a second loop
    and asyncpg crashes with 'Future attached to a different loop'.
    """
    try:
        return await process_document(msg, media)
    except Exception:
        logger.exception("Unhandled error in background document processing")
        return None


def _verify_signature(body: bytes, signature: str | None) -> bool:
    """Verify the `X-Waha-Signature` header against the shared secret.

    Returns True when:
    - HMAC is explicitly disabled (waha_hmac_enabled=False)
    - Secret is unset or still the default 'change_me'
    - The provided signature matches the computed HMAC

    Returns False only when HMAC is enabled AND a non-default secret
    is set AND the signature doesn't match.
    """
    settings = get_dynamic_settings()
    
    # User explicitly disabled HMAC verification
    if not settings.waha_hmac_enabled:
        return True
    
    secret = settings.waha_webhook_secret
    # Default/empty secret = dev mode, skip verification
    if not secret or secret == "change_me":
        return True
    
    # Secret is set and HMAC enabled — require matching signature
    if not signature:
        return False
    expected = hmac.new(
        secret.encode(), body, sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature)


@router.post("/waha")
async def waha_webhook(
    request: Request,
    background: BackgroundTasks,
    x_waha_signature: str | None = Header(None, alias="X-Waha-Signature"),
):
    """
    Endpoint that WAHA POSTs to when a new WhatsApp message arrives.

    The pipeline runs in the background (non-blocking) so WAHA receives
    an immediate 200 OK; real processing happens asynchronously.
    """
    body = await request.body()

    if not _verify_signature(body, x_waha_signature):
        raise HTTPException(status_code=401, detail="invalid-signature")

    try:
        webhook = WAHAWebhook.model_validate_json(body)
    except Exception as exc:
        logger.warning("Malformed webhook payload: %s", exc)
        raise HTTPException(status_code=400, detail="invalid-payload")

    msg = webhook.get_message()
    if msg is None:
        logger.warning("Could not extract message from webhook payload")
        raise HTTPException(status_code=400, detail="invalid-payload")

    has_media = msg.hasMedia or (msg.type in ("image", "document", "video", "audio", "ptt", "documentMessage"))
    logger.info(
        "WAHA webhook received: event=%s session=%s msg=%s chat=%s type=%s has_media=%s media_url=%s",
        webhook.event,
        webhook.session,
        msg.id,
        msg.chatId,
        msg.type,
        has_media,
        bool(msg.media and msg.media.url),
    )
    if not msg.media and not has_media:
        logger.info("WAHA message %s ignored: no media", msg.id)
        return {"status": "ignored", "reason": "no-media"}

    media_obj = msg.media or WAHAFile()
    background.add_task(_background_with_logging, msg, media_obj)

    return {"status": "accepted", "message_id": msg.id}
