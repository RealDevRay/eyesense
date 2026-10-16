import 'package:eyesense/core/config/app_config.dart';
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:eyesense/models/scene_result.dart';

class OutputPolicy {
  static const List<String> prohibitedPhrasesEn = [
    'safe to cross',
    'clear to cross',
    'cross the road',
    'cross the street',
    'cross now',
    'path is clear',
    'clear path',
    'no hazards present',
    'no hazards',
    'no obstacles',
    'safe to proceed',
    'walk forward',
    'turn left now',
    'turn right now',
    'imminent collision',
    'about to hit',
  ];

  static const List<String> prohibitedPhrasesSw = [
    'salama kuvuka',
    'vuka barabara',
    'vuka sasa',
    'njia iko wazi',
    'njia ni wazi',
    'hakuna vikwazo',
    'salama kuendelea',
    'tembea mbele',
    'karibu kugongana',
  ];

  static bool containsProhibitedSafetyGuidance(String text) {
    final lower = text.toLowerCase();
    for (final phrase in prohibitedPhrasesEn) {
      if (lower.contains(phrase)) return true;
    }
    for (final phrase in prohibitedPhrasesSw) {
      if (lower.contains(phrase)) return true;
    }
    // Proximity patterns like "X meters away" / "X metres away"
    if (RegExp(r'\b\d+(\.\d+)?\s*(meters?|metres?|feet)\s*away\b', caseSensitive: false).hasMatch(lower)) {
      return true;
    }
    return false;
  }

  /// Validates a SceneResult before display and speech.
  /// Throws [AppException] if stale, cancelled, or schema-invalid.
  /// If prohibited safety claims are present, replaces them with a conservative limitation response.
  static SceneResult validateSceneResult({
    required SceneResult result,
    required DateTime captureTimestamp,
    required int taskGeneration,
    required int currentGeneration,
    DateTime Function()? nowProvider,
    String language = 'en',
  }) {
    // 1. Generation check (ensure task wasn't cancelled or superseded)
    if (taskGeneration != currentGeneration) {
      throw const AppException(
        code: ErrorCode.operationCancelled,
        userMessage: 'Operation was cancelled.',
      );
    }

    // 2. Freshness check (15 seconds since camera capture)
    final now = nowProvider != null ? nowProvider() : DateTime.now();
    final elapsed = now.difference(captureTimestamp);
    if (elapsed > AppConfig.sceneFreshnessLimit) {
      throw const AppException(
        code: ErrorCode.staleResultDiscarded,
        userMessage: 'The scene observation has expired. Please capture a new image.',
      );
    }

    // 3. Schema & content validation
    if (result.summary.trim().isEmpty) {
      throw const AppException(
        code: ErrorCode.validationFailed,
        userMessage: 'Could not obtain a clear scene description.',
      );
    }

    // 4. Prohibited phrase checks & conservative limitation response
    final bool summaryViolates = containsProhibitedSafetyGuidance(result.summary);
    final bool answerViolates = result.answer != null && containsProhibitedSafetyGuidance(result.answer!);
    final bool concernViolates = result.concernDescription != null && containsProhibitedSafetyGuidance(result.concernDescription!);

    if (summaryViolates || answerViolates || concernViolates) {
      final isSwahili = language == 'sw';
      final limitationSummary = isSwahili
          ? 'Picha inaonekana. EyeSense haiwezi kuthibitisha njia salama au kutoa maelekezo ya kuvuka. Tafadhali tumia msaada wako wa kawaida wa uhamaji.'
          : 'Scene detected. EyeSense cannot confirm navigation safety or crossing decisions. Please rely on your mobility aids and physical orientation.';

      final limitationAnswer = result.answer != null
          ? (isSwahili
              ? 'EyeSense haiwezi kuamua usalama wa njia au kuvuka. Tafadhali tegemea vifaa vyako vya uhamaji.'
              : 'EyeSense cannot determine path safety or crossing decisions. Please rely on your mobility aids.')
          : null;

      final limitationConcern = isSwahili
          ? 'Tahadhari ya usalama: Maelekezo ya kutembea au kuvuka hayawezi kutolewa kutoka kwa picha.'
          : 'Safety limitation: Walking or crossing guidance cannot be provided from images.';

      return result.copyWith(
        summary: summaryViolates ? limitationSummary : result.summary,
        answer: answerViolates ? limitationAnswer : result.answer,
        possibleConcern: true,
        concernDescription: limitationConcern,
      );
    }

    return result;
  }
}
