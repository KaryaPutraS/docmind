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
import asyncio
import hmac
import logging
from hashlib import sha256

from fastapi import APIRouter, BackgroundTasks, Header, HTTPException, Request

from app.config import get_settings
from app.schemas import WAHAWebhook
from app.services.pipeline import process_document

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/webhook", tags=["webhook"])
settings = get_settings()


def _background_with_logging(msg, media):
    """Wrapper around process_document that logs and never raises."""
    try:
        return asyncio.run(process_document(msg, media))
    except Exception:
        logger.exception("Unhandled error in background document processing")
        return None


def _verify_signature(body: bytes, signature: str | None) -> bool:
    """Verify the `X-Waha-Signature` header against the shared secret.

    Returns True (skip verification) when WAHA_WEBHOOK_SECRET is unset
    or set to the default 'change_me' — this is intentionally permissive
    for local development. Set a strong random secret for production use.
    """
    if not settings.waha_webhook_secret or settings.waha_webhook_secret == "change_me":
        return True  # DEVELOPMENT ONLY — skip signature verification
    if not signature:
        return False
    expected = hmac.new(
        settings.waha_webhook_secret.encode(), body, sha256
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

    # Optional signature check
    if not _verify_signature(body, x_waha_signature):
        raise HTTPException(status_code=401, detail="invalid-signature")

    # Parse the webhook payload
    try:
        webhook = WAHAWebhook.model_validate_json(body)
    except Exception as exc:
        logger.warning("Malformed webhook payload: %s", exc)
        raise HTTPException(status_code=400, detail="invalid-payload")

    msg = webhook.payload

    # Only process messages that carry a file attachment
    if not msg.media or not msg.media.url:
        logger.debug("Message %s has no media — ignoring", msg.id)
        return {"status": "ignored", "reason": "no-media"}

    # Fire-and-forget: process in the background with error logging
    background.add_task(_background_with_logging, msg, msg.media)

    return {"status": "accepted", "message_id": msg.id}
