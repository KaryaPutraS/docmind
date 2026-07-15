# ============================================================
# DocMind — FastAPI application entry point
# ============================================================
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.database import engine
from app.models import Base
from app.routers import documents, webhook, settings as settings_router, status

cfg = get_settings()

# ── Logging ──────────────────────────────────────────────
logging.basicConfig(
    level=logging.DEBUG if cfg.debug else logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)


# ── Lifespan (replaces deprecated on_event) ──────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Create tables if they don't exist yet (dev convenience)."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logging.info("Database tables ensured.")
    yield
    await engine.dispose()


# ── App ───────────────────────────────────────────────────
app = FastAPI(
    title="DocMind API",
    description="AI-Powered Automated Document Management System",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS — allow Flutter / dev clients
# TODO(prod): Restrict allow_origins to the actual frontend domain(s) before production.
#              Wildcard '*' is safe only because allow_credentials=False.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────
app.include_router(webhook.router)
app.include_router(documents.router)
app.include_router(settings_router.router)
app.include_router(status.router)


@app.get("/health")
async def health():
    return {"status": "ok", "service": "docmind-api"}
