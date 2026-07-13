// ============================================================
// DocMind Flutter — App Settings model + service
// ============================================================

class AppSettings {
  final String aiProvider;
  final String aiModel;
  final double aiTemperature;
  final int aiMaxTokens;
  final String wahaApiUrl;
  final String wahaSession;
  final int wahaPollingIntervalSeconds;
  final List<String> wahaGroupWhitelist;
  final bool ocrEnabled;
  final List<String> ocrKeywords;
  final String ocrLanguage;
  final String storageProvider;
  final String storageBucket;
  final String storageEndpoint;
  final String storageRegion;
  final int maxFileSizeMb;
  final List<String> allowedMimeTypes;
  final bool notificationsEnabled;
  final String notificationsWebhookUrl;

  const AppSettings({
    required this.aiProvider,
    required this.aiModel,
    required this.aiTemperature,
    required this.aiMaxTokens,
    required this.wahaApiUrl,
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
    required this.maxFileSizeMb,
    required this.allowedMimeTypes,
    required this.notificationsEnabled,
    required this.notificationsWebhookUrl,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      aiProvider: json['ai_provider'] as String? ?? 'gemini',
      aiModel: json['ai_model'] as String? ?? 'gemini-1.5-pro',
      aiTemperature: (json['ai_temperature'] as num?)?.toDouble() ?? 0.3,
      aiMaxTokens: json['ai_max_tokens'] as int? ?? 2048,
      wahaApiUrl: json['waha_api_url'] as String? ?? '',
      wahaSession: json['waha_session'] as String? ?? 'default',
      wahaPollingIntervalSeconds: json['waha_polling_interval_seconds'] as int? ?? 30,
      wahaGroupWhitelist: (json['waha_group_whitelist'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      ocrEnabled: json['ocr_enabled'] as bool? ?? true,
      ocrKeywords: (json['ocr_keywords'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      ocrLanguage: json['ocr_language'] as String? ?? 'ind+eng',
      storageProvider: json['storage_provider'] as String? ?? 'minio',
      storageBucket: json['storage_bucket'] as String? ?? '',
      storageEndpoint: json['storage_endpoint'] as String? ?? '',
      storageRegion: json['storage_region'] as String? ?? '',
      maxFileSizeMb: json['max_file_size_mb'] as int? ?? 20,
      allowedMimeTypes: (json['allowed_mime_types'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      notificationsEnabled: json['notifications_enabled'] as bool? ?? false,
      notificationsWebhookUrl: json['notifications_webhook_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ai_provider': aiProvider,
      'ai_model': aiModel,
      'ai_temperature': aiTemperature,
      'ai_max_tokens': aiMaxTokens,
      'waha_api_url': wahaApiUrl,
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
      'max_file_size_mb': maxFileSizeMb,
      'allowed_mime_types': allowedMimeTypes,
      'notifications_enabled': notificationsEnabled,
      'notifications_webhook_url': notificationsWebhookUrl,
    };
  }

  AppSettings copyWith({
    String? aiProvider,
    String? aiModel,
    double? aiTemperature,
    int? aiMaxTokens,
    String? wahaApiUrl,
    String? wahaSession,
    int? wahaPollingIntervalSeconds,
    List<String>? wahaGroupWhitelist,
    bool? ocrEnabled,
    List<String>? ocrKeywords,
    String? ocrLanguage,
    String? storageProvider,
    String? storageBucket,
    String? storageEndpoint,
    String? storageRegion,
    int? maxFileSizeMb,
    List<String>? allowedMimeTypes,
    bool? notificationsEnabled,
    String? notificationsWebhookUrl,
  }) {
    return AppSettings(
      aiProvider: aiProvider ?? this.aiProvider,
      aiModel: aiModel ?? this.aiModel,
      aiTemperature: aiTemperature ?? this.aiTemperature,
      aiMaxTokens: aiMaxTokens ?? this.aiMaxTokens,
      wahaApiUrl: wahaApiUrl ?? this.wahaApiUrl,
      wahaSession: wahaSession ?? this.wahaSession,
      wahaPollingIntervalSeconds:
          wahaPollingIntervalSeconds ?? this.wahaPollingIntervalSeconds,
      wahaGroupWhitelist: wahaGroupWhitelist ?? this.wahaGroupWhitelist,
      ocrEnabled: ocrEnabled ?? this.ocrEnabled,
      ocrKeywords: ocrKeywords ?? this.ocrKeywords,
      ocrLanguage: ocrLanguage ?? this.ocrLanguage,
      storageProvider: storageProvider ?? this.storageProvider,
      storageBucket: storageBucket ?? this.storageBucket,
      storageEndpoint: storageEndpoint ?? this.storageEndpoint,
      storageRegion: storageRegion ?? this.storageRegion,
      maxFileSizeMb: maxFileSizeMb ?? this.maxFileSizeMb,
      allowedMimeTypes: allowedMimeTypes ?? this.allowedMimeTypes,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationsWebhookUrl:
          notificationsWebhookUrl ?? this.notificationsWebhookUrl,
    );
  }

  Map<String, dynamic> toPatchJson() {
    /// Only include fields that differ from defaults for a PATCH request.
    return toJson();
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
