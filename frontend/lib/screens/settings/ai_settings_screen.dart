// ============================================================
// DocMind Flutter — AI Settings Screen
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/document_providers.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _modelCtrl;
  late TextEditingController _tempCtrl;
  late TextEditingController _tokensCtrl;
  String _provider = 'gemini';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _modelCtrl = TextEditingController();
    _tempCtrl = TextEditingController();
    _tokensCtrl = TextEditingController();

    // Pre-fill from current settings once loaded
    Future.microtask(() {
      final settingsAsync = ref.read(settingsProvider);
      settingsAsync.whenData((s) {
        setState(() {
          _modelCtrl.text = s.aiModel;
          _tempCtrl.text = s.aiTemperature.toString();
          _tokensCtrl.text = s.aiMaxTokens.toString();
          _provider = s.aiProvider;
        });
      });
    });
  }

  @override
  void dispose() {
    _modelCtrl.dispose();
    _tempCtrl.dispose();
    _tokensCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateSettings({
        'ai_provider': _provider,
        'ai_model': _modelCtrl.text.trim(),
        'ai_temperature': double.parse(_tempCtrl.text.trim()),
        'ai_max_tokens': int.parse(_tokensCtrl.text.trim()),
      });
      ref.invalidate(settingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ AI settings saved'),
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
        title: const Text('AI / Gemini Settings',
            style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
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
            // ── Provider ──────────────────────────
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AI Provider',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'gemini',
                            label: Text('Gemini'),
                            icon: Icon(Icons.auto_awesome)),
                        ButtonSegment(
                            value: 'openai',
                            label: Text('OpenAI'),
                            icon: Icon(Icons.open_in_new)),
                        ButtonSegment(
                            value: 'custom',
                            label: Text('Custom'),
                            icon: Icon(Icons.tune)),
                      ],
                      selected: {_provider},
                      onSelectionChanged: (v) =>
                          setState(() => _provider = v.first),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Model Name ────────────────────────
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Model Name',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _modelCtrl,
                      decoration: const InputDecoration(
                        hintText: 'gemini-1.5-pro / gpt-4o',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.model_training),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Temperature ───────────────────────
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Temperature',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        Text(_tempCtrl.text.isEmpty
                            ? '0.3'
                            : _tempCtrl.text,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4F6EF7))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _tempCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: '0.0 - 1.0',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.thermostat),
                        suffixText: '0.0 - 1.0',
                      ),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null || n < 0 || n > 1)
                          return 'Must be 0.0 - 1.0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lower = more deterministic. Higher = more creative.',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Max Tokens ────────────────────────
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Max Output Tokens',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _tokensCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '2048',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                        suffixText: '64 - 8192',
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 64 || n > 8192)
                          return 'Must be 64 - 8192';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
