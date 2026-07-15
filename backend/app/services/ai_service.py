# ============================================================
# DocMind — AI Service (Gemini 1.5 Pro — classification + embedding)
# ============================================================
import json
import logging
import re

import google.generativeai as genai

from app.config import get_settings
from app.settings_store import get_settings as get_dynamic_settings
from app.schemas import GeminiClassification

logger = logging.getLogger(__name__)
settings = get_settings()

_configured = False


def _ensure_configured() -> None:
    """Lazily initialise the Gemini client on first use (not at import time)."""
    dyn = get_dynamic_settings()
    api_key = dyn.ai_api_key or settings.gemini_api_key
    
    if api_key:
        genai.configure(api_key=api_key)
    else:
        logger.warning("GEMINI_API_KEY is empty — AI features disabled")


# ---------------------------------------------------------------------------
# Prompt template: force Gemini to return ONLY valid JSON
# ---------------------------------------------------------------------------
CLASSIFICATION_SYSTEM_PROMPT = """\
Anda adalah asisten AI pengarsipan dokumen.
Tugas Anda: membaca teks hasil OCR sebuah dokumen, lalu mengembalikan metadata
dalam format JSON **strict** dengan field berikut:

{
  "new_filename": "<nama_file_baru>.pdf",
  "category": "<kategori>",
  "folder_structure": "<YYYY/MM/Lokasi_atau_Instansi>",
  "summary": "<ringkasan_isi_1-2_kalimat>",
  "tags": ["tag1", "tag2"]
}

Aturan:
1. new_filename: deskriptif, gunakan format "JenisDokumen_Instansi_Tanggal.pdf"
   Contoh: "SuratMasuk_DinasPU_20260713.pdf"
2. category: salah satu dari [Surat Masuk, Surat Keluar, Laporan, KTP, NPWP,
   Invoice, Kwitansi, Nota Dinas, Kontrak, SPK, BAST, Akta, Sertifikat, Ijazah,
   Rekening Koran, Formulir, Lainnya]
3. folder_structure: path direktori (YYYY/MM/NamaInstansi atau Lokasi)
4. summary: ringkasan singkat isi dokumen dalam Bahasa Indonesia
5. tags: 2-4 keyword tambahan

JANGAN tambahkan teks apapun selain JSON. JANGAN gunakan markdown code fences.

PENTING UNTUK DOKUMEN:
Jika teks OCR yang diberikan terlalu panjang, kacau, atau bahkan kosong (misalnya karena file dokumen/PDF), Anda WAJIB memprioritaskan "Nama file asli" (Judul File) untuk menentukan kategori, folder_structure, dan new_filename. Jangan bergantung sepenuhnya pada OCR jika judul file sudah cukup jelas."""


async def classify_document(ocr_text: str, original_filename: str) -> GeminiClassification:
    """
    Send OCR text to Gemini 1.5 Pro, parse the returned JSON,
    and return a structured GeminiClassification.
    """
    _ensure_configured()
    dyn = get_dynamic_settings()
    model_name = dyn.ai_model or settings.gemini_model
    model = genai.GenerativeModel(
        model_name=model_name,
        system_instruction=CLASSIFICATION_SYSTEM_PROMPT,
    )

    user_prompt = (
        f"Nama file asli: {original_filename}\n\n"
        f"Teks hasil OCR:\n{ocr_text[:6000]}"   # keep within token budget
    )

    response = await model.generate_content_async(user_prompt)
    raw = response.text.strip()

    # Strip markdown fences if Gemini ignored the instruction
    raw = re.sub(r"^```(?:json)?\s*", "", raw)
    raw = re.sub(r"\s*```$", "", raw)

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        logger.error("Gemini returned invalid JSON: %s", raw[:500])
        # Fallback: use sensible defaults
        return GeminiClassification(
            new_filename=f"Unknown_{original_filename}",
            category="Lainnya",
            folder_structure="Unsorted",
            summary="(AI gagal parsing — lihat file asli)",
            tags=[],
        )

    return GeminiClassification(**data)


async def generate_embedding(text: str) -> list[float]:
    """
    Generate a 768-d embedding vector using Gemini's text-embedding-004.
    Falls back gracefully if the embedding model is unavailable.
    """
    _ensure_configured()
    try:
        result = await genai.embed_content_async(
            model="models/text-embedding-004",
            content=text,
            task_type="RETRIEVAL_DOCUMENT",
        )
        return result["embedding"]
    except Exception as exc:
        logger.warning("Embedding generation failed; search disabled: %s", exc)
        return []
