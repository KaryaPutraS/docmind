# ============================================================
# DocMind — Firebase Storage client
# Used when storage_provider="firebase" in settings.
# Uses the Firebase Admin SDK (REST) to upload files.
# ============================================================
import json
import logging
import os
from pathlib import Path

import httpx

from app.settings_store import get_settings as get_runtime_settings

logger = logging.getLogger(__name__)

FIREBASE_STORAGE_BASE = "https://firebasestorage.googleapis.com/v0/b"


class FirebaseStorageClient:
    """Minimal Firebase Storage client using REST API + API Key."""

    def __init__(
        self,
        api_key: str,
        project_id: str,
        bucket: str,
        auth_domain: str = "",
    ):
        self.api_key = api_key
        self.project_id = project_id
        self.bucket = bucket
        self.auth_domain = auth_domain or f"{project_id}.firebaseapp.com"
        # Firebase Storage REST endpoint
        self._base = f"{FIREBASE_STORAGE_BASE}/{bucket}/o"

    def upload_file(
        self,
        local_path: str | Path,
        object_name: str,
        content_type: str = "application/octet-stream",
        public: bool = True,
    ) -> str:
        """
        Upload a local file to Firebase Storage via REST API.
        Returns the download URL (public or authenticated).
        """
        local_path = Path(local_path)

        # Step 1: Get upload URL from Firebase Storage REST
        upload_url = f"{self._base}?uploadType=media&name={object_name}"
        if not self.api_key:
            raise RuntimeError("Firebase API key is not configured")

        # Firebase REST auth uses ?auth=<api_key> or Bearer token.
        # For upload with media type, we pass the token as query param.
        upload_url += f"&key={self.api_key}"

        with open(local_path, "rb") as f:
            file_bytes = f.read()

        resp = httpx.post(
            upload_url,
            content=file_bytes,
            headers={"Content-Type": content_type},
            timeout=60.0,
        )

        if resp.status_code not in (200, 201):
            logger.error(
                "Firebase upload failed: %s %s",
                resp.status_code,
                resp.text[:500],
            )
            raise RuntimeError(f"Firebase upload failed: {resp.text[:200]}")

        data = resp.json()

        # Step 2: Return download URL
        if public:
            # Public URL pattern: https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<escaped_name>?alt=media
            import urllib.parse

            encoded = urllib.parse.quote(object_name, safe="")
            return f"{self._base}/{encoded}?alt=media"
        else:
            return data.get("downloadTokens", "")

    def get_download_url(self, object_name: str, expires_seconds: int = 3600) -> str:
        """Generate a signed download URL (requires service account for real signing).
        Falls back to public URL if using API key auth."""
        import urllib.parse

        encoded = urllib.parse.quote(object_name, safe="")
        return f"{self._base}/{encoded}?alt=media&token={self.api_key}"

    @classmethod
    def from_settings(cls) -> "FirebaseStorageClient":
        """Build a Firebase client from the runtime settings store."""
        settings = get_runtime_settings()
        if not settings.firebase_api_key:
            raise RuntimeError("Firebase API key is not configured in settings")

        return cls(
            api_key=settings.firebase_api_key,
            project_id=settings.firebase_project_id,
            bucket=settings.firebase_storage_bucket or f"{settings.firebase_project_id}.appspot.com",
            auth_domain=settings.firebase_auth_domain,
        )
