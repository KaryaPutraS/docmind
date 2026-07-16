# ============================================================
# DocMind — AI Service (Gemini 1.5 Pro — classification + embedding)
# ============================================================
import json
import logging
import re

import google.generativeai as genai
import httpx

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
    Classify document metadata.

    Current implementation uses Gemini SDK when provider is Gemini. If the user
    selects a non-Gemini provider (DeepSeek/OpenAI/etc.) or no Gemini key exists,
    we MUST NOT crash the WhatsApp → Drive pipeline. In that case use a safe
    heuristic fallback so files still enter Google Drive and the app.
    """
    dyn = get_dynamic_settings()
    provider = (dyn.ai_provider or "gemini").lower()
    api_key = dyn.ai_api_key or settings.gemini_api_key
    if provider == "deepseek" and api_key:
        try:
            user_prompt = (
                f"Nama file asli: {original_filename}\n\n"
                f"Teks hasil OCR:\n{ocr_text[:6000]}"
            )
            async with httpx.AsyncClient(timeout=60.0) as client:
                resp = await client.post(
                    "https://api.deepseek.com/chat/completions",
                    headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
                    json={
                        "model": dyn.ai_model or "deepseek-chat",
                        "messages": [
                            {"role": "system", "content": CLASSIFICATION_SYSTEM_PROMPT},
                            {"role": "user", "content": user_prompt},
                        ],
                        "temperature": dyn.ai_temperature,
                        "max_tokens": dyn.ai_max_tokens,
                        "response_format": {"type": "json_object"},
                    },
                )
                resp.raise_for_status()
                raw = resp.json()["choices"][0]["message"]["content"].strip()
            raw = re.sub(r"^```(?:json)?\s*", "", raw)
            raw = re.sub(r"\s*```$", "", raw)
            return GeminiClassification(**json.loads(raw))
        except Exception as exc:
            logger.warning("DeepSeek classification failed; using fallback metadata: %s", exc)

    if provider != "gemini" or not api_key:
        logger.warning("AI provider %s unavailable/unsupported; using fallback classification", provider)
        return GeminiClassification(
            new_filename=original_filename or "Dokumen_WhatsApp.pdf",
            category="Lainnya",
            folder_structure="WhatsApp/Belum_Diklasifikasi",
            summary=(ocr_text[:250] if ocr_text else "File diterima dari WhatsApp dan disimpan tanpa klasifikasi AI."),
            tags=["whatsapp", "auto-upload"],
        )

    _ensure_configured()
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
    For non-Gemini providers (DeepSeek, etc.) skip embedding for now instead of
    calling Gemini with an invalid key and filling logs with noise.
    """
    dyn = get_dynamic_settings()
    provider = (dyn.ai_provider or "gemini").lower()
    api_key = dyn.ai_api_key or settings.gemini_api_key
    if provider != "gemini" or not api_key:
        logger.info("Embedding skipped for provider=%s", provider)
        return []
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
