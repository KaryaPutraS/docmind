# ============================================================
# DocMind — Pydantic request/response schemas
# ============================================================
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


# ── WAHA Webhook Payload ──────────────────────────────────────

class WAHAFile(BaseModel):
    """File metadata inside a WAHA message."""
    mimetype: str | None = Field(None, alias="mimetype")
    filename: str | None = Field(None, alias="filename")
    url: str | None = Field(None, alias="url")           # WAHA internal download URL
    size: int | None = Field(None, alias="size")          # bytes


class WAHAMessage(BaseModel):
    """Incoming WAHA webhook message (subset we care about)."""
    id: str
    from_: str = Field(..., alias="from")
    chatId: str
    body: str | None = None
    type: str | None = None          # "image", "document", "ptt", etc.
    media: WAHAFile | None = None
    timestamp: int | None = None


class WAHAWebhook(BaseModel):
    """Top-level WAHA webhook wrapper."""
    event: str
    session: str | None = None
    payload: WAHAMessage
    metadata: dict | None = None


# ── Gemini AI Response ────────────────────────────────────────

class GeminiClassification(BaseModel):
    """Structured JSON the Gemini model MUST return."""
    new_filename: str
    category: str
    folder_structure: str    # e.g. "2026/07/Banjarmasin"
    summary: str
    tags: list[str] = Field(default_factory=list)


# ── API Responses ─────────────────────────────────────────────

class DocumentResponse(BaseModel):
    """Document row returned to the Flutter frontend."""
    id: UUID
    original_filename: str
    new_filename: str
    category: str | None
    folder_path: str | None
    mime_type: str | None
    file_size: int | None
    ai_summary: str | None
    processed_at: datetime | None
    download_url: str | None = None   # signed or public MinIO URL

    model_config = {"from_attributes": True}


class SearchRequest(BaseModel):
    query: str
    limit: int = Field(default=20, ge=1, le=100)


class FolderTree(BaseModel):
    """Flattened folder tree for frontend."""
    folders: list[str]
    files: list[DocumentResponse]
