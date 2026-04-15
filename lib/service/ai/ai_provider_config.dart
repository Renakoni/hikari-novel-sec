class AiProviderConfig {
  final bool enabled;
  final String provider;
  final String baseUrl;
  final String apiKey;
  final String model;
  final double temperature;
  final int maxTokens;

  const AiProviderConfig({
    required this.enabled,
    required this.provider,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.temperature,
    required this.maxTokens,
  });

  bool get isReady => enabled && baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty && model.trim().isNotEmpty;
}
