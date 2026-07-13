// ============================================================
// DocMind Flutter — AI Settings Screen (v2)
// Full provider list, API key field, auto-fetch models on key
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../providers/document_providers.dart';
import '../../services/api_service.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _tempCtrl;
  late TextEditingController _tokensCtrl;

  String _provider = 'gemini';
  String _model = 'gemini-1.5-pro';
  List<String> _availableModels = [];
  bool _loadingModels = false;
  bool _saving = false;
  bool _apiKeyVisible = false;

  // Static provider list with icons & colors
  static const _providers = [
    _ProviderInfo('gemini', 'Google Gemini', Color(0xFF4285F4), Icons.auto_awesome),
    _ProviderInfo('openai', 'OpenAI', Color(0xFF10A37F), Icons.psychology),
    _ProviderInfo('groq', 'Groq', Color(0xFFF55036), Icons.bolt_rounded),
    _ProviderInfo('anthropic', 'Anthropic Claude', Color(0xFFD97757), Icons.lightbulb_rounded),
    _ProviderInfo('deepseek', 'DeepSeek', Color(0xFF4D6BFE), Icons.explore_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _apiKeyCtrl = TextEditingController();
    _tempCtrl = TextEditingController(text: '0.3');
    _tokensCtrl = TextEditingController(text: '2048');

    Future.microtask(() {
      final settingsAsync = ref.read(settingsProvider);
      settingsAsync.whenData((s) {
        setState(() {
          _provider = s.aiProvider;
          _model = s.aiModel;
          _apiKeyCtrl.text = s.aiApiKey;
          _tempCtrl.text = s.aiTemperature.toString();
          _tokensCtrl.text = s.aiMaxTokens.toString();
        });
        _fetchModels();
      });
    });
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _tempCtrl.dispose();
    _tokensCtrl.dispose();
    super.dispose();
  }

  // ─── Auto-fetch models when provider changes ────────────
  Future<void> _fetchModels() async {
    setState(() => _loadingModels = true);
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.dio.get(
        '/api/settings/models',
        queryParameters: {'provider': _provider},
      );
      final models = (result.data['models'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      setState(() {
        _availableModels = models;
        // Auto-select first model if current one is not in list
        if (models.isNotEmpty && !models.contains(_model)) {
          _model = models.first;
        }
      });
    } catch (_) {
      // Fallback: use hardcoded list if backend unreachable
      setState(() {
        _availableModels = _backendModels[_provider] ?? [];
      });
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  // Hardcoded fallback (same as backend KNOWN_MODELS)
  static const Map<String, List<String>> _backendModels = {
    'gemini': ['gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-2.0-flash', 'gemini-1.5-pro', 'gemini-1.5-flash', 'gemini-1.5-flash-8b'],
    'openai': ['gpt-4o', 'gpt-4o-mini', 'gpt-4.1', 'gpt-4.1-mini', 'o4-mini', 'o3-mini'],
    'groq': ['llama-4-scout-17b-16e-instruct', 'llama-4-maverick-17b-128e-instruct', 'llama-3.3-70b-versatile', 'deepseek-r1-distill-llama-70b', 'qwen-2.5-32b', 'mixtral-8x7b-32768'],
    'anthropic': ['claude-sonnet-4-20250514', 'claude-3-5-sonnet-20241022', 'claude-3-5-haiku-20241022', 'claude-3-opus-20240229'],
    'deepseek': ['deepseek-chat', 'deepseek-reasoner'],
  };

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateSettings({
        'ai_provider': _provider,
        'ai_model': _model,
        'ai_api_key': _apiKeyCtrl.text.trim(),
        'ai_temperature': double.parse(_tempCtrl.text.trim()),
        'ai_max_tokens': int.parse(_tokensCtrl.text.trim()),
      });
      ref.invalidate(settingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ AI settings saved'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed: $e'), backgroundColor: Colors.red),
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
        title: const Text('AI Model Settings', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── API KEY (NEW - most important, shown first) ──
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.vpn_key_rounded, size: 20, color: Color(0xFF4F6EF7)),
                      SizedBox(width: 8),
                      Text('API Key', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      'Masukkan API key dari provider $_provider. Disimpan aman di backend, tidak dikirim ke pihak lain.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _apiKeyCtrl,
                      obscureText: !_apiKeyVisible,
                      decoration: InputDecoration(
                        hintText: 'sk-... atau AIza...',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: IconButton(
                          icon: Icon(_apiKeyVisible ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _apiKeyVisible = !_apiKeyVisible),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Provider List (NEW - full list) ──────────
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AI Provider', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 10),
                    ..._providers.map((p) => _buildProviderTile(p)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Model Dropdown (NEW - auto-populated) ────
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Model', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Otomatis tampil berdasarkan provider yang dipilih',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    const SizedBox(height: 10),
                    _loadingModels
                        ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                        : DropdownButtonFormField<String>(
                            value: _availableModels.contains(_model) ? _model : null,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.model_training),
                            ),
                            hint: const Text('Pilih model...'),
                            items: _availableModels.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (v) => setState(() => _model = v ?? ''),
                            validator: (v) => (v == null || v.isEmpty) ? 'Pilih model' : null,
                          ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Temperature ──────────────────────────────
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Temperature', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(_tempCtrl.text.isEmpty ? '0.3' : _tempCtrl.text,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4F6EF7))),
                    ]),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _tempCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: '0.3',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.thermostat),
                        suffixText: '0.0 - 1.0',
                      ),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null || n < 0 || n > 1) return '0.0 - 1.0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 4),
                    Text('Rendah = lebih deterministik. Tinggi = lebih kreatif.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Max Tokens ───────────────────────────────
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Max Output Tokens', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
                        if (n == null || n < 64 || n > 8192) return '64 - 8192';
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

  // ─── Provider tile with radio selection ──────────────
  Widget _buildProviderTile(_ProviderInfo p) {
    final selected = _provider == p.id;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _provider = p.id;
          _model = ''; // will auto-fill after fetch
        });
        _fetchModels();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? p.color.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? p.color : Colors.grey.shade200, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: p.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(p.icon, color: p.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(p.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: selected ? p.color : Colors.black87))),
            Radio<String>(
              value: p.id,
              groupValue: _provider,
              onChanged: (v) {
                setState(() => _provider = v!);
                _fetchModels();
              },
              activeColor: p.color,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderInfo {
  final String id;
  final String name;
  final Color color;
  final IconData icon;
  const _ProviderInfo(this.id, this.name, this.color, this.icon);
}
