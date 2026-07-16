// ============================================================
// DocMind Flutter — App Settings model
// Google Drive ONLY storage.
// ============================================================
import 'dart:convert';

class AppSettings {
  // AI
  final String aiProvider;
  final String aiModel;
  final String aiApiKey;
  final double aiTemperature;
  final int aiMaxTokens;
  // WAHA
  final String wahaApiUrl;
  final String wahaApiKey;
  final String wahaWebhookSecret;
  final bool wahaHmacEnabled;
  final String wahaSession;
  final int wahaPollingIntervalSeconds;
  final List<String> wahaGroupWhitelist;
  // OCR
  final bool ocrEnabled;
  final List<String> ocrKeywords;
  final String ocrLanguage;
  // Storage
  final String storageProvider;
  // Google Drive
  final String googleDriveCredentialsJson;
  final String googleDriveFolderId;
  // VPS SFTP Storage
  final String vpsStorageHost;
  final int vpsStoragePort;
  final String vpsStorageUsername;
  final String vpsStoragePassword;
  final String vpsStorageBasePath;
  final String vpsStoragePublicBaseUrl;
  // General
  final int maxFileSizeMb;
  final List<String> allowedMimeTypes;
  final bool notificationsEnabled;
  final String notificationsWebhookUrl;

  const AppSettings({
    required this.aiProvider,
    required this.aiModel,
    required this.aiApiKey,
    required this.aiTemperature,
    required this.aiMaxTokens,
    required this.wahaApiUrl,
    required this.wahaApiKey,
    required this.wahaWebhookSecret,
    required this.wahaHmacEnabled,
    required this.wahaSession,
    required this.wahaPollingIntervalSeconds,
    required this.wahaGroupWhitelist,
    required this.ocrEnabled,
    required this.ocrKeywords,
    required this.ocrLanguage,
    required this.storageProvider,
    required this.googleDriveCredentialsJson,
    required this.googleDriveFolderId,
    required this.vpsStorageHost,
    required this.vpsStoragePort,
    required this.vpsStorageUsername,
    required this.vpsStoragePassword,
    required this.vpsStorageBasePath,
    required this.vpsStoragePublicBaseUrl,
    required this.maxFileSizeMb,
    required this.allowedMimeTypes,
    required this.notificationsEnabled,
    required this.notificationsWebhookUrl,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      aiProvider: json['ai_provider'] as String? ?? 'gemini',
      aiModel: json['ai_model'] as String? ?? 'gemini-1.5-pro',
      aiApiKey: json['ai_api_key'] as String? ?? '',
      aiTemperature: (json['ai_temperature'] as num?)?.toDouble() ?? 0.3,
      aiMaxTokens: json['ai_max_tokens'] as int? ?? 2048,
      wahaApiUrl: json['waha_api_url'] as String? ?? '',
      wahaApiKey: json['...ey'] as String? ?? '',
      wahaWebhookSecret: json['waha_webhook_secret'] as String? ?? '',
      wahaHmacEnabled: json['waha_hmac_enabled'] as bool? ?? false,
      wahaSession: json['waha_session'] as String? ?? 'default',
      wahaPollingIntervalSeconds:
          json['waha_polling_interval_seconds'] as int? ?? 30,
      wahaGroupWhitelist: _parseStringList(json['waha_group_whitelist']),
      ocrEnabled: json['ocr_enabled'] as bool? ?? true,
      ocrKeywords: _parseStringList(json['ocr_keywords']),
      ocrLanguage: json['ocr_language'] as String? ?? 'ind+eng',
      storageProvider:
          json['storage_provider'] as String? ?? 'vps',
      googleDriveCredentialsJson:
          _serializeJsonField(json['google_drive_credentials_json']),
      googleDriveFolderId:
          json['google_drive_folder_id'] as String? ?? 'root',
      vpsStorageHost: json['vps_storage_host'] as String? ?? '',
      vpsStoragePort: json['vps_storage_port'] as int? ?? 22,
      vpsStorageUsername: json['vps_storage_username'] as String? ?? '',
      vpsStoragePassword: json['vps_storage_password'] as String? ?? '',
      vpsStorageBasePath:
          json['vps_storage_base_path'] as String? ?? '',
      vpsStoragePublicBaseUrl:
          json['vps_storage_public_base_url'] as String? ?? '',
      maxFileSizeMb: json['max_file_size_mb'] as int? ?? 20,
      allowedMimeTypes: _parseStringList(json['allowed_mime_types']),
      notificationsEnabled: json['notifications_enabled'] as bool? ?? false,
      notificationsWebhookUrl:
          json['notifications_webhook_url'] as String? ?? '',
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  static String _serializeJsonField(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return jsonEncode(value);
  }

  Map<String, dynamic> toJson() {
    return {
      'ai_provider': aiProvider,
      'ai_model': aiModel,
      'ai_api_key': aiApiKey,
      'ai_temperature': aiTemperature,
      'ai_max_tokens': aiMaxTokens,
      'waha_api_url': wahaApiUrl,
      'waha_api_key': wahaApiKey,
      'waha_webhook_secret': wahaWebhookSecret,
      'waha_hmac_enabled': wahaHmacEnabled,
      'waha_session': wahaSession,
      'waha_polling_interval_seconds': wahaPollingIntervalSeconds,
      'waha_group_whitelist': wahaGroupWhitelist,
      'ocr_enabled': ocrEnabled,
      'ocr_keywords': ocrKeywords,
      'ocr_language': ocrLanguage,
      'storage_provider': storageProvider,
      'google_drive_credentials_json': googleDriveCredentialsJson,
      'google_drive_folder_id': googleDriveFolderId,
      'vps_storage_host': vpsStorageHost,
      'vps_storage_port': vpsStoragePort,
      'vps_storage_username': vpsStorageUsername,
      'vps_storage_password': vpsStoragePassword,
      'vps_storage_base_path': vpsStorageBasePath,
      'vps_storage_public_base_url': vpsStoragePublicBaseUrl,
      'max_file_size_mb': maxFileSizeMb,
      'allowed_mime_types': allowedMimeTypes,
      'notifications_enabled': notificationsEnabled,
      'notifications_webhook_url': notificationsWebhookUrl,
    };
  }
}

class SystemStatus {
  final String api;
  final String postgres;
  final String storage;
  final bool storageConnected;

  const SystemStatus({
    required this.api,
    required this.postgres,
    required this.storage,
    required this.storageConnected,
  });

  factory SystemStatus.fromJson(Map<String, dynamic> json) {
    return SystemStatus(
      api: json['api'] as String? ?? 'unknown',
      postgres: json['postgres'] as String? ?? 'unknown',
      storage: json['storage'] as String? ?? 'not-configured',
      storageConnected: json['storage_connected'] as bool? ?? false,
    );
  }
}
