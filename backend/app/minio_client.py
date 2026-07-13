# ============================================================
# DocMind — Unified storage (Google Drive ONLY)
# Replaces minio_client.py — single backend, clean interface.
# ============================================================
import logging

logger = logging.getLogger(__name__)

_google_drive_client = None


def _get_client():
    """Lazy-init the Google Drive client from runtime settings."""
    global _google_drive_client
    if _google_drive_client is None:
        from app.google_drive_client import GoogleDriveClient
        _google_drive_client = GoogleDriveClient.from_settings()
    return _google_drive_client


def upload_file(
    local_path: str,
    object_name: str,
    content_type: str = "application/octet-stream",
) -> str:
    """
    Upload a file to Google Drive.
    Returns the Drive file ID.
    """
    client = _get_client()
    return client.upload_file(local_path, object_name, content_type)


def get_download_url(file_id: str) -> str:
    """Get a direct download URL for a Drive file."""
    client = _get_client()
    return client.get_download_url(file_id)
