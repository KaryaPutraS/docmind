// ============================================================
// DocMind Flutter — API Service (Dio client)
// ============================================================
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../models/document_model.dart';

class ApiService {
  late final Dio _dio;

  /// Override the base URL at runtime or via --dart-define=API_BASE_URL
  /// Default: Android emulator → host machine
  static const String _definedUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
  static String baseUrlOverride = _definedUrl;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrlOverride,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    if (kDebugMode) {
      _dio.interceptors.add(PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // List documents (paginated, optionally filtered by folder)
  // ─────────────────────────────────────────────────────────────
  Future<List<DocumentModel>> listDocuments({
    String? folder,
    String? category,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (folder != null && folder.isNotEmpty) params['folder'] = folder;
    if (category != null) params['category'] = category;

    final response = await _dio.get('/api/documents/', queryParameters: params);
    final list = (response.data as List<dynamic>)
        .map((json) => DocumentModel.fromJson(json as Map<String, dynamic>))
        .toList();
    return list;
  }

  // ─────────────────────────────────────────────────────────────
  // Folder tree (folders + files at a given prefix)
  // ─────────────────────────────────────────────────────────────
  Future<FolderTree> getFolderTree({String prefix = ''}) async {
    final response = await _dio.get(
      '/api/documents/tree',
      queryParameters: {'prefix': prefix},
    );
    return FolderTree.fromJson(response.data as Map<String, dynamic>);
  }

  // ─────────────────────────────────────────────────────────────
  // Semantic search
  // ─────────────────────────────────────────────────────────────
  Future<List<DocumentModel>> semanticSearch(String query, {int limit = 20}) async {
    final response = await _dio.post(
      '/api/documents/search',
      data: {'query': query, 'limit': limit},
    );
    final list = (response.data as List<dynamic>)
        .map((json) => DocumentModel.fromJson(json as Map<String, dynamic>))
        .toList();
    return list;
  }

  // ─────────────────────────────────────────────────────────────
  // Get single document (with pre-signed download URL)
  // ─────────────────────────────────────────────────────────────
  Future<DocumentModel> getDocument(String docId) async {
    final response = await _dio.get('/api/documents/$docId');
    return DocumentModel.fromJson(response.data as Map<String, dynamic>);
  }
}
