# ============================================================
# DocMind — VPS / Local Storage Client
# Supports: local filesystem (default), SFTP (remote VPS)
# ============================================================
import logging
import os
import shutil
from pathlib import Path

from app.settings_store import get_settings

logger = logging.getLogger(__name__)


class VpsStorageClient:
    """Upload files to local filesystem (default) or remote VPS via SFTP."""

    def __init__(
        self,
        host: str = "",
        port: int = 22,
        username: str = "",
        password: str = "",
        base_path: str = "/app/uploads",
        public_base_url: str = "http://43.156.71.166/uploads",
    ):
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.base_path = base_path.rstrip("/")
        self.public_base_url = public_base_url.rstrip("/")
        self._remote = bool(host and host not in ("localhost", "127.0.0.1"))

    def upload_file(
        self,
        local_path: str,
        object_name: str,
        content_type: str = "application/octet-stream",
    ) -> str:
        """
        Upload a file. Returns the public URL to access the file.
        - Local mode: copy to base_path on the same filesystem
        - SFTP mode: upload to remote VPS
        """
        if self._remote:
            return self._sftp_upload(local_path, object_name)
        return self._local_upload(local_path, object_name)

    def _local_upload(self, local_path: str, object_name: str) -> str:
        dest = os.path.join(self.base_path, object_name)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copy2(local_path, dest)
        os.chmod(dest, 0o644)
        public_url = f"{self.public_base_url}/{object_name}"
        logger.info("Local storage OK: %s → %s", local_path, public_url)
        return public_url

    def _sftp_upload(self, local_path: str, object_name: str) -> str:
        import paramiko

        remote_path = f"{self.base_path}/{object_name}"
        transport = paramiko.Transport((self.host, self.port))
        transport.connect(username=self.username, password=self.password)
        sftp = paramiko.SFTPClient.from_transport(transport)
        try:
            dirname = os.path.dirname(remote_path)
            try:
                sftp.stat(dirname)
            except FileNotFoundError:
                self._mkdir_p(sftp, dirname)
            sftp.put(local_path, remote_path)
            sftp.chmod(remote_path, 0o644)
        finally:
            sftp.close()
        public_url = f"{self.public_base_url}/{object_name}"
        logger.info("SFTP upload OK: %s → %s", local_path, public_url)
        return public_url

    def _mkdir_p(self, sftp, remote_directory: str):
        if remote_directory == "/":
            return
        try:
            sftp.stat(remote_directory)
        except FileNotFoundError:
            self._mkdir_p(sftp, os.path.dirname(remote_directory))
            sftp.mkdir(remote_directory)

    def get_download_url(self, file_ref: str) -> str:
        if file_ref.startswith("http"):
            return file_ref
        return f"{self.public_base_url}/{file_ref}"

    @classmethod
    def from_settings(cls) -> "VpsStorageClient":
        s = get_settings()
        host = s.vps_storage_host or ""
        return cls(
            host=host,
            port=s.vps_storage_port,
            username=s.vps_storage_username,
            password=s.vps_storage_password,
            base_path=s.vps_storage_base_path or "/app/uploads",
            public_base_url=s.vps_storage_public_base_url or "http://43.156.71.166/uploads",
        )
