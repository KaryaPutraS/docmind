# ============================================================
# DocMind — Dynamic Settings Store (backed by JSON file)
# Runtime settings that can be changed from the Flutter UI
# without redeploy. Separate from .env secrets.
# ============================================================
import json
import logging
import os
from pathlib import Path
from threading import Lock

from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)

SETTINGS_FILE = Path(os.getenv("DOCMIND_SETTINGS_FILE", "/data/settings.json"))

_lock = Lock()

# Default settings
_DEFAULTS = {
    "ai_provider": "gemini",
    "ai_model": "gemini-1.5-pro",
    "ai_temperature": 0.3,
    "ai_max_tokens": 2048,
    "waha_api_url": "http://localhost:3000",
    "waha_session": "default",
    "waha_polling_interval_seconds": 30,
    "waha_group_whitelist": [],
    "ocr_enabled": True,
    "ocr_keywords": [
        "Surat", "Laporan", "KTP", "NPWP", "Invoice", "Kwitansi",
        "Nota", "Kontrak", "SPK", "BAST", "Akta", "Sertifikat",
        "Ijazah", "Rekening", "Formulir",
    ],
    "ocr_language": "ind+eng",
    "storage_provider": "minio",
    "storage_bucket": "docmind-documents",
    "storage_endpoint": "localhost:9000",
    "storage_region": "us-east-1",
    "max_file_size_mb": 20,
    "allowed_mime_types": ["image/jpeg", "image/png", "image/webp", "application/pdf"],
    "notifications_enabled": True,
    "notifications_webhook_url": "",
}


# ── Pydantic schema for API ──────────────────────────────────

class AppSettings(BaseModel):
    ai_provider: str = "gemini"
    ai_model: str = "gemini-1.5-pro"
    ai_temperature: float = Field(default=0.3, ge=0.0, le=1.0)
    ai_max_tokens: int = Field(default=2048, ge=64, le=8192)
    waha_api_url: str = "http://localhost:3000"
    waha_session: str = "default"
    waha_polling_interval_seconds: int = Field(default=30, ge=5, le=300)
    waha_group_whitelist: list[str] = Field(default_factory=list)
    ocr_enabled: bool = True
    ocr_keywords: list[str] = Field(default_factory=list)
    ocr_language: str = "ind+eng"
    storage_provider: str = "minio"
    storage_bucket: str = "docmind-documents"
    storage_endpoint: str = "localhost:9000"
    storage_region: str = "us-east-1"
    max_file_size_mb: int = Field(default=20, ge=1, le=500)
    allowed_mime_types: list[str] = Field(default_factory=list)
    notifications_enabled: bool = True
    notifications_webhook_url: str = ""


class SettingsUpdate(BaseModel):
    """Partial update — only the fields provided will be changed."""
    ai_provider: str | None = None
    ai_model: str | None = None
    ai_temperature: float | None = Field(default=None, ge=0.0, le=1.0)
    ai_max_tokens: int | None = Field(default=None, ge=64, le=8192)
    waha_api_url: str | None = None
    waha_session: str | None = None
    waha_polling_interval_seconds: int | None = Field(default=None, ge=5, le=300)
    waha_group_whitelist: list[str] | None = None
    ocr_enabled: bool | None = None
    ocr_keywords: list[str] | None = None
    ocr_language: str | None = None
    storage_provider: str | None = None
    storage_bucket: str | None = None
    storage_endpoint: str | None = None
    storage_region: str | None = None
    max_file_size_mb: int | None = Field(default=None, ge=1, le=500)
    allowed_mime_types: list[str] | None = None
    notifications_enabled: bool | None = None
    notifications_webhook_url: str | None = None


# ── Persistence ──────────────────────────────────────────────

def _load_raw() -> dict:
    """Load settings from disk, merging with defaults for any missing keys."""
    if SETTINGS_FILE.exists():
        try:
            with open(SETTINGS_FILE, "r") as f:
                data = json.load(f)
        except (json.JSONDecodeError, OSError) as exc:
            logger.warning("Corrupted settings file, using defaults: %s", exc)
            data = {}
    else:
        data = {}

    merged = dict(_DEFAULTS)
    merged.update({k: v for k, v in data.items() if k in _DEFAULTS})
    return merged


def _save_raw(data: dict) -> None:
    SETTINGS_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(SETTINGS_FILE, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def get_settings() -> AppSettings:
    """Return current settings as a typed model."""
    with _lock:
        return AppSettings(**_load_raw())


def update_settings(patch: SettingsUpdate) -> AppSettings:
    """Apply a partial update and persist. Returns the new full settings."""
    with _lock:
        current = _load_raw()
        updates = patch.model_dump(exclude_none=True)
        current.update(updates)
        _save_raw(current)
    return AppSettings(**current)
