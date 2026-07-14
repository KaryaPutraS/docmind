# ============================================================
# DocMind — Settings API router
# ============================================================
import logging

from fastapi import APIRouter, HTTPException

from app.settings_store import (
    KNOWN_MODELS,
    get_settings,
    is_google_drive_configured,
    update_settings,
)
from app.settings_store import AppSettings, SettingsUpdate

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/settings", tags=["settings"])


@router.get("/", response_model=AppSettings)
def read_settings():
    """Return current runtime settings (API keys are truncated for display)."""
    s = get_settings()
    return s


@router.patch("/", response_model=AppSettings)
def patch_settings(patch: SettingsUpdate):
    """Update runtime settings. Only provide fields you want to change."""
    try:
        return update_settings(patch)
    except Exception as e:
        logger.exception("Failed to update settings")
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/status")
def system_status():
    """Return live status of all services."""
    from app.config import get_settings as get_env

    env = get_env()

    drive_ok = is_google_drive_configured()

    return {
        "api": "running",
        "postgres": "configured" if env.postgres_host else "not-configured",
        "google_drive": "connected" if drive_ok else "not-configured",
        "drive_credentials_set": drive_ok,
        "waha_webhook_secret_set": bool(env.waha_webhook_secret and env.waha_webhook_secret != "change_me"),
    }


@router.get("/providers")
def list_providers():
    """Return available AI providers and their models."""
    result = []
    for provider, models in KNOWN_MODELS.items():
        result.append({"id": provider, "name": provider.capitalize(), "models": models})
    return result


@router.get("/models")
def list_models(provider: str = "gemini"):
    """Return models for a specific AI provider."""
    models = KNOWN_MODELS.get(provider, [])
    return {"provider": provider, "models": models}
