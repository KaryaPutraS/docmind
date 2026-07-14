-- ============================================================
-- DocMind — Database initialisation
-- Enables pgvector extension and creates core tables
-- ============================================================

-- Extension for vector similarity search (768-d OpenAI / 768-d Gemini)
CREATE EXTENSION IF NOT EXISTS vector;

-- ---------------------------------------------------------------
-- documents — one row per stored file
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS documents (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wa_message_id   TEXT,                     -- WAHA message id (for dedup)
    wa_chat_id      TEXT,                     -- sender / group chat id
    wa_sender       TEXT,                     -- phone number of sender

    original_filename TEXT NOT NULL,
    new_filename    TEXT NOT NULL,            -- AI-generated name
    category        TEXT,                     -- e.g. "Surat Masuk", "KTP", "Laporan"
    folder_path     TEXT,                     -- e.g. "2026/07/Banjarmasin"
    mime_type       TEXT,
    file_size       BIGINT,                   -- bytes

    minio_bucket    TEXT NOT NULL DEFAULT 'docmind-documents',
    minio_object    TEXT NOT NULL,            -- key/path inside the bucket
    drive_file_id   TEXT,                     -- Google Drive file ID

    ocr_text        TEXT,                     -- raw Tesseract output
    ai_summary      TEXT,                     -- short summary from Gemini
    ai_metadata     JSONB,                    -- full JSON returned by Gemini

    embedding       vector(768),             -- Gemini text-embedding-004 / OpenAI ada-002

    processed_at    TIMESTAMPTZ DEFAULT now(),
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- Index on folder_path for tree navigation
CREATE INDEX IF NOT EXISTS idx_documents_folder
    ON documents (folder_path);

-- Index for dedup on incoming WhatsApp messages
CREATE UNIQUE INDEX IF NOT EXISTS idx_documents_wa_msg
    ON documents (wa_message_id)
    WHERE wa_message_id IS NOT NULL;

-- HNSW index for semantic (ANN) search
CREATE INDEX IF NOT EXISTS idx_documents_embedding
    ON documents
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 128);
