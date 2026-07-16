# ============================================================
# DocMind — Dynamic Settings Store (backed by JSON file)
# Google Drive ONLY storage. No MinIO, no S3, no Firebase.
# ============================================================
import json
import logging
import os
from pathlib import Path
from threading import Lock

from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)

SETTINGS_FILE = Path(os.getenv("DOCMIND_SETTINGS_FILE", "/app/data/docmind_settings.json"))

_lock = Lock()

# ── Known provider → models mapping ─────────────────────────
KNOWN_MODELS = {
    "gemini": [
        "gemini-2.5-flash", "gemini-2.5-pro",
        "gemini-2.0-flash", "gemini-1.5-pro",
        "gemini-1.5-flash", "gemini-1.5-flash-8b",
    ],
    "openai": [
        "gpt-4o", "gpt-4o-mini", "gpt-4.1",
        "gpt-4.1-mini", "o4-mini", "o3-mini",
    ],
    "groq": [
        "llama-4-scout-17b-16e-instruct",
        "llama-4-maverick-17b-128e-instruct",
        "llama-3.3-70b-versatile",
        "deepseek-r1-distill-llama-70b",
        "qwen-2.5-32b", "mixtral-8x7b-32768",
    ],
    "anthropic": [
        "claude-sonnet-4-20250514",
        "claude-3-5-sonnet-20241022",
        "claude-3-5-haiku-20241022",
        "claude-3-opus-20240229",
    ],
    "deepseek": [
        "deepseek-chat", "deepseek-reasoner",
    ],
}

_DEFAULTS = {
    # ── AI ─────────────────────────────────────────
    "ai_provider": "gemini",
    "ai_model": "gemini-1.5-pro",
    "ai_api_key": "",
    "ai_temperature": 0.3,
    "ai_max_tokens": 2048,
    # ── WAHA ───────────────────────────────────────
    "waha_api_url": "http://localhost:3000",
    "waha_api_key": "",
    "waha_webhook_secret": "change_me",
    "waha_hmac_enabled": True,
    "waha_session": "default",
    "waha_polling_interval_seconds": 30,
    "waha_group_whitelist": [],
    # ── OCR ────────────────────────────────────────
    "ocr_enabled": True,
    "ocr_keywords": [
        "Surat", "Laporan", "KTP", "NPWP", "Invoice", "Kwitansi",
        "Nota", "Kontrak", "SPK", "BAST", "Akta", "Sertifikat",
        "Ijazah", "Rekening", "Formulir",
    ],
    "ocr_language": "ind+eng",
    # ── Storage ─────────────────────────────────────
    "storage_provider": "vps",  # vps | google_drive
    "google_drive_credentials_json": {},
    "google_drive_folder_id": "root",
    "vps_storage_host": "",  # kosong = local storage di /app/uploads/
    "vps_storage_port": 22,
    "vps_storage_username": "",
    "vps_storage_password": "",
    "vps_storage_base_path": "/app/uploads",
    "vps_storage_public_base_url": "http://43.156.71.166/uploads",
    # ── General ────────────────────────────────────
    "max_file_size_mb": 20,
    "allowed_mime_types": ["image/jpeg", "image/png", "image/webp", "application/pdf"],
    "notifications_enabled": True,
    "notifications_webhook_url": "",
}


# ── Pydantic schemas ────────────────────────────────────────

class AppSettings(BaseModel):
    # AI
    ai_provider: str = "gemini"
    ai_model: str = "gemini-1.5-pro"
    ai_api_key: str = ""
    ai_temperature: float = Field(default=0.3, ge=0.0, le=1.0)
    ai_max_tokens: int = Field(default=2048, ge=64, le=8192)
    # WAHA
    waha_api_url: str = "http://localhost:3000"
    waha_api_key: str = ""
    waha_webhook_secret: str = "change_me"
    waha_hmac_enabled: bool = True
    waha_session: str = "default"
    waha_polling_interval_seconds: int = Field(default=30, ge=5, le=300)
    waha_group_whitelist: list[str] = Field(default_factory=list)
    # OCR
    ocr_enabled: bool = True
    ocr_keywords: list[str] = Field(default_factory=list)
    ocr_language: str = "ind+eng"
    # Google Drive
    storage_provider: str = "vps"
    google_drive_credentials_json: dict | str = Field(default_factory=dict)
    google_drive_folder_id: str = "root"
    # VPS SFTP Storage
    vps_storage_host: str = ""
    vps_storage_port: int = Field(default=22, ge=1, le=65535)
    vps_storage_username: str = ""
    vps_storage_password: str = ""
    vps_storage_base_path: str = "/home/magang/docmind_uploads"
    vps_storage_public_base_url: str = "https://magang.vpsmso.site/docmind_uploads"
    # General
    max_file_size_mb: int = Field(default=20, ge=1, le=500)
    allowed_mime_types: list[str] = Field(default_factory=list)
    notifications_enabled: bool = True
    notifications_webhook_url: str = ""


class SettingsUpdate(BaseModel):
    ai_provider: str | None = None
    ai_model: str | None = None
    ai_api_key: str | None = None
    ai_temperature: float | None = Field(default=None, ge=0.0, le=1.0)
    ai_max_tokens: int | None = Field(default=None, ge=64, le=8192)
    waha_api_url: str | None = None
    waha_api_key: str | None = None
    waha_webhook_secret: str | None = None
    waha_hmac_enabled: bool | None = None
    waha_session: str | None = None
    waha_polling_interval_seconds: int | None = Field(default=None, ge=5, le=300)
    waha_group_whitelist: list[str] | None = None
    ocr_enabled: bool | None = None
    ocr_keywords: list[str] | None = None
    ocr_language: str | None = None
    google_drive_credentials_json: dict | str | None = None
    google_drive_folder_id: str | None = None
    storage_provider: str | None = None
    vps_storage_host: str | None = None
    vps_storage_port: int | None = Field(default=None, ge=1, le=65535)
    vps_storage_username: str | None = None
    vps_storage_password: str | None = None
    vps_storage_base_path: str | None = None
    vps_storage_public_base_url: str | None = None
    max_file_size_mb: int | None = Field(default=None, ge=1, le=500)
    allowed_mime_types: list[str] | None = None
    notifications_enabled: bool | None = None
    notifications_webhook_url: str | None = None


# ── Persistence ──────────────────────────────────────────────

def _load_raw() -> dict:
    if SETTINGS_FILE.exists():
        try:
            with open(SETTINGS_FILE, "r") as f:
                data = json.load(f)
        except (json.JSONDecodeError, OSError) as exc:
            logger.warning("Corrupted settings file, using defaults: %s", exc)
            data = {}
    else:
        # First boot — create settings file with defaults
        data = {}
        logger.info("Settings file not found at %s, creating with defaults", SETTINGS_FILE)
        try:
            _save_raw(dict(_DEFAULTS))
        except OSError as exc:
            logger.warning("Could not create settings file: %s — using in-memory defaults", exc)
    merged = dict(_DEFAULTS)
    # Only merge keys that exist in defaults (ignore stale keys from old versions)
    merged.update({k: v for k, v in data.items() if k in _DEFAULTS})
    return merged


def _save_raw(data: dict) -> None:
    SETTINGS_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(SETTINGS_FILE, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def get_settings() -> AppSettings:
    with _lock:
        return AppSettings(**_load_raw())


def update_settings(patch: SettingsUpdate) -> AppSettings:
    with _lock:
        current = _load_raw()
        updates = patch.model_dump(exclude_none=True)
        
        # Auto-parse Google Drive credentials if provided as a string
        if "google_drive_credentials_json" in updates and isinstance(updates["google_drive_credentials_json"], str):
            creds_str = updates["google_drive_credentials_json"].strip()
            if creds_str:
                try:
                    # strict=False allows unescaped newlines in string values (e.g., in private_key)
                    updates["google_drive_credentials_json"] = json.loads(creds_str, strict=False)
                except Exception as e:
                    logger.warning("Failed to parse google_drive_credentials_json: %s", e)
                    
        current.update(updates)
        _save_raw(current)
    return AppSettings(**current)


def get_ai_api_key() -> str:
    settings = get_settings()
    return settings.ai_api_key or os.getenv("GEMINI_API_KEY", "")


def get_waha_api_key() -> str:
    settings = get_settings()
    return settings.waha_api_key or os.getenv("WAHA_API_KEY", "")


def is_google_drive_configured() -> bool:
    """Check if Google Drive credentials are actually set."""
    settings = get_settings()
    creds = settings.google_drive_credentials_json
    if isinstance(creds, str):
        try:
            creds = json.loads(creds, strict=False)
        except (json.JSONDecodeError, TypeError):
            return False
    if not creds:
        return False
    # Must have at minimum: type, project_id, private_key, client_email
    required = ("type", "project_id", "private_key", "client_email")
    if isinstance(creds, dict):
        return all(creds.get(k) for k in required)
    return False
