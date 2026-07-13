# ============================================================
# DocMind — Settings API router (for Flutter settings screen)
# ============================================================
import logging

from fastapi import APIRouter, HTTPException

from app.settings_store import (
    AppSettings,
    SettingsUpdate,
    get_settings,
    update_settings,
)
from app.config import get_settings as get_env_settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/settings", tags=["settings"])


@router.get("/", response_model=AppSettings)
async def read_settings():
    """Return all current app settings."""
    return get_settings()


@router.patch("/", response_model=AppSettings)
async def patch_settings(body: SettingsUpdate):
    """Update one or more settings fields. Returns the full updated settings."""
    try:
        return update_settings(body)
    except Exception as exc:
        logger.error("Failed to update settings: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc))


@router.get("/status", response_model=dict)
async def system_status():
    """Quick health + connection status for the dashboard."""
    env = get_env_settings()

    status = {
        "api": "running",
        "gemini_configured": bool(env.gemini_api_key),
        "minio_endpoint": env.minio_endpoint,
        "minio_bucket": env.minio_bucket,
        "postgres_host": env.postgres_host,
        "waha_webhook_secret_set": env.waha_webhook_secret not in ("", "change_me"),
    }

    # Try a quick DB ping
    try:
        from app.database import engine
        async with engine.connect() as conn:
            await conn.execute("SELECT 1")
        status["postgres"] = "connected"
    except Exception:
        status["postgres"] = "disconnected"

    # Try MinIO ping
    try:
        from app.minio_client import get_minio_client
        client = get_minio_client()
        client.list_buckets()
        status["minio"] = "connected"
    except Exception:
        status["minio"] = "disconnected"

    return status
