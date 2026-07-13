# ============================================================
# DocMind — App Configuration (env → Pydantic model)
# ============================================================
import os

from dotenv import load_dotenv
from pydantic_settings import BaseSettings
from functools import lru_cache

# Explicit dotenv loading as fallback before pydantic-settings
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env"))


class Settings(BaseSettings):
    """All configuration loaded from environment / .env file."""

    # ---- PostgreSQL ----
    postgres_user: str = "docmind"
    postgres_password: str = "docmind_pg_change_me"
    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_db: str = "docmind"

    # ---- MinIO ----
    minio_root_user: str = "docmind_admin"
    minio_root_password: str = "docmind_secret_change_me"
    minio_endpoint: str = "localhost:9000"
    minio_bucket: str = "docmind-documents"
    minio_secure: bool = False

    # ---- Gemini AI ----
    gemini_api_key: str = ""
    gemini_model: str = "gemini-1.5-pro"

    # ---- OCR Filtering ----
    ocr_keywords: str = (
        "Surat,Laporan,KTP,NPWP,Invoice,Kwitansi,"
        "Nota,Kontrak,SPK,BAST,Akta,Sertifikat,Ijazah,Rekening,Formulir"
    )

    # ---- WAHA ----
    waha_webhook_secret: str = "change_me"

    # ---- App ----
    debug: bool = True

    @property
    def database_url(self) -> str:
        return (
            f"postgresql+asyncpg://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )

    @property
    def ocr_keyword_list(self) -> list[str]:
        """Return keywords as a lowercase list for matching."""
        return [kw.strip().lower() for kw in self.ocr_keywords.split(",") if kw.strip()]

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


@lru_cache()
def get_settings() -> Settings:
    return Settings()
