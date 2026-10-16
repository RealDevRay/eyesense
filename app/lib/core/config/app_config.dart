class AppConfig {
  static const String appName = 'EyeSense';
  static const String tagline = 'Your world, described.';

  // Default API Base URL (configurable via --dart-define=API_BASE_URL=...)
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://eyesense-api.klantrilogy.workers.dev',
  );

  // Default Demo Access Token for Hosted Mode (configurable via --dart-define=HOSTED_ACCESS_TOKEN=...)
  static const String defaultDemoAccessToken = String.fromEnvironment(
    'HOSTED_ACCESS_TOKEN',
    defaultValue: 'eyesense-pilot-token-rotated-2026',
  );

  // Fixed Groq API Endpoint for BYOK direct mode
  static const String groqDirectApiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String groqModelsApiUrl = 'https://api.groq.com/openai/v1/models';

  // Supported Vision Model
  static const String defaultVisionModel = 'qwen/qwen3.8-27b';
  static const List<String> supportedModels = [
    'qwen/qwen3.8-27b',
  ];

  // Request & Freshness Timeouts
  static const Duration clientTimeout = Duration(seconds: 15);
  static const Duration sceneFreshnessLimit = Duration(seconds: 15);
  static const Duration conversationTurnExpiry = Duration(seconds: 60);

  // Image capture tuning
  static const int maxImageLongEdge = 1280;
  static const int jpegQuality = 80;
  static const int maxImageDecodedBytes = 1024 * 1024; // 1 MiB

  // Agent bounds
  static const int maxModelCallsPerOperation = 2;
  static const int sceneMaxTokens = 512;
  static const int readingMaxTokens = 768;
  static const int conversationMaxTokens = 256;
  static const int maxOcrTextCharacters = 12000;
  static const int maxQuestionCharacters = 300;
}
