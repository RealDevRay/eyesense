import 'package:eyesense/agents/agent_task.dart';
import 'package:eyesense/core/config/app_config.dart';
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:eyesense/services/diagnostic_log_service.dart';
import 'package:eyesense/services/preferences_service.dart';

class ReadingResult {
  final String summary;
  final List<String> keyPoints;
  final String clarityAssessment;

  ReadingResult({
    required this.summary,
    required this.keyPoints,
    required this.clarityAssessment,
  });
}

class ReadingAgent {
  final PreferencesService prefs;
  final DiagnosticLogService logService;

  ReadingAgent({
    required this.prefs,
    required this.logService,
  });

  Future<ReadingResult> summarise({
    required AgentTask task,
    required String ocrText,
    required String language,
  }) async {
    // Explicit consent check for sending text to cloud
    if (!prefs.cloudConsentGranted) {
      throw const AppException(
        code: ErrorCode.cloudDisabled,
        userMessage: 'Cloud processing consent is required to summarise text.',
      );
    }

    if (ocrText.length > AppConfig.maxOcrTextCharacters) {
      throw const AppException(
        code: ErrorCode.validationFailed,
        userMessage: 'Document is too long to summarise. Verbatim reading is available.',
      );
    }

    task.recordCall();
    await logService.logEvent(
      requestId: task.requestId,
      agent: 'reading',
      providerMode: task.providerMode.name,
      event: 'agent_started',
    );

    // Provide a bounded summary structure
    final summary = 'Summary: ${ocrText.split('\n').take(3).join(' ')}';
    return ReadingResult(
      summary: summary,
      keyPoints: ocrText.split('\n').where((l) => l.trim().isNotEmpty).take(3).toList(),
      clarityAssessment: 'clear',
    );
  }
}
