# ============================================================
# DocMind — MinIO client (singleton)
# ============================================================
from minio import Minio

from app.config import get_settings

settings = get_settings()

_client: Minio | None = None


def get_minio_client() -> Minio:
    """Return a configured MinIO client. Lazily initialised."""
    global _client
    if _client is None:
        _client = Minio(
            endpoint=settings.minio_endpoint,
            access_key=settings.minio_root_user,
            secret_key=settings.minio_root_password,
            secure=settings.minio_secure,
        )
        # Ensure the bucket exists
        if not _client.bucket_exists(settings.minio_bucket):
            _client.make_bucket(settings.minio_bucket)
            print(f"[minio] Created bucket '{settings.minio_bucket}'")
    return _client


def upload_file_to_minio(
    local_path: str,
    object_name: str,
    content_type: str = "application/octet-stream",
) -> str:
    """
    Upload a local file to the MinIO bucket.

    Returns the object key (path inside the bucket).
    """
    client = get_minio_client()
    client.fput_object(
        bucket_name=settings.minio_bucket,
        object_name=object_name,
        file_path=local_path,
        content_type=content_type,
    )
    return object_name


def get_presigned_url(object_name: str, expires_seconds: int = 3600) -> str:
    """Generate a temporary pre-signed download URL."""
    client = get_minio_client()
    return client.presigned_get_object(
        bucket_name=settings.minio_bucket,
        object_name=object_name,
        expires=expires_seconds,
    )
