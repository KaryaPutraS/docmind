# ============================================================
# DocMind — Unified storage (Google Drive OR VPS SFTP)
# ============================================================
import logging

logger = logging.getLogger(__name__)

_client = None
_client_type = None  # "google_drive" | "vps"


def _get_provider():
    """Return the active storage provider string from runtime settings."""
    from app.settings_store import get_settings, is_google_drive_configured

    s = get_settings()
    provider = (s.storage_provider or "").lower()
    if provider == "google_drive" and is_google_drive_configured():
        return "google_drive"
    if provider == "vps" and s.vps_storage_host:
        return "vps"
    # Fallback: if Drive is configured, use it
    if is_google_drive_configured():
        return "google_drive"
    if s.vps_storage_host:
        return "vps"
    return provider or "vps"


def _get_client():
    global _client, _client_type
    provider = _get_provider()
    if _client is None or _client_type != provider:
        if provider == "google_drive":
            from app.google_drive_client import GoogleDriveClient
            _client = GoogleDriveClient.from_settings()
        else:
            from app.vps_storage_client import VpsStorageClient
            _client = VpsStorageClient.from_settings()
        _client_type = provider
        logger.info("Storage provider: %s", provider)
    return _client


def upload_file(
    local_path: str,
    object_name: str,
    content_type: str = "application/octet-stream",
) -> str:
    """
    Upload a file to the active storage backend.
    Returns: file_id (Drive) or public URL (VPS).
    """
    client = _get_client()
    return client.upload_file(local_path, object_name, content_type)


def get_download_url(file_id: str) -> str:
    """Get a direct download URL for a stored file."""
    client = _get_client()
    return client.get_download_url(file_id)


def is_vps_storage() -> bool:
    return _get_provider() == "vps"


def is_google_drive_storage() -> bool:
    return _get_provider() == "google_drive"
