# ============================================================
# DocMind — OCR Service (Tesseract-based filtering)
# ============================================================
import io
import logging
import shutil
import sys
import tempfile
from pathlib import Path

import pytesseract
from PIL import Image
from pdf2image import convert_from_path

from app.config import get_settings

# Validate poppler-utils availability (required by pdf2image)
_POPPLER_BIN = shutil.which("pdftoppm") or shutil.which("pdftocairo") or (
    sys.platform == "win32" and (shutil.which("pdftoppm.exe"))
)

if not _POPPLER_BIN:
    from pdf2image.exceptions import PDFInfoNotInstalledError  # noqa: F401

logger = logging.getLogger(__name__)
settings = get_settings()


def extract_text_from_image(image_bytes: bytes) -> str:
    """OCR raw image bytes and return the extracted text."""
    try:
        img = Image.open(io.BytesIO(image_bytes))
        # Convert RGBA → RGB if necessary (Tesseract doesn't handle alpha)
        if img.mode in ("RGBA", "LA", "P"):
            img = img.convert("RGB")
        text = pytesseract.image_to_string(img, lang="ind+eng")
        return text.strip()
    except Exception as exc:
        logger.warning("Tesseract failed on image: %s", exc)
        return ""


def extract_text_from_pdf(file_bytes: bytes) -> str:
    """Render PDF pages to images and OCR them. Returns combined text."""
    if not _POPPLER_BIN:
        logger.error(
            "poppler-utils not found. Install poppler-utils (apt) "
            "or download from https://github.com/oschwartz10612/poppler-windows/releases"
        )
        return ""

    tmp = tempfile.NamedTemporaryFile(suffix=".pdf", delete=False)
    try:
        tmp.write(file_bytes)
        tmp.flush()
        tmp_path = tmp.name
    finally:
        tmp.close()

    try:
        images = convert_from_path(tmp_path, dpi=200, first_page=1, last_page=3)
        text_parts: list[str] = []
        for page_img in images:
            page_text = pytesseract.image_to_string(page_img, lang="ind+eng")
            text_parts.append(page_text.strip())
        return "\n--- PAGE BREAK ---\n".join(text_parts)
    except Exception as exc:
        logger.warning("Tesseract failed on PDF: %s", exc)
        return ""
    finally:
        Path(tmp_path).unlink(missing_ok=True)


def ocr_extract(file_bytes: bytes, mime_type: str) -> str:
    """Dispatch to the right OCR path based on MIME type."""
    if mime_type in ("image/jpeg", "image/png", "image/webp"):
        return extract_text_from_image(file_bytes)
    elif mime_type == "application/pdf":
        return extract_text_from_pdf(file_bytes)
    else:
        logger.info("Unsupported MIME type for OCR: %s", mime_type)
        return ""


def contains_keywords(text: str, keywords: str | None = None) -> bool:
    """
    Return True if the OCR text contains at least one keyword
    from the provided string or OCR_KEYWORDS (case-insensitive, partial match).
    """
    if not text:
        return False
    text_lower = text.lower()
    
    kw_list = settings.ocr_keyword_list
    if keywords:
        if isinstance(keywords, str):
            kw_list = [k.strip().lower() for k in keywords.split(",") if k.strip()]
        else:
            # Assuming it's already an iterable of strings
            kw_list = [k.strip().lower() for k in keywords if isinstance(k, str) and k.strip()]
        
    for kw in kw_list:
        # kw_list elements from settings are already lowercased in config, 
        # but if passed via string they are lowercased above
        if (kw if isinstance(kw, str) else "").lower() in text_lower:
            return True
    return False
