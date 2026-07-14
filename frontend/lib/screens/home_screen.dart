// ============================================================
// DocMind Flutter — Home Screen (Drive-like UI)
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../models/document_model.dart';
import '../providers/document_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final prefix = ref.watch(currentFolderProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final isSearching = searchQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: _buildAppBar(isSearching),
      body: Column(
        children: [
          if (!isSearching) _buildBreadcrumbs(prefix),
          Expanded(
            child: isSearching ? _buildSearchResults(searchQuery) : _buildFolderView(prefix),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => ref.invalidate(folderTreeProvider(prefix)),
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh_rounded),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // App Bar with dynamic search toggle
  // ─────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(bool isSearching) {
    return AppBar(
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF4338CA)], // Deep violet to indigo
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      foregroundColor: Colors.white,
      title: isSearching
          ? _SearchBar(
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value.trim();
              },
            )
          : Row(
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
                  'DocMind',
                  style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
              ],
            ),
      actions: [
        IconButton(
          icon: Icon(isSearching ? Icons.close : Icons.search_rounded),
          onPressed: () {
            if (isSearching) {
              ref.read(searchQueryProvider.notifier).state = '';
            } else {
              ref.read(searchQueryProvider.notifier).state = ' ';
            }
          },
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Breadcrumb trail for folder navigation
  // ─────────────────────────────────────────────────────────────
  Widget _buildBreadcrumbs(String path) {
    final parts = path.isEmpty ? <String>[] : path.split('/');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => ref.read(currentFolderProvider.notifier).state = '',
              child: const Text('🏠 Root', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            for (int i = 0; i < parts.length; i++) ...[
              const Text('  ›  ', style: TextStyle(color: Colors.grey)),
              GestureDetector(
                onTap: () {
                  final newPath = parts.sublist(0, i + 1).join('/');
                  ref.read(currentFolderProvider.notifier).state = newPath;
                },
                child: Text(
                  parts[i],
                  style: TextStyle(
                    fontWeight: i == parts.length - 1 ? FontWeight.w700 : FontWeight.w500,
                    color: i == parts.length - 1 ? const Color(0xFF6366F1) : Colors.black87,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Main folder + file list view
  // ─────────────────────────────────────────────────────────────
  Widget _buildFolderView(String prefix) {
    final treeAsync = ref.watch(folderTreeProvider(prefix));

    return treeAsync.when(
      data: (tree) => _buildTreeContent(tree, prefix),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('Failed to load', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.invalidate(folderTreeProvider(prefix)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTreeContent(FolderTree tree, String prefix) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(folderTreeProvider(prefix));
      },
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (tree.folders.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Folders',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
            ),
            ...tree.folders.map((f) => _buildFolderTile(f, prefix)),
            const SizedBox(height: 12),
          ],
          if (tree.files.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Files',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
            ),
          ...tree.files.map((doc) => _buildFileTile(doc)),
          if (tree.folders.isEmpty && tree.files.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('📂 This folder is empty.\nSend a document via WhatsApp!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 15)),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Folder tile → tap to navigate deeper
  // ─────────────────────────────────────────────────────────────
  Widget _buildFolderTile(String folderName, String currentPrefix) {
    final display = folderName.split('/').last;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.folder_rounded, color: Color(0xFF6366F1), size: 36),
        title: Text(display, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () {
          ref.read(currentFolderProvider.notifier).state = folderName;
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // File tile
  // ─────────────────────────────────────────────────────────────
  Widget _buildFileTile(DocumentModel doc) {
    return Card(
      child: ListTile(
        leading: _fileIcon(doc.mimeType),
        title: Text(
          doc.newFilename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: Row(
          children: [
            if (doc.category != null) _categoryChip(doc.category!),
            const SizedBox(width: 8),
            Text(
              _formatSize(doc.fileSize),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Spacer(),
            if (doc.processedAt != null)
              Text(
                timeago.format(doc.processedAt!, locale: 'id'),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.download_rounded, size: 20),
          onPressed: () => _downloadFile(doc),
        ),
        onTap: () => _showDetailSheet(doc),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Semantic search results
  // ─────────────────────────────────────────────────────────────
  Widget _buildSearchResults(String query) {
    final resultsAsync = ref.watch(searchResultsProvider(query));

    return resultsAsync.when(
      data: (docs) {
        if (docs.isEmpty) {
          return const Center(
            child: Text('🔍 No results found.',
                style: TextStyle(color: Colors.grey, fontSize: 15)),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(searchResultsProvider(query));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (_, i) => _buildFileTile(docs[i]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text('Search error: $err', style: const TextStyle(color: Colors.redAccent)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Detail bottom sheet
  // ─────────────────────────────────────────────────────────────
  void _showDetailSheet(DocumentModel doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        maxChildSize: 0.85,
        minChildSize: 0.25,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(doc.newFilename,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _detailRow('📄 Original', doc.originalFilename),
              _detailRow('📁 Folder', doc.folderPath ?? '-'),
              _detailRow('🏷️ Category', doc.category ?? '-'),
              if (doc.aiSummary != null) ...[
                const SizedBox(height: 12),
                const Text('Summary', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(doc.aiSummary!, style: const TextStyle(color: Colors.black87, fontSize: 14)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Utility helpers
  // ─────────────────────────────────────────────────────────────
  Widget _fileIcon(String? mime) {
    IconData icon;
    if (mime == 'application/pdf') {
      icon = Icons.picture_as_pdf;
    } else if (mime != null && mime.startsWith('image/')) {
      icon = Icons.image;
    } else {
      icon = Icons.insert_drive_file;
    }
    return Icon(icon, size: 36, color: const Color(0xFF6366F1));
  }

  Widget _categoryChip(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        category,
        style: const TextStyle(fontSize: 11, color: Color(0xFF4F6EF7), fontWeight: FontWeight.w700),
      ),
    );
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Future<void> _downloadFile(DocumentModel doc) async {
    String? url = doc.downloadUrl;

    if (url == null) {
      try {
        final api = ref.read(apiServiceProvider);
        final full = await api.getDocument(doc.id);
        url = full.downloadUrl;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to get download link')),
          );
        }
        return;
      }
    }

    if (url != null && mounted) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open download link')),
            );
          }
        }
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// Standalone search bar widget — owns its own controller
// ─────────────────────────────────────────────────────────────────
class _SearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.onChanged});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: true,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: const InputDecoration(
        hintText: 'Semantic search...',
        hintStyle: TextStyle(color: Colors.white54),
        border: InputBorder.none,
      ),
      onChanged: widget.onChanged,
    );
  }
}
