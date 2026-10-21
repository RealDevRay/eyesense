import 'package:eyesense/core/config/app_config.dart';

/// Explicit destinations: a failed request never falls back to another company.
enum DirectAiProvider {
  groq,
  openai,
  gemini,
  // Append providers to preserve existing indices as well as saved names.
  mistral;

  String get displayName => switch (this) {
    groq => 'Groq',
    openai => 'OpenAI',
    gemini => 'Google Gemini',
    mistral => 'Mistral',
  };

  String get chatCompletionsUrl => switch (this) {
    groq => AppConfig.groqDirectApiUrl,
    openai => 'https://api.openai.com/v1/chat/completions',
    gemini => 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    mistral => 'https://api.mistral.ai/v1/chat/completions',
  };

  String get modelsUrl => switch (this) {
    groq => AppConfig.groqModelsApiUrl,
    openai => 'https://api.openai.com/v1/models',
    gemini => 'https://generativelanguage.googleapis.com/v1beta/openai/models',
    mistral => 'https://api.mistral.ai/v1/models',
  };

  String get defaultModel => switch (this) {
    groq => AppConfig.defaultVisionModel,
    openai => 'gpt-5-mini',
    gemini => 'gemini-3.8-flash',
    mistral => 'mistral-small-latest',
  };
}
