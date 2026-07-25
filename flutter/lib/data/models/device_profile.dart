class DeviceProfile {
  final String deviceId;
  final String userContext;
  final String responseStyle;
  final String theme;
  final String ollamaModel;
  final String ollamaBaseUrl;

  const DeviceProfile({
    required this.deviceId,
    this.userContext = '',
    this.responseStyle = '',
    this.theme = 'system',
    this.ollamaModel = '',
    this.ollamaBaseUrl = '',
  });

  factory DeviceProfile.fromJson(Map<String, dynamic> json) => DeviceProfile(
    deviceId: json['device_id'] as String,
    userContext: json['user_context'] as String? ?? '',
    responseStyle: json['response_style'] as String? ?? '',
    theme: json['theme'] as String? ?? 'system',
    ollamaModel: json['ollama_model'] as String? ?? '',
    ollamaBaseUrl: json['ollama_base_url'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'user_context': userContext,
    'response_style': responseStyle,
    'theme': theme,
    'ollama_model': ollamaModel,
    'ollama_base_url': ollamaBaseUrl,
    'last_seen_at': DateTime.now().toIso8601String(),
  };
}
