// ============================================================
// DocMind Flutter — Settings Screen (Master)
// Google Drive ONLY — no MinIO/S3/Firebase references.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/settings_model.dart';
import '../providers/document_providers.dart';
import 'settings/ai_settings_screen.dart';
import 'settings/waha_settings_screen.dart';
import 'settings/storage_settings_screen.dart';
import 'settings/ocr_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final statusAsync = ref.watch(systemStatusProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF4338CA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icon.jpg',
                width: 30,
                height: 30,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Settings',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── System Status Card ─────────────────────────
          _buildSectionHeader('System Status'),
          statusAsync.when(
            data: (status) => _buildStatusCard(status, context),
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('⚠️ Cannot reach backend: $e',
                    style: const TextStyle(color: Colors.orange)),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── AI Settings ────────────────────────────────
          _buildSectionHeader('AI / Gemini'),
          _buildMenuTile(
            context,
            icon: Icons.psychology_rounded,
            title: 'AI Model',
            subtitle: settingsAsync.whenOrNull(
                  data: (s) => '${s.aiProvider} › ${s.aiModel}',
                ) ??
                '...',
            color: const Color(0xFF7C3AED),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
            ),
          ),

          const SizedBox(height: 16),

          // ── WAHA / WhatsApp ────────────────────────────
          _buildSectionHeader('WhatsApp (WAHA)'),
          _buildMenuTile(
            context,
            icon: Icons.chat_rounded,
            title: 'WAHA Connection',
            subtitle: settingsAsync.whenOrNull(
                  data: (s) => s.wahaApiUrl,
                ) ??
                '...',
            color: const Color(0xFF25D366),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WahaSettingsScreen()),
            ),
          ),

          const SizedBox(height: 16),

          // ── Storage ────────────────────────────────────
          _buildSectionHeader('Storage'),
          _buildMenuTile(
            context,
            icon: Icons.cloud_done_rounded,
            title: 'Google Drive',
            subtitle: settingsAsync.whenOrNull(
                  data: (s) => s.googleDriveCredentialsJson.isNotEmpty
                      ? 'Connected · ${s.googleDriveFolderId}'
                      : 'Not configured',
                ) ??
                '...',
            color: const Color(0xFF0F9D58),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const StorageSettingsScreen()),
            ),
          ),

          const SizedBox(height: 16),

          // ── OCR ────────────────────────────────────────
          _buildSectionHeader('OCR & Document Filtering'),
          _buildMenuTile(
            context,
            icon: Icons.document_scanner_rounded,
            title: 'OCR Settings',
            subtitle: settingsAsync.whenOrNull(
                  data: (s) => s.ocrEnabled
                      ? '${s.ocrLanguage} · ${s.ocrKeywords.length} keywords'
                      : 'Disabled',
                ) ??
                '...',
            color: const Color(0xFFF59E0B),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OcrSettingsScreen()),
            ),
          ),

          const SizedBox(height: 24),

          // ── About ──────────────────────────────────────
          _buildSectionHeader('About'),
          Card(
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DocMind v3.1.0',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  SizedBox(height: 4),
                  Text(
                      'AI-Powered Automated Document Management System',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  SizedBox(height: 8),
                  Text(
                      'Built with: FastAPI · Flutter · PostgreSQL · Google Drive · Gemini AI',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              letterSpacing: 0.5)),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  Widget _buildStatusCard(SystemStatus status, BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _statusRow('API Server', status.api == 'running',
                Icons.dns_rounded),
            const Divider(height: 20),
            _statusRow('PostgreSQL',
                status.postgres == 'connected' || status.postgres == 'configured', Icons.storage_rounded),
            const Divider(height: 20),
            _statusRow('Google Drive',
                status.driveCredentialsSet, Icons.cloud_done_rounded),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, bool ok, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: ok ? Colors.green : Colors.red),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 14))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: ok ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            ok ? 'ONLINE' : 'OFFLINE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ok ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ),
      ],
    );
  }
}
