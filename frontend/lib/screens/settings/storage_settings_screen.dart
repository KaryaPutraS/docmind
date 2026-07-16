// ============================================================
// DocMind Flutter — Storage Settings Screen
// Supports: Google Drive (Service Account) OR VPS SFTP
// ============================================================
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/document_providers.dart';

enum StorageProvider { vps, googleDrive }

class StorageSettingsScreen extends ConsumerStatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  ConsumerState<StorageSettingsScreen> createState() =>
      _StorageSettingsScreenState();
}

class _StorageSettingsScreenState
    extends ConsumerState<StorageSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  StorageProvider _provider = StorageProvider.vps;
  bool _saving = false;
  bool _driveConnected = false;

  // ── VPS fields ───────────────────────────────────
  late TextEditingController _vpsHostCtrl;
  late TextEditingController _vpsPortCtrl;
  late TextEditingController _vpsUserCtrl;
  late TextEditingController _vpsPassCtrl;
  late TextEditingController _vpsBaseCtrl;
  late TextEditingController _vpsPublicCtrl;
  bool _vpsPassVisible = false;

  // ── Google Drive fields ──────────────────────────
  late TextEditingController _driveCredentialsCtrl;
  late TextEditingController _driveFolderCtrl;

  // ── General ──────────────────────────────────────
  late TextEditingController _maxSizeCtrl;

  @override
  void initState() {
    super.initState();
    _vpsHostCtrl = TextEditingController();
    _vpsPortCtrl = TextEditingController(text: '22');
    _vpsUserCtrl = TextEditingController();
    _vpsPassCtrl = TextEditingController();
    _vpsBaseCtrl = TextEditingController();
    _vpsPublicCtrl = TextEditingController();
    _driveCredentialsCtrl = TextEditingController();
    _driveFolderCtrl = TextEditingController();
    _maxSizeCtrl = TextEditingController();

    Future.microtask(() {
      final settingsAsync = ref.read(settingsProvider);
      settingsAsync.whenData((s) {
        setState(() {
          _provider = s.storageProvider == 'google_drive'
              ? StorageProvider.googleDrive
              : StorageProvider.vps;

          _vpsHostCtrl.text = s.vpsStorageHost;
          _vpsPortCtrl.text = s.vpsStoragePort.toString();
          _vpsUserCtrl.text = s.vpsStorageUsername;
          _vpsPassCtrl.text = s.vpsStoragePassword;
          _vpsBaseCtrl.text = s.vpsStorageBasePath;
          _vpsPublicCtrl.text = s.vpsStoragePublicBaseUrl;

          _driveCredentialsCtrl.text = s.googleDriveCredentialsJson;
          _driveFolderCtrl.text = s.googleDriveFolderId;
          _maxSizeCtrl.text = s.maxFileSizeMb.toString();
        });
      });
    });
  }

  @override
  void dispose() {
    _vpsHostCtrl.dispose();
    _vpsPortCtrl.dispose();
    _vpsUserCtrl.dispose();
    _vpsPassCtrl.dispose();
    _vpsBaseCtrl.dispose();
    _vpsPublicCtrl.dispose();
    _driveCredentialsCtrl.dispose();
    _driveFolderCtrl.dispose();
    _maxSizeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateSettings({
        'storage_provider':
            _provider == StorageProvider.googleDrive ? 'google_drive' : 'vps',
        'vps_storage_host': _vpsHostCtrl.text.trim(),
        'vps_storage_port': int.parse(_vpsPortCtrl.text.trim()),
        'vps_storage_username': _vpsUserCtrl.text.trim(),
        'vps_storage_password': _vpsPassCtrl.text.trim(),
        'vps_storage_base_path': _vpsBaseCtrl.text.trim(),
        'vps_storage_public_base_url': _vpsPublicCtrl.text.trim(),
        'google_drive_credentials_json': _driveCredentialsCtrl.text.trim(),
        'google_drive_folder_id': _driveFolderCtrl.text.trim(),
        'max_file_size_mb': int.parse(_maxSizeCtrl.text.trim()),
      });
      ref.invalidate(settingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _provider == StorageProvider.googleDrive
                  ? '✅ Drive settings saved'
                  : '✅ VPS Storage settings saved',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
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

  Future<void> _testConnection() async {
    try {
      final api = ref.read(apiServiceProvider);
      final status = await api.getSystemStatus();
      setState(() => _driveConnected = status.storageConnected);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _driveConnected
                  ? '✅ Storage: Connected'
                  : '⚠️ Storage: Not connected',
            ),
            backgroundColor: _driveConnected ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Connection test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVps = _provider == StorageProvider.vps;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A1F36),
        foregroundColor: Colors.white,
        title: const Text('Storage',
            style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_tethering),
            tooltip: 'Test connection',
            onPressed: _testConnection,
          ),
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
            // ── Provider toggle card ──────────────
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              color: isVps ? Colors.teal.shade700 : const Color(0xFF0F9D58),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(isVps ? Icons.dns : Icons.cloud_done_rounded,
                            size: 36, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isVps ? 'VPS Storage' : 'Google Drive',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                              Text(
                                isVps
                                    ? 'Upload via SFTP to your VPS'
                                    : 'Upload via Service Account to Drive',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<StorageProvider>(
                      segments: const [
                        ButtonSegment(
                            value: StorageProvider.vps,
                            label: Text('VPS'),
                            icon: Icon(Icons.dns)),
                        ButtonSegment(
                            value: StorageProvider.googleDrive,
                            label: Text('Drive'),
                            icon: Icon(Icons.cloud)),
                      ],
                      selected: {_provider},
                      onSelectionChanged: (v) =>
                          setState(() => _provider = v.first),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith(
                            (s) => Colors.white.withValues(alpha: 0.2)),
                        foregroundColor:
                            WidgetStateProperty.all(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── VPS fields ────────────────────────
            if (isVps) ...[
              _buildLabeledField(
                icon: Icons.link_rounded,
                label: 'VPS Host / Domain',
                hint: 'magang.vpsmso.site',
                controller: _vpsHostCtrl,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildLabeledField(
                      icon: Icons.numbers,
                      label: 'SFTP Port',
                      hint: '22',
                      controller: _vpsPortCtrl,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final port = int.tryParse(v ?? '');
                        if (port == null || port < 1 || port > 65535) {
                          return '1-65535';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: _buildLabeledField(
                      icon: Icons.person,
                      label: 'Username',
                      hint: 'magang',
                      controller: _vpsUserCtrl,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildCard(
                icon: Icons.lock,
                title: 'Password',
                child: TextFormField(
                  controller: _vpsPassCtrl,
                  obscureText: !_vpsPassVisible,
                  decoration: InputDecoration(
                    hintText: 'Enter SFTP password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.key),
                    suffixIcon: IconButton(
                      icon: Icon(_vpsPassVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _vpsPassVisible = !_vpsPassVisible),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildLabeledField(
                icon: Icons.folder_open,
                label: 'Base Path (VPS directory)',
                hint: '/home/magang/docmind_uploads',
                controller: _vpsBaseCtrl,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!v.startsWith('/')) return 'Must be absolute path';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildLabeledField(
                icon: Icons.public,
                label: 'Public Base URL',
                hint: 'https://magang.vpsmso.site/docmind_uploads',
                controller: _vpsPublicCtrl,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final uri = Uri.tryParse(v.trim());
                  if (uri == null || !uri.hasScheme) return 'Invalid URL';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'File akan diupload ke folder Base Path via SFTP '
                        'dan dapat diakses via Public Base URL.',
                        style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Google Drive fields ───────────────
            if (!isVps) ...[
              // ── Step-by-step guide ──────────────
              Card(
                elevation: 0,
                color: Colors.blue.shade50,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text('Cara mendapatkan Service Account JSON:',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.blue)),
                        ],
                      ),
                      SizedBox(height: 10),
                      _StepNumber(1, 'Buka Google Cloud Console'),
                      _StepNumber(2,
                          'Buat project → APIs & Services → Enable Drive API'),
                      _StepNumber(3,
                          'Credentials → Create Credentials → Service Account'),
                      _StepNumber(4,
                          'Isi nama → Done → klik email service account'),
                      _StepNumber(5,
                          'Keys → Add Key → Create New Key → JSON'),
                      _StepNumber(6,
                          'Download JSON → buka → copy seluruh isi'),
                      _StepNumber(7, 'Paste ke kolom di bawah ini'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ── Credentials JSON ────────────────
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
                          Icon(Icons.code,
                              size: 20, color: Color(0xFF0F9D58)),
                          SizedBox(width: 8),
                          Text('Service Account JSON Key',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _driveCredentialsCtrl,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          hintText:
                              'Paste the entire JSON content here...',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildLabeledField(
                icon: Icons.folder_shared,
                label: 'Google Drive Folder ID',
                hint: 'root (default) atau Folder ID spesifik',
                controller: _driveFolderCtrl,
              ),
              const SizedBox(height: 16),
            ],

            // ── Max file size ─────────────────────
            _buildLabeledField(
              icon: Icons.storage,
              label: 'Max Upload Size (MB)',
              hint: '20',
              controller: _maxSizeCtrl,
              keyboardType: TextInputType.number,
              validator: (v) {
                final size = int.tryParse(v ?? '');
                if (size == null || size < 1 || size > 500) return '1-500 MB';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    String? subtitle,
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
                Icon(icon, size: 20, color: const Color(0xFF4F6EF7)),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildLabeledField({
    required IconData icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return _buildCard(
      icon: icon,
      title: label,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        validator: validator,
      ),
    );
  }
}

class _StepNumber extends StatelessWidget {
  final int step;
  final String text;
  const _StepNumber(this.step, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text('$step',
                style: const TextStyle(
                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
          ),
        ],
      ),
    );
  }
}
