# ============================================================
# DocMind Backend — Dockerfile
# Python 3.11 slim + Tesseract OCR binary dependencies
# ============================================================
FROM python:3.11-slim-bookworm

# System dependencies for Tesseract & image processing
RUN apt-get update && apt-get install -y --no-install-recommends \
    tesseract-ocr \
    tesseract-ocr-ind \
    libtesseract-dev \
    libleptonica-dev \
    poppler-utils \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r docmind && useradd -r -g docmind -d /app docmind

WORKDIR /app

# Python deps (layer cache)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Source code
COPY . .

# Set ownership to non-root user
RUN chown -R docmind:docmind /app && mkdir -p /app/data && chown -R docmind:docmind /app/data && mkdir -p /data/uploads && chown -R docmind:docmind /data
USER docmind

EXPOSE 8000

# Health check — verifies the API is responding
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
