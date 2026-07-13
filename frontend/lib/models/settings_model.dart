// ============================================================
// DocMind Flutter — App Settings model (v2)
// Added: ai_api_key, waha_api_key, firebase_* fields
// ============================================================

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
  final String wahaSession;
  final int wahaPollingIntervalSeconds;
  final List<String> wahaGroupWhitelist;
  // OCR
  final bool ocrEnabled;
  final List<String> ocrKeywords;
  final String ocrLanguage;
  // Storage
  final String storageProvider;
  final String storageBucket;
  final String storageEndpoint;
  final String storageRegion;
  // Firebase
  final String firebaseApiKey;
  final String firebaseProjectId;
  final String firebaseStorageBucket;
  final String firebaseAppId;
  final String firebaseMessagingSenderId;
  final String firebaseAuthDomain;
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
    required this.wahaSession,
    required this.wahaPollingIntervalSeconds,
    required this.wahaGroupWhitelist,
    required this.ocrEnabled,
    required this.ocrKeywords,
    required this.ocrLanguage,
    required this.storageProvider,
    required this.storageBucket,
    required this.storageEndpoint,
    required this.storageRegion,
    required this.firebaseApiKey,
    required this.firebaseProjectId,
    required this.firebaseStorageBucket,
    required this.firebaseAppId,
    required this.firebaseMessagingSenderId,
    required this.firebaseAuthDomain,
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
      wahaApiKey: json['waha_api_key'] as String? ?? '',
      wahaSession: json['waha_session'] as String? ?? 'default',
      wahaPollingIntervalSeconds:
          json['waha_polling_interval_seconds'] as int? ?? 30,
      wahaGroupWhitelist: _parseStringList(json['waha_group_whitelist']),
      ocrEnabled: json['ocr_enabled'] as bool? ?? true,
      ocrKeywords: _parseStringList(json['ocr_keywords']),
      ocrLanguage: json['ocr_language'] as String? ?? 'ind+eng',
      storageProvider: json['storage_provider'] as String? ?? 'minio',
      storageBucket: json['storage_bucket'] as String? ?? '',
      storageEndpoint: json['storage_endpoint'] as String? ?? '',
      storageRegion: json['storage_region'] as String? ?? '',
      firebaseApiKey: json['firebase_api_key'] as String? ?? '',
      firebaseProjectId: json['firebase_project_id'] as String? ?? '',
      firebaseStorageBucket: json['firebase_storage_bucket'] as String? ?? '',
      firebaseAppId: json['firebase_app_id'] as String? ?? '',
      firebaseMessagingSenderId:
          json['firebase_messaging_sender_id'] as String? ?? '',
      firebaseAuthDomain: json['firebase_auth_domain'] as String? ?? '',
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

  Map<String, dynamic> toJson() {
    return {
      'ai_provider': aiProvider,
      'ai_model': aiModel,
      'ai_api_key': aiApiKey,
      'ai_temperature': aiTemperature,
      'ai_max_tokens': aiMaxTokens,
      'waha_api_url': wahaApiUrl,
      'waha_api_key': wahaApiKey,
      'waha_session': wahaSession,
      'waha_polling_interval_seconds': wahaPollingIntervalSeconds,
      'waha_group_whitelist': wahaGroupWhitelist,
      'ocr_enabled': ocrEnabled,
      'ocr_keywords': ocrKeywords,
      'ocr_language': ocrLanguage,
      'storage_provider': storageProvider,
      'storage_bucket': storageBucket,
      'storage_endpoint': storageEndpoint,
      'storage_region': storageRegion,
      'firebase_api_key': firebaseApiKey,
      'firebase_project_id': firebaseProjectId,
      'firebase_storage_bucket': firebaseStorageBucket,
      'firebase_app_id': firebaseAppId,
      'firebase_messaging_sender_id': firebaseMessagingSenderId,
      'firebase_auth_domain': firebaseAuthDomain,
      'max_file_size_mb': maxFileSizeMb,
      'allowed_mime_types': allowedMimeTypes,
      'notifications_enabled': notificationsEnabled,
      'notifications_webhook_url': notificationsWebhookUrl,
    };
  }
}

class SystemStatus {
  final String api;
  final bool geminiConfigured;
  final String minioEndpoint;
  final String minioBucket;
  final String postgresHost;
  final bool wahaWebhookSecretSet;
  final String postgres;
  final String minio;

  const SystemStatus({
    required this.api,
    required this.geminiConfigured,
    required this.minioEndpoint,
    required this.minioBucket,
    required this.postgresHost,
    required this.wahaWebhookSecretSet,
    required this.postgres,
    required this.minio,
  });

  factory SystemStatus.fromJson(Map<String, dynamic> json) {
    return SystemStatus(
      api: json['api'] as String? ?? 'unknown',
      geminiConfigured: json['gemini_configured'] as bool? ?? false,
      minioEndpoint: json['minio_endpoint'] as String? ?? '',
      minioBucket: json['minio_bucket'] as String? ?? '',
      postgresHost: json['postgres_host'] as String? ?? '',
      wahaWebhookSecretSet: json['waha_webhook_secret_set'] as bool? ?? false,
      postgres: json['postgres'] as String? ?? 'unknown',
      minio: json['minio'] as String? ?? 'unknown',
    );
  }
}
