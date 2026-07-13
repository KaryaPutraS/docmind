// ============================================================
// DocMind Flutter — Document model
// ============================================================

class DocumentModel {
  final String id;
  final String originalFilename;
  final String newFilename;
  final String? category;
  final String? folderPath;
  final String? mimeType;
  final int? fileSize;
  final String? aiSummary;
  final DateTime? processedAt;
  final String? downloadUrl;

  const DocumentModel({
    required this.id,
    required this.originalFilename,
    required this.newFilename,
    this.category,
    this.folderPath,
    this.mimeType,
    this.fileSize,
    this.aiSummary,
    this.processedAt,
    this.downloadUrl,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as String,
      originalFilename: json['original_filename'] as String,
      newFilename: json['new_filename'] as String,
      category: json['category'] as String?,
      folderPath: json['folder_path'] as String?,
      mimeType: json['mime_type'] as String?,
      fileSize: json['file_size'] as int?,
      aiSummary: json['ai_summary'] as String?,
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'] as String)
          : null,
      downloadUrl: json['download_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'original_filename': originalFilename,
      'new_filename': newFilename,
      if (category != null) 'category': category,
      if (folderPath != null) 'folder_path': folderPath,
      if (mimeType != null) 'mime_type': mimeType,
      if (fileSize != null) 'file_size': fileSize,
      if (aiSummary != null) 'ai_summary': aiSummary,
      if (processedAt != null) 'processed_at': processedAt!.toIso8601String(),
      if (downloadUrl != null) 'download_url': downloadUrl,
    };
  }
}

class FolderTree {
  final List<String> folders;
  final List<DocumentModel> files;

  const FolderTree({
    required this.folders,
    required this.files,
  });

  factory FolderTree.fromJson(Map<String, dynamic> json) {
    return FolderTree(
      folders: (json['folders'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      files: (json['files'] as List<dynamic>?)
              ?.map((e) =>
                  DocumentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'folders': folders,
      'files': files.map((e) => e.toJson()).toList(),
    };
  }
}
