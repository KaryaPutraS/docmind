# ============================================================
# DocMind — Pydantic request/response schemas
# ============================================================
from datetime import datetime
from typing import Any
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
    """Incoming WAHA webhook message (subset we care about).

    WAHA payloads vary between versions. This model accepts both:
    - ``chatId`` (v2024.x)
    - ``chat_id`` (some custom setups)
    - ``from`` / ``fromMe`` (sender field)
    """
    id: str = Field(default="unknown", alias="_data.id")
    from_: str = Field(default="unknown", alias="fromMe")
    chatId: str = Field(default="unknown")
    body: str | None = None
    type: str | None = None          # "image", "document", "ptt", etc.
    media: WAHAFile | None = None
    timestamp: int | None = None

    model_config = {"extra": "allow", "populate_by_name": True}


class WAHAWebhook(BaseModel):
    """Top-level WAHA webhook wrapper.

    Accepts the actual WAHA payload shape:
    {
        "event": "message",
        "session": "default",
        "payload": {...},
        "metadata": {...},
        "engine": "NOWEB",
        "environment": {...}
    }
    """
    event: str | None = None
    session: str | None = None
    payload: dict[str, Any] | WAHAMessage = Field(default_factory=dict)
    metadata: dict | None = None

    model_config = {"extra": "allow", "populate_by_name": True}

    def get_message(self) -> WAHAMessage | None:
        """Parse the payload into a WAHAMessage, handling both dict and object."""
        if isinstance(self.payload, WAHAMessage):
            return self.payload
        if not isinstance(self.payload, dict):
            return None
        msg = self.payload

        # Map WAHA field variants to our schema
        msg_id = msg.get("id") or msg.get("_data", {}).get("id") or msg.get("key", {}).get("id") or "unknown"
        from_ = msg.get("_data", {}).get("notifyName") or msg.get("from") or msg.get("fromMe") or "unknown"
        chat_id = msg.get("chatId") or msg.get("chat_id") or msg.get("from") or msg.get("id") or "unknown"

        return WAHAMessage(
            id=str(msg_id),
            from_=str(from_),
            chatId=str(chat_id),
            body=msg.get("body") or msg.get("caption") or "",
            type=msg.get("type", ""),
            media=WAHAFile(
                mimetype=msg.get("media", {}).get("mimetype") if isinstance(msg.get("media"), dict) else None,
                filename=msg.get("media", {}).get("filename") if isinstance(msg.get("media"), dict) else None,
                url=msg.get("media", {}).get("url") if isinstance(msg.get("media"), dict) else msg.get("media", {}).get("_data", {}).get("url") if isinstance(msg.get("media", {}).get("_data"), dict) else None,
                size=msg.get("media", {}).get("size") if isinstance(msg.get("media"), dict) else None,
            ) if msg.get("media") else None,
            timestamp=msg.get("timestamp"),
        )


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
    download_url: str | None = None   # Google Drive download URL

    model_config = {"from_attributes": True}


class SearchRequest(BaseModel):
    query: str
    limit: int = Field(default=20, ge=1, le=100)


class FolderTree(BaseModel):
    """Flattened folder tree for frontend."""
    folders: list[str]
    files: list[DocumentResponse]
