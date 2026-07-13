# ============================================================
# DocMind — Google Drive Storage client
# Uses a Google Service Account to upload files to a shared
# Drive folder. No OAuth per-user — one folder, zero login.
# ============================================================
import json
import logging
import io
from pathlib import Path

logger = logging.getLogger(__name__)

# We use the Google Drive REST API directly with httpx to avoid
# pulling in the heavy google-api-python-client dependency.
# Auth: Service Account → JWT → bearer token


def _get_access_token(credentials_json: dict) -> str:
    """Exchange a service-account JSON key for a short-lived OAuth2 token."""
    import time
    import jwt  # pyjwt — minimal, reliable JWT signing

    now = int(time.time())
    scope = "https://www.googleapis.com/auth/drive.file"

    payload = {
        "iss": credentials_json["client_email"],
        "scope": scope,
        "aud": credentials_json["token_uri"],
        "exp": now + 3600,
        "iat": now,
    }

    assertion = jwt.encode(
        payload,
        credentials_json["private_key"],
        algorithm="RS256",
    )

    import httpx

    resp = httpx.post(
        credentials_json["token_uri"],
        data={
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": assertion,
        },
        timeout=15.0,
    )
    resp.raise_for_status()
    return resp.json()["access_token"]


class GoogleDriveClient:
    """Upload files to Google Drive via Service Account REST API."""

    def __init__(
        self,
        credentials_json: dict | str,
        folder_id: str = "root",
    ):
        if isinstance(credentials_json, str):
            credentials_json = json.loads(credentials_json)
        self._creds = credentials_json
        self._folder_id = folder_id
        self._token: str | None = None
        self._token_expiry: float = 0

    def _get_token(self) -> str:
        import time

        if self._token and time.time() < self._token_expiry - 60:
            return self._token

        self._token = _get_access_token(self._creds)
        self._token_expiry = time.time() + 3500
        return self._token

    def upload_file(
        self,
        local_path: str | Path,
        object_name: str,
        content_type: str = "application/octet-stream",
    ) -> str:
        """
        Upload a file to the configured Drive folder.
        Returns the Google Drive file ID.
        """
        local_path = Path(local_path)

        file_size = local_path.stat().st_size
        token = self._get_token()

        import httpx

        # Simple upload for small files (<5 MB): single POST
        if file_size < 5 * 1024 * 1024:
            metadata = {
                "name": object_name,
                "parents": [self._folder_id],
            }

            # Upload metadata + file in one multipart request
            boundary = "docmind_upload_boundary"
            body = (
                f"--{boundary}\r\n"
                f"Content-Type: application/json; charset=UTF-8\r\n\r\n"
                f"{json.dumps(metadata)}\r\n"
                f"--{boundary}\r\n"
                f"Content-Type: {content_type}\r\n\r\n"
            ).encode("utf-8")
            body += local_path.read_bytes()
            body += f"\r\n--{boundary}--\r\n".encode("utf-8")

            resp = httpx.post(
                "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart",
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": f"multipart/related; boundary={boundary}",
                },
                content=body,
                timeout=120.0,
            )
        else:
            # Resumable upload for large files
            resp = httpx.post(
                "https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable",
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json; charset=UTF-8",
                },
                json={
                    "name": object_name,
                    "parents": [self._folder_id],
                },
                timeout=30.0,
            )
            if resp.status_code == 200:
                upload_url = resp.headers.get("Location", "")
                if upload_url:
                    resp = httpx.put(
                        upload_url,
                        headers={
                            "Content-Type": content_type,
                            "Content-Length": str(file_size),
                        },
                        content=local_path.read_bytes(),
                        timeout=300.0,
                    )

        if resp.status_code not in (200, 201):
            logger.error(
                "Google Drive upload failed [%d]: %s",
                resp.status_code,
                resp.text[:500],
            )
            raise RuntimeError(
                f"Google Drive upload failed [{resp.status_code}]: {resp.text[:200]}"
            )

        data = resp.json()
        file_id = data["id"]
        logger.info("Uploaded '%s' → Drive ID %s", object_name, file_id)
        return file_id

    def get_download_url(self, file_id: str) -> str:
        """Return a direct download link for a Drive file.
        The file must be shared with 'anyone with link' permission."""
        # Set permission to anyone-with-link if not already
        token = self._get_token()
        import httpx

        # Make file publicly accessible (viewer)
        httpx.post(
            f"https://www.googleapis.com/drive/v3/files/{file_id}/permissions",
            headers={"Authorization": f"Bearer {token}"},
            json={"role": "reader", "type": "anyone"},
            timeout=15.0,
        )

        return f"https://drive.google.com/uc?export=download&id={file_id}"

    def get_web_view_url(self, file_id: str) -> str:
        """Link to open file in Google Drive web viewer."""
        return f"https://drive.google.com/file/d/{file_id}/view"

    @classmethod
    def from_settings(cls) -> "GoogleDriveClient":
        """Build a Google Drive client from the runtime settings store."""
        from app.settings_store import get_settings as get_runtime_settings

        settings = get_runtime_settings()
        creds_raw = settings.google_drive_credentials_json

        if not creds_raw:
            raise RuntimeError(
                "Google Drive credentials not configured. "
                "Go to Settings → Storage → Google Drive → paste Service Account JSON."
            )

        if isinstance(creds_raw, str):
            creds_raw = json.loads(creds_raw)

        return cls(
            credentials_json=creds_raw,
            folder_id=settings.google_drive_folder_id or "root",
        )
