// ============================================================
// DocMind Flutter — Storage Settings Screen (v2)
// Added: Firebase provider option with required Firebase config fields
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
  // Firebase fields
  late TextEditingController _fbApiKeyCtrl;
  late TextEditingController _fbProjectIdCtrl;
  late TextEditingController _fbStorageBucketCtrl;
  late TextEditingController _fbAppIdCtrl;
  late TextEditingController _fbSenderIdCtrl;
  late TextEditingController _fbAuthDomainCtrl;

  String _provider = 'minio';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _endpointCtrl = TextEditingController();
    _bucketCtrl = TextEditingController();
    _regionCtrl = TextEditingController();
    _maxSizeCtrl = TextEditingController();
    _fbApiKeyCtrl = TextEditingController();
    _fbProjectIdCtrl = TextEditingController();
    _fbStorageBucketCtrl = TextEditingController();
    _fbAppIdCtrl = TextEditingController();
    _fbSenderIdCtrl = TextEditingController();
    _fbAuthDomainCtrl = TextEditingController();

    Future.microtask(() {
      final settingsAsync = ref.read(settingsProvider);
      settingsAsync.whenData((s) {
        setState(() {
          _provider = s.storageProvider;
          _endpointCtrl.text = s.storageEndpoint;
          _bucketCtrl.text = s.storageBucket;
          _regionCtrl.text = s.storageRegion;
          _maxSizeCtrl.text = s.maxFileSizeMb.toString();
          _fbApiKeyCtrl.text = s.firebaseApiKey;
          _fbProjectIdCtrl.text = s.firebaseProjectId;
          _fbStorageBucketCtrl.text = s.firebaseStorageBucket;
          _fbAppIdCtrl.text = s.firebaseAppId;
          _fbSenderIdCtrl.text = s.firebaseMessagingSenderId;
          _fbAuthDomainCtrl.text = s.firebaseAuthDomain;
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
    _fbApiKeyCtrl.dispose();
    _fbProjectIdCtrl.dispose();
    _fbStorageBucketCtrl.dispose();
    _fbAppIdCtrl.dispose();
    _fbSenderIdCtrl.dispose();
    _fbAuthDomainCtrl.dispose();
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
        'firebase_api_key': _fbApiKeyCtrl.text.trim(),
        'firebase_project_id': _fbProjectIdCtrl.text.trim(),
        'firebase_storage_bucket': _fbStorageBucketCtrl.text.trim(),
        'firebase_app_id': _fbAppIdCtrl.text.trim(),
        'firebase_messaging_sender_id': _fbSenderIdCtrl.text.trim(),
        'firebase_auth_domain': _fbAuthDomainCtrl.text.trim(),
      });
      ref.invalidate(settingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Storage settings saved'),
              backgroundColor: Colors.green, duration: Duration(seconds: 2)),
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
        title: const Text('Storage Config',
            style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20,
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _providerChip('minio', 'MinIO', Icons.storage,
                            const Color(0xFFC63527)),
                        _providerChip('s3', 'AWS S3', Icons.cloud,
                            const Color(0xFFF90)),
                        _providerChip('firebase', 'Firebase',
                            Icons.local_fire_department,
                            const Color(0xFFFFA000)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Firebase fields (shown only when firebase selected) ─
            if (_provider == 'firebase') ...[
              _sectionHeader('Firebase Configuration',
                  'Dapatkan dari Firebase Console → Project Settings → General'),
              _buildInputCard(
                icon: Icons.vpn_key_rounded,
                title: 'Firebase API Key',
                subtitle: 'Web API Key dari Firebase project',
                controller: _fbApiKeyCtrl,
                hint: 'AIzaSy...',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              _buildInputCard(
                icon: Icons.badge_rounded,
                title: 'Project ID',
                subtitle: 'ID project Firebase',
                controller: _fbProjectIdCtrl,
                hint: 'docmind-xxxxx',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              _buildInputCard(
                icon: Icons.cloud_sync_rounded,
                title: 'Storage Bucket',
                subtitle: 'gRPC bucket URL (biasanya <project>.appspot.com)',
                controller: _fbStorageBucketCtrl,
                hint: 'docmind-xxxxx.appspot.com',
              ),
              const SizedBox(height: 12),
              _buildInputCard(
                icon: Icons.phone_iphone_rounded,
                title: 'App ID',
                subtitle: 'Firebase App ID (ada di Project Settings)',
                controller: _fbAppIdCtrl,
                hint: '1:123456789:android:...',
              ),
              const SizedBox(height: 12),
              _buildInputCard(
                icon: Icons.notifications_active_rounded,
                title: 'Messaging Sender ID',
                subtitle: 'Firebase Cloud Messaging sender ID',
                controller: _fbSenderIdCtrl,
                hint: '123456789012',
              ),
              const SizedBox(height: 12),
              _buildInputCard(
                icon: Icons.language_rounded,
                title: 'Auth Domain',
                subtitle: 'Firebase Auth domain',
                controller: _fbAuthDomainCtrl,
                hint: 'docmind-xxxxx.firebaseapp.com',
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.blue.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Untuk mendapatkan Firebase config:\n'
                          '1. Buka Firebase Console → Project Settings\n'
                          '2. Tab General → scroll ke "Your apps"\n'
                          '3. Pilih Web App → copy Firebase config JSON\n'
                          '4. Paste masing-masing field di atas',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],

            // ── S3/MinIO fields (hidden for firebase) ────
            if (_provider != 'firebase') ...[
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
              _buildInputCard(
                icon: Icons.public_rounded,
                title: 'Region',
                subtitle:
                    'AWS region (for S3) or leave as us-east-1 for MinIO',
                controller: _regionCtrl,
                hint: 'us-east-1',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
            ],

            // ── Max File Size (always shown) ─────────
            _buildInputCard(
              icon: Icons.data_usage_rounded,
              title: 'Max File Size (MB)',
              subtitle: 'Files larger than this will be rejected',
              controller: _maxSizeCtrl,
              hint: '20',
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1 || n > 500) return '1 - 500 MB';
                return null;
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _providerChip(
      String id, String label, IconData icon, Color color) {
    final selected = _provider == id;
    return ChoiceChip(
      selected: selected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: selected ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selectedColor: color,
      backgroundColor: color.withOpacity(0.08),
      labelStyle: TextStyle(
        color: selected ? Colors.white : color,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      onSelected: (_) => setState(() => _provider = id),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1F36))),
          Text(subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
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
