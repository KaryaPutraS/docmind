# ============================================================
# DocMind — Unified storage uploader
# Routes to MinIO, S3, or Firebase depending on runtime settings.
# ============================================================
import logging

from app.config import get_settings as get_env_settings
from app.settings_store import get_settings as get_runtime_settings

logger = logging.getLogger(__name__)
env = get_env_settings()

# MinIO client — lazy init
_minio_client = None


def _get_minio():
    global _minio_client
    if _minio_client is None:
        from minio import Minio
        _minio_client = Minio(
            endpoint=env.minio_endpoint,
            access_key=env.minio_root_user,
            secret_key=env.minio_root_password,
            secure=env.minio_secure,
        )
        if not _minio_client.bucket_exists(env.minio_bucket):
            _minio_client.make_bucket(env.minio_bucket)
            logger.info("Created MinIO bucket '%s'", env.minio_bucket)
    return _minio_client


def get_minio_client():
    """Return the MinIO client (for health checks, etc)."""
    return _get_minio()


# ── Unified upload ──────────────────────────────────────────

def upload_file(
    local_path: str,
    object_name: str,
    content_type: str = "application/octet-stream",
) -> tuple[str, str]:
    """
    Upload a file to the configured storage backend.

    Returns (provider, object_key_or_url).
    - For MinIO/S3: returns ("minio", object_key)
    - For Firebase: returns ("firebase", download_url)
    """
    provider = get_runtime_settings().storage_provider

    if provider == "firebase":
        from app.firebase_client import FirebaseStorageClient
        client = FirebaseStorageClient.from_settings()
        url = client.upload_file(local_path, object_name, content_type)
        return ("firebase", url)

    elif provider == "s3":
        # S3 via MinIO SDK (with real AWS endpoint)
        client = _get_minio()
        client.fput_object(
            bucket_name=env.minio_bucket,
            object_name=object_name,
            file_path=local_path,
            content_type=content_type,
        )
        return ("s3", object_name)

    else:  # minio (default)
        client = _get_minio()
        client.fput_object(
            bucket_name=env.minio_bucket,
            object_name=object_name,
            file_path=local_path,
            content_type=content_type,
        )
        return ("minio", object_name)


def get_download_url(object_name: str, expires_seconds: int = 3600) -> str:
    """Generate a download URL for the stored object."""
    provider = get_runtime_settings().storage_provider

    if provider == "firebase":
        from app.firebase_client import FirebaseStorageClient
        client = FirebaseStorageClient.from_settings()
        return client.get_download_url(object_name, expires_seconds)

    else:
        client = _get_minio()
        return client.presigned_get_object(
            bucket_name=env.minio_bucket,
            object_name=object_name,
            expires=expires_seconds,
        )
