// ============================================================
// DocMind Flutter — OCR Settings Screen
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/document_providers.dart';

class OcrSettingsScreen extends ConsumerStatefulWidget {
  const OcrSettingsScreen({super.key});

  @override
  ConsumerState<OcrSettingsScreen> createState() =>
      _OcrSettingsScreenState();
}

class _OcrSettingsScreenState extends ConsumerState<OcrSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _langCtrl;
  late TextEditingController _keywordsCtrl;
  bool _ocrEnabled = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _langCtrl = TextEditingController();
    _keywordsCtrl = TextEditingController();

    Future.microtask(() {
      final settingsAsync = ref.read(settingsProvider);
      settingsAsync.whenData((s) {
        setState(() {
          _ocrEnabled = s.ocrEnabled;
          _langCtrl.text = s.ocrLanguage;
          _keywordsCtrl.text = s.ocrKeywords.join(', ');
        });
      });
    });
  }

  @override
  void dispose() {
    _langCtrl.dispose();
    _keywordsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateSettings({
        'ocr_enabled': _ocrEnabled,
        'ocr_language': _langCtrl.text.trim(),
        'ocr_keywords': _keywordsCtrl.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      });
      ref.invalidate(settingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ OCR settings saved'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A1F36),
        foregroundColor: Colors.white,
        title: const Text('OCR & Document Filtering',
            style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('SAVE',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── OCR Toggle ────────────────────────
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: SwitchListTile(
                secondary: Icon(
                  _ocrEnabled
                      ? Icons.document_scanner_rounded
                      : Icons.document_scanner_outlined,
                  color: _ocrEnabled
                      ? const Color(0xFFF59E0B)
                      : Colors.grey,
                  size: 28,
                ),
                title: const Text('OCR Scanning',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _ocrEnabled
                      ? 'Text will be extracted from images & PDFs'
                      : 'Only MIME type filter will be used',
                  style: const TextStyle(fontSize: 12),
                ),
                value: _ocrEnabled,
                onChanged: (v) => setState(() => _ocrEnabled = v),
                activeColor: const Color(0xFFF59E0B),
              ),
            ),

            if (_ocrEnabled) ...[
              const SizedBox(height: 12),

              // ── Language ────────────────────────
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.translate, size: 20,
                              color: Color(0xFFF59E0B)),
                          SizedBox(width: 8),
                          Text('OCR Language',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tesseract language codes: ind=Indonesian, eng=English, ind+eng=both',
                        style: TextStyle(fontSize: 11,
                            color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _langCtrl,
                        decoration: const InputDecoration(
                          hintText: 'ind+eng',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.language),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Keywords ────────────────────────
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.filter_list_alt, size: 20,
                              color: Color(0xFFF59E0B)),
                          SizedBox(width: 8),
                          Text('Keyword Filter',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Only process documents whose OCR text contains at least one of these keywords. Comma-separated.',
                        style: TextStyle(fontSize: 11,
                            color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _keywordsCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText:
                              'Surat, Laporan, KTP, NPWP, Invoice, Kontrak...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'At least one keyword required'
                                : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
