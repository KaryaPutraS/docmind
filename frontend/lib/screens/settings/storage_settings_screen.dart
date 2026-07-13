// ============================================================
// DocMind Flutter — Storage Settings Screen
// Google Drive ONLY — paste Service Account JSON + folder ID.
// ============================================================
import 'dart:convert';

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
  late TextEditingController _credentialsCtrl;
  late TextEditingController _folderIdCtrl;
  late TextEditingController _maxSizeCtrl;
  bool _saving = false;
  bool _driveConnected = false;

  @override
  void initState() {
    super.initState();
    _credentialsCtrl = TextEditingController();
    _folderIdCtrl = TextEditingController();
    _maxSizeCtrl = TextEditingController();

    Future.microtask(() {
      final settingsAsync = ref.read(settingsProvider);
      settingsAsync.whenData((s) {
        setState(() {
          _credentialsCtrl.text = s.googleDriveCredentialsJson;
          _folderIdCtrl.text = s.googleDriveFolderId;
          _maxSizeCtrl.text = s.maxFileSizeMb.toString();
        });
      });
    });
  }

  @override
  void dispose() {
    _credentialsCtrl.dispose();
    _folderIdCtrl.dispose();
    _maxSizeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.updateSettings({
        'google_drive_credentials_json': _credentialsCtrl.text.trim(),
        'google_drive_folder_id': _folderIdCtrl.text.trim(),
        'max_file_size_mb': int.parse(_maxSizeCtrl.text.trim()),
      });
      ref.invalidate(settingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Google Drive settings saved'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
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
      setState(() => _driveConnected = status.driveCredentialsSet);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _driveConnected
                  ? '✅ Google Drive: Connected'
                  : '⚠️ Google Drive: Not configured',
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A1F36),
        foregroundColor: Colors.white,
        title: const Text('Google Drive',
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
            // ── Google Drive branding ──────────────
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              color: const Color(0xFF0F9D58),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.cloud_done_rounded,
                        size: 40, color: Colors.white),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Google Drive',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                          SizedBox(height: 4),
                          Text(
                            'Semua file otomatis tersimpan ke Google Drive.\n'
                            'Gunakan Service Account untuk akses programmatic.',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Step-by-step guide ──────────────────
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
                    _StepNumber(2, 'Buat project → APIs & Services → Enable Drive API'),
                    _StepNumber(3, 'Credentials → Create Credentials → Service Account'),
                    _StepNumber(4, 'Isi nama → Done → klik email service account'),
                    _StepNumber(5, 'Keys → Add Key → Create New Key → JSON'),
                    _StepNumber(6, 'Download JSON → buka → copy seluruh isi'),
                    _StepNumber(7, 'Paste ke kolom di bawah ini'),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.folder_shared, color: Colors.amber, size: 18),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Opsional: isi Folder ID untuk menyimpan di folder tertentu.\n'
                            'Kosongkan untuk upload ke "My Drive" root.',
                            style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Credentials JSON ────────────────────
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
                        Icon(Icons.code, size: 20, color: Color(0xFF0F9D58)),
                        SizedBox(width: 8),
                        Text('Service Account JSON Key',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Paste seluruh isi file JSON Service Account di sini.\n'
                      'Format: {"type":"service_account","project_id":"...", ...}',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _credentialsCtrl,
                      maxLines: 12,
                      style: const TextStyle(
                          fontSize: 11, fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        hintText:
                            '{\n  "type": "service_account",\n  "project_id": "docmind-xxx",\n  "private_key": "-----BEGIN PRIVATE KEY-----\\n...",\n  "client_email": "docmind@docmind-xxx.iam.gserviceaccount.com",\n  ...\n}',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Service Account JSON wajib diisi';
                        try {
                          jsonDecode(v.trim());
                        } catch (_) {
                          return 'Format JSON tidak valid — pastikan copy dari file .json';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Folder ID ──────────────────────────
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
                        Icon(Icons.folder_rounded,
                            size: 20, color: Color(0xFF0F9D58)),
                        SizedBox(width: 8),
                        Text('Google Drive Folder ID',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID folder dari URL Google Drive:\n'
                      'https://drive.google.com/drive/folders/<ID INI>\n'
                      'Kosongkan: "root" (My Drive).',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _folderIdCtrl,
                      decoration: const InputDecoration(
                        hintText: 'root (atau folder ID, contoh: 1xYZ9abc123...)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.folder_open),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Max file size ──────────────────────
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
                        Icon(Icons.data_usage_rounded,
                            size: 20, color: Color(0xFF0F9D58)),
                        SizedBox(width: 8),
                        Text('Max File Size (MB)',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'File > ukuran ini akan ditolak.',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _maxSizeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '20',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.storage),
                        suffixText: '1 - 500 MB',
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 1 || n > 500)
                          return '1 - 500 MB';
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

class _StepNumber extends StatelessWidget {
  final int number;
  final String text;
  const _StepNumber(this.number, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text('$number',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey,
                    height: 1.5)),
          ),
        ],
      ),
    );
  }
}
