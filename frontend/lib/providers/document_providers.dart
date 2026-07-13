// ============================================================
// DocMind Flutter — Riverpod providers
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/document_model.dart';
import '../services/api_service.dart';

// ── Singleton service ──────────────────────────────────────
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

// ── Current folder prefix (navigation state) ───────────────
final currentFolderProvider = StateProvider<String>((ref) => '');

// ── Folder tree (folder list + files at current prefix) ────
final folderTreeProvider = FutureProvider.family<FolderTree, String>(
  (ref, prefix) async {
    final api = ref.watch(apiServiceProvider);
    return api.getFolderTree(prefix: prefix);
  },
);

// ── Semantic search results ────────────────────────────────
final searchQueryProvider = StateProvider<String>((ref) => '');
final searchResultsProvider = FutureProvider.family<List<DocumentModel>, String>(
  (ref, query) async {
    if (query.trim().isEmpty) return [];
    final api = ref.watch(apiServiceProvider);
    return api.semanticSearch(query);
  },
);
