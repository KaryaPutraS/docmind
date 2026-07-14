# ============================================================
# DocMind — SQLAlchemy ORM models
# ============================================================
import uuid

from pgvector.sqlalchemy import Vector
from sqlalchemy import BigInteger, Index, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy.sql import func
from sqlalchemy.types import DateTime


class Base(DeclarativeBase):
    pass


class Document(Base):
    __tablename__ = "documents"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    wa_message_id: Mapped[str | None] = mapped_column(Text, nullable=True)
    wa_chat_id: Mapped[str | None] = mapped_column(Text, nullable=True)
    wa_sender: Mapped[str | None] = mapped_column(Text, nullable=True)

    original_filename: Mapped[str] = mapped_column(Text, nullable=False)
    new_filename: Mapped[str] = mapped_column(Text, nullable=False)
    category: Mapped[str | None] = mapped_column(Text, nullable=True)
    folder_path: Mapped[str | None] = mapped_column(Text, nullable=True)
    mime_type: Mapped[str | None] = mapped_column(Text, nullable=True)
    file_size: Mapped[int | None] = mapped_column(BigInteger, nullable=True)

    minio_bucket: Mapped[str] = mapped_column(Text, default="docmind", nullable=True)
    minio_object: Mapped[str] = mapped_column(Text, nullable=False)
    drive_file_id: Mapped[str | None] = mapped_column(Text, nullable=True)

    ocr_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    ai_summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    ai_metadata: Mapped[dict | None] = mapped_column(JSONB, nullable=True)

    embedding: Mapped[list[float] | None] = mapped_column(Vector(768), nullable=True)

    processed_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    created_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    __table_args__ = (
        Index("idx_documents_folder", "folder_path"),
        UniqueConstraint(
            "wa_message_id", name="idx_documents_wa_msg", deferrable=True
        ),
    )
