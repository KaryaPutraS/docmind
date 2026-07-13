# ============================================================
# DocMind — Documents API router (for Flutter frontend)
#
# SECURITY NOTE: No authentication is implemented on any endpoint.
# Anyone with network access to this API can list all documents,
# browse the folder tree, search, and download any file.
# TODO(auth): Add API-key or OAuth2 middleware before production deployment.
# ============================================================
import logging
import re
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import select

from app.database import AsyncSessionLocal
from app.minio_client import get_presigned_url
from app.models import Document
from app.schemas import DocumentResponse, FolderTree, SearchRequest

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/documents", tags=["documents"])

# Cache for query embeddings to avoid regenerating on every call
_embedding_cache: dict[str, list[float]] = {}
_EMBEDDING_CACHE_MAX = 128


def _sanitize_like_pattern(value: str) -> str:
    """Escape SQL LIKE wildcards % and _ to prevent injection/false matches."""
    return re.sub(r"([%_])", r"\\\1", value)


# ---------------------------------------------------------------------------
# List all documents (paginated)
# ---------------------------------------------------------------------------
@router.get("/", response_model=list[DocumentResponse])
async def list_documents(
    folder: str | None = Query(None, description="Filter by folder_path prefix"),
    category: str | None = Query(None),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
):
    async with AsyncSessionLocal() as session:
        stmt = select(Document).order_by(Document.processed_at.desc())

        if folder:
            stmt = stmt.where(Document.folder_path.like(f"{_sanitize_like_pattern(folder)}%"))
        if category:
            stmt = stmt.where(Document.category == category)

        stmt = stmt.limit(limit).offset(offset)
        result = await session.execute(stmt)
        rows = result.scalars().all()

        return [_doc_to_response(r) for r in rows]


# ---------------------------------------------------------------------------
# Folder tree — returns distinct folders + files in a given folder
# ---------------------------------------------------------------------------
@router.get("/tree", response_model=FolderTree)
async def folder_tree(
    prefix: str = Query(default="", description="Folder prefix to list"),
):
    async with AsyncSessionLocal() as session:
        # Fetch direct children (files + subfolders)
        # A folder is considered "direct" if its path starts with prefix and
        # the remainder has at most one slash.
        stmt = select(Document).where(
            Document.folder_path.like(f"{_sanitize_like_pattern(prefix)}%")
        ).order_by(Document.folder_path, Document.new_filename)
        result = await session.execute(stmt)
        rows = result.scalars().all()

        folders_set: set[str] = set()
        files: list[DocumentResponse] = []

        prefix_depth = prefix.count("/") + (1 if prefix else 0)

        for doc in rows:
            parts = (doc.folder_path or "").split("/")
            if len(parts) > prefix_depth:
                # This doc lives deeper — surface the immediate child folder
                child_folder = "/".join(parts[:prefix_depth])
                folders_set.add(child_folder)
            elif len(parts) == prefix_depth:
                files.append(_doc_to_response(doc))

        return FolderTree(
            folders=sorted(folders_set),
            files=files,
        )


# ---------------------------------------------------------------------------
# Semantic search (pgvector cosine similarity)
# ---------------------------------------------------------------------------
@router.post("/search", response_model=list[DocumentResponse])
async def semantic_search(body: SearchRequest):
    async with AsyncSessionLocal() as session:
        # Generate embedding for the query text (re-use Gemini)
        from app.services.ai_service import generate_embedding

        safe_query = _sanitize_like_pattern(body.query)

        # Check cache first to avoid regenerating embeddings for repeated queries
        cache_key = body.query.strip().lower()
        if cache_key in _embedding_cache:
            query_embedding = _embedding_cache[cache_key]
        else:
            query_embedding = await generate_embedding(body.query)
            if query_embedding:
                if len(_embedding_cache) >= _EMBEDDING_CACHE_MAX:
                    _embedding_cache.pop(next(iter(_embedding_cache)))
                _embedding_cache[cache_key] = query_embedding

        if not query_embedding:
            # Fall back to text-only search (with sanitized LIKE pattern)
            stmt = (
                select(Document)
                .where(
                    (Document.ocr_text.ilike(f"%{safe_query}%"))
                    | (Document.ai_summary.ilike(f"%{safe_query}%"))
                    | (Document.new_filename.ilike(f"%{safe_query}%"))
                )
                .order_by(Document.processed_at.desc())
                .limit(body.limit)
            )
        else:
            # Cosine similarity ANN search via pgvector
            stmt = (
                select(Document)
                .order_by(Document.embedding.cosine_distance(query_embedding))
                .limit(body.limit)
            )

        result = await session.execute(stmt)
        rows = result.scalars().all()
        return [_doc_to_response(r) for r in rows]


# ---------------------------------------------------------------------------
# Single document detail + pre-signed download URL
# ---------------------------------------------------------------------------
@router.get("/{doc_id}", response_model=DocumentResponse)
async def get_document(doc_id: str):
    # Validate UUID format early to avoid pointless DB queries
    try:
        doc_uuid = UUID(doc_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="invalid-document-id-format")

    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(Document).where(Document.id == doc_uuid)
        )
        doc = result.scalar_one_or_none()
        if doc is None:
            raise HTTPException(status_code=404, detail="document-not-found")
        return _doc_to_response(doc, include_url=True)


# ---------------------------------------------------------------------------
# Helper: ORM → Pydantic
# ---------------------------------------------------------------------------
def _doc_to_response(doc: Document, include_url: bool = False) -> DocumentResponse:
    url: str | None = None
    if include_url:
        try:
            url = get_presigned_url(doc.minio_object)
        except Exception:
            url = None
    return DocumentResponse(
        id=doc.id,
        original_filename=doc.original_filename,
        new_filename=doc.new_filename,
        category=doc.category,
        folder_path=doc.folder_path,
        mime_type=doc.mime_type,
        file_size=doc.file_size,
        ai_summary=doc.ai_summary,
        processed_at=doc.processed_at,
        download_url=url,
    )
