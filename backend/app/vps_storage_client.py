# ============================================================
# DocMind — VPS SFTP Storage Client
# ============================================================
import logging
import os
from pathlib import Path

import paramiko

from app.settings_store import get_settings

logger = logging.getLogger(__name__)


class VpsStorageClient:
    """Upload files to a remote VPS via SFTP."""

    def __init__(
        self,
        host: str,
        port: int = 22,
        username: str = "",
        password: str = "",
        base_path: str = "/home/magang/docmind_uploads",
        public_base_url: str = "https://magang.vpsmso.site/docmind_uploads",
    ):
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.base_path = base_path.rstrip("/")
        self.public_base_url = public_base_url.rstrip("/")

    def _sftp_connect(self) -> paramiko.SFTPClient:
        transport = paramiko.Transport((self.host, self.port))
        transport.connect(username=self.username, password=self.password)
        return paramiko.SFTPClient.from_transport(transport)

    def upload_file(
        self,
        local_path: str,
        object_name: str,
        content_type: str = "application/octet-stream",
    ) -> str:
        """
        Upload a file to VPS via SFTP.
        Returns the public URL to access the file.
        """
        remote_path = f"{self.base_path}/{object_name}"

        sftp = self._sftp_connect()
        try:
            # Ensure directory exists
            dirname = os.path.dirname(remote_path)
            try:
                sftp.stat(dirname)
            except FileNotFoundError:
                self._mkdir_p(sftp, dirname)

            sftp.put(local_path, remote_path)
            sftp.chmod(remote_path, 0o644)
        finally:
            sftp.close()

        # Return public URL
        public_url = f"{self.public_base_url}/{object_name}"
        logger.info("VPS upload OK: %s → %s", local_path, public_url)
        return public_url

    def _mkdir_p(self, sftp: paramiko.SFTPClient, remote_directory: str):
        """Create directory recursively on remote."""
        if remote_directory == "/":
            return
        try:
            sftp.stat(remote_directory)
        except FileNotFoundError:
            self._mkdir_p(sftp, os.path.dirname(remote_directory))
            sftp.mkdir(remote_directory)

    def get_download_url(self, file_ref: str) -> str:
        """
        file_ref is already a public URL for VPS storage.
        Just return it as-is for backward compat.
        """
        if file_ref.startswith("http"):
            return file_ref
        return f"{self.public_base_url}/{file_ref}"

    @classmethod
    def from_settings(cls) -> "VpsStorageClient":
        s = get_settings()
        return cls(
            host=s.vps_storage_host,
            port=s.vps_storage_port,
            username=s.vps_storage_username,
            password=s.vps_storage_password,
            base_path=s.vps_storage_base_path,
            public_base_url=s.vps_storage_public_base_url,
        )
