import 'package:eyesense/models/direct_ai_provider.dart';

import 'package:eyesense/services/providers/openai_compatible_provider.dart';

/// Backward-compatible Groq entry point for existing callers and test fakes.
class GroqDirectVisionProvider extends OpenAiCompatibleVisionProvider {
  GroqDirectVisionProvider({
    required super.credentialService,
    super.model,
    super.dio,
    super.apiKeyOverride,
  }) : super(provider: DirectAiProvider.groq);
}
