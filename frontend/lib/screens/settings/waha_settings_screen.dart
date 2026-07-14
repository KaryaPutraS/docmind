// ============================================================
// DocMind Flutter — WAHA (WhatsApp) Settings Screen (v3)
// Added: WAHA API Key, Webhook Secret fields
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/document_providers.dart';

class WahaSettingsScreen extends ConsumerStatefulWidget {
  const WahaSettingsScreen({super.key});

  @override
  ConsumerState<WahaSettingsScreen> createState() =>
      _WahaSettingsScreenState();
}

class _WahaSettingsScreenState extends ConsumerState<WahaSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _apiUrlCtrl;
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _webhookSecretCtrl;
  late TextEditingController _sessionCtrl;
  late TextEditingController _pollingCtrl;
  late TextEditingController _whitelistCtrl;
  bool _apiKeyVisible = false;
  bool _webhookSecretVisible = false;
  bool _hmacEnabled = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _apiUrlCtrl = TextEditingController();
    _apiKeyCtrl = TextEditingController();
    _webhookSecretCtrl = TextEditingController();
    _sessionCtrl = TextEditingController();
    _pollingCtrl = TextEditingController();
    _whitelistCtrl = TextEditingController();

    Future.microtask(() {
      final settingsAsync = ref.read(settingsProvider);
      settingsAsync.whenData((s) {
        setState(() {
          _apiUrlCtrl.text = s.wahaApiUrl;
          _apiKeyCtrl.text = s.wahaApiKey;
          _webhookSecretCtrl.text = s.wahaWebhookSecret;
          _hmacEnabled = s.wahaHmacEnabled;
          _sessionCtrl.text = s.wahaSession;
          _pollingCtrl.text = s.wahaPollingIntervalSeconds.toString();
          _whitelistCtrl.text = s.wahaGroupWhitelist.join(', ');
        });
      });
    });
  }

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _webhookSecretCtrl.dispose();
    _sessionCtrl.dispose();
    _pollingCtrl.dispose();
    _whitelistCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateSettings({
        'waha_api_url': _apiUrlCtrl.text.trim(),
        'waha_api_key': _apiKeyCtrl.text.trim(),
        'waha_webhook_secret': _webhookSecretCtrl.text.trim(),
        'waha_hmac_enabled': _hmacEnabled,
        'waha_session': _sessionCtrl.text.trim(),
        'waha_polling_interval_seconds':
            int.parse(_pollingCtrl.text.trim()),
        'waha_group_whitelist': _whitelistCtrl.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      });
      ref.invalidate(settingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ WAHA settings saved'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed: $e'),
              backgroundColor: Colors.red),
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
        title: const Text('WAHA Connection',
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
            // ── WAHA API URL ──────────────────────
            _buildCard(
              icon: Icons.link_rounded,
              title: 'WAHA API URL',
              subtitle: 'The full HTTP URL of your WAHA instance',
              child: TextFormField(
                controller: _apiUrlCtrl,
                decoration: const InputDecoration(
                  hintText: 'http://43.156.71.166:3000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final uri = Uri.tryParse(v.trim());
                  if (uri == null || !uri.hasScheme) return 'Invalid URL';
                  return null;
                },
              ),
            ),

            const SizedBox(height: 12),

            // ── WAHA API KEY ──────────────────────
            _buildCard(
              icon: Icons.vpn_key_rounded,
              title: 'WAHA API Key',
              subtitle: 'API key / token for authenticating with the WAHA server',
              child: TextFormField(
                controller: _apiKeyCtrl,
                obscureText: !_apiKeyVisible,
                decoration: InputDecoration(
                  hintText: 'your-waha-api-key-or-token',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: IconButton(
                    icon: Icon(_apiKeyVisible
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _apiKeyVisible = !_apiKeyVisible),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── WEBHOOK SECRET ────────────────────
            _buildCard(
              icon: Icons.security_rounded,
              title: 'Webhook Secret',
              subtitle: 'Shared secret for HMAC signature verification.\n'
                  'Set the same value in WAHA\'s WEBHOOK_SECRET config.\n'
                  'WAHA must POST to: http://43.156.71.166/webhook/waha',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _webhookSecretCtrl,
                    obscureText: !_webhookSecretVisible,
                    decoration: InputDecoration(
                      hintText: 'generate-a-random-secret-here',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_webhookSecretVisible
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(
                            () => _webhookSecretVisible = !_webhookSecretVisible),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required for production';
                      if (v.trim().length < 8) return 'Min 8 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  // HMAC Enable/Disable Toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable HMAC Verification',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    subtitle: const Text(
                      'OFF = accept all webhooks (for testing). ON = require matching signature.',
                      style: TextStyle(fontSize: 10),
                    ),
                    value: _hmacEnabled,
                    activeColor: const Color(0xFF25D366),
                    dense: true,
                    onChanged: (val) => setState(() => _hmacEnabled = val),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'WAHA Webhook URL: http://43.156.71.166/webhook/waha',
                            style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Session ───────────────────────────
            _buildCard(
              icon: Icons.smartphone_rounded,
              title: 'Session Name',
              subtitle: 'WAHA session ID (e.g. "default" or "ops")',
              child: TextFormField(
                controller: _sessionCtrl,
                decoration: const InputDecoration(
                  hintText: 'default',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_android),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),

            const SizedBox(height: 12),

            // ── Polling Interval ──────────────────
            _buildCard(
              icon: Icons.timer_rounded,
              title: 'Polling Interval',
              subtitle:
                  'How often the backend polls WAHA for new messages (seconds)',
              child: TextFormField(
                controller: _pollingCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '30',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.timer),
                  suffixText: '5 - 300 sec',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 5 || n > 300)
                    return 'Must be 5 - 300';
                  return null;
                },
              ),
            ),

            const SizedBox(height: 12),

            // ── Group Whitelist ───────────────────
            _buildCard(
              icon: Icons.group_work_rounded,
              title: 'Group Whitelist',
              subtitle:
                  'Comma-separated group chat IDs. Leave empty to process files from all chats.',
              child: TextFormField(
                controller: _whitelistCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '6281234567890@g.us, 6289...@g.us',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.group_add),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF25D366)),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
