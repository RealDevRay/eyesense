class AppConfig {
  static const String appName = 'EyeSense';
  static const String tagline = 'Your world, described.';

  // Default API Base URL (configurable via --dart-define=API_BASE_URL=...)
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://eyesense-api.klantrilogy.workers.dev',
  );

  /// Internal builds only. A public release must not pass this define.
  /// Empty means hosted mode fails closed until a token is saved in secure storage.
  static const String defaultDemoAccessToken = String.fromEnvironment(
    'HOSTED_ACCESS_TOKEN',
    defaultValue: '',
  );

  static const String termsVersion = '1.1-pilot';
  static const String appVersionLabel = '1.0.0+1';

  // Fixed Groq API Endpoint for BYOK direct mode
  static const String groqDirectApiUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String groqModelsApiUrl =
      'https://api.groq.com/openai/v1/models';

  // Supported Vision Model
  static const String defaultVisionModel = 'qwen/qwen3.8-27b';
  static const List<String> supportedModels = ['qwen/qwen3.8-27b'];

  // The request deadline is shorter than the freshness window so capture,
  // resize and one timed-out attempt can still deliver a usable result.
  static const Duration clientTimeout = Duration(seconds: 10);
  static const Duration sceneFreshnessLimit = Duration(seconds: 25);
  static const Duration conversationTurnExpiry = Duration(seconds: 60);

  // Image capture tuning
  static const int maxImageLongEdge = 1280;
  static const int jpegQuality = 80;
  static const int maxImageDecodedBytes = 1024 * 1024; // 1 MiB

  // Agent bounds
  // Pilot: a timeout may still have consumed provider quota. Retry only on a
  // new explicit user action, never automatically within the operation.
  static const int maxModelCallsPerOperation = 1;
  static const int sceneMaxTokens = 512;
  static const int readingMaxTokens = 768;
  static const int conversationMaxTokens = 256;
  static const int maxOcrTextCharacters = 12000;
  static const int maxQuestionCharacters = 300;
}
