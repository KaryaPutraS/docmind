// ============================================================
// DocMind Flutter — Storage (MinIO) Settings Screen
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/document_providers.dart';

class StorageSettingsScreen extends ConsumerStatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  ConsumerState<StorageSettingsScreen> createState() =>
      _StorageSettingsScreenState();
}

class _StorageSettingsScreenState
    extends ConsumerState<StorageSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _endpointCtrl;
  late TextEditingController _bucketCtrl;
  late TextEditingController _regionCtrl;
  late TextEditingController _maxSizeCtrl;
  String _provider = 'minio';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _endpointCtrl = TextEditingController();
    _bucketCtrl = TextEditingController();
    _regionCtrl = TextEditingController();
    _maxSizeCtrl = TextEditingController();

    Future.microtask(() {
      final settingsAsync = ref.read(settingsProvider);
      settingsAsync.whenData((s) {
        setState(() {
          _endpointCtrl.text = s.storageEndpoint;
          _bucketCtrl.text = s.storageBucket;
          _regionCtrl.text = s.storageRegion;
          _maxSizeCtrl.text = s.maxFileSizeMb.toString();
          _provider = s.storageProvider;
        });
      });
    });
  }

  @override
  void dispose() {
    _endpointCtrl.dispose();
    _bucketCtrl.dispose();
    _regionCtrl.dispose();
    _maxSizeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateSettings({
        'storage_provider': _provider,
        'storage_endpoint': _endpointCtrl.text.trim(),
        'storage_bucket': _bucketCtrl.text.trim(),
        'storage_region': _regionCtrl.text.trim(),
        'max_file_size_mb': int.parse(_maxSizeCtrl.text.trim()),
      });
      ref.invalidate(settingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Storage settings saved'),
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
        title: const Text('Storage Config',
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
                    const Text('Storage Provider',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'minio',
                            label: Text('MinIO'),
                            icon: Icon(Icons.storage)),
                        ButtonSegment(
                            value: 's3',
                            label: Text('AWS S3'),
                            icon: Icon(Icons.cloud)),
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

            // ── Endpoint ──────────────────────────
            _buildInputCard(
              icon: Icons.dns_rounded,
              title: 'Endpoint',
              subtitle: 'Host:port of your S3-compatible storage',
              controller: _endpointCtrl,
              hint: 'localhost:9000',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),

            const SizedBox(height: 12),

            // ── Bucket ────────────────────────────
            _buildInputCard(
              icon: Icons.folder_special_rounded,
              title: 'Bucket Name',
              subtitle: 'The bucket where documents will be stored',
              controller: _bucketCtrl,
              hint: 'docmind-documents',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),

            const SizedBox(height: 12),

            // ── Region ────────────────────────────
            _buildInputCard(
              icon: Icons.public_rounded,
              title: 'Region',
              subtitle: 'AWS region (for S3) or leave as us-east-1 for MinIO',
              controller: _regionCtrl,
              hint: 'us-east-1',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),

            const SizedBox(height: 12),

            // ── Max File Size ─────────────────────
            _buildInputCard(
              icon: Icons.data_usage_rounded,
              title: 'Max File Size (MB)',
              subtitle: 'Files larger than this will be rejected',
              controller: _maxSizeCtrl,
              hint: '20',
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1 || n > 500)
                  return 'Must be 1 - 500 MB';
                return null;
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
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
                Icon(icon, size: 20, color: const Color(0xFF0EA5E9)),
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
            TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
              ),
              validator: validator,
            ),
          ],
        ),
      ),
    );
  }
}
