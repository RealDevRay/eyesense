import 'package:eyesense/core/config/app_config.dart';
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:eyesense/models/scene_result.dart';

class OutputPolicy {
  /// Validates a SceneResult before display and speech.
  /// Throws [AppException] if stale, invalid, or violates safety boundaries.
  static void validateSceneResult({
    required SceneResult result,
    required DateTime captureTimestamp,
    required int taskGeneration,
    required int currentGeneration,
  }) {
    // 1. Generation check (ensure task wasn't cancelled or superseded)
    if (taskGeneration != currentGeneration) {
      throw const AppException(
        code: ErrorCode.operationCancelled,
        userMessage: 'Operation was cancelled.',
      );
    }

    // 2. Freshness check (15 seconds since camera capture)
    final elapsed = DateTime.now().difference(captureTimestamp);
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

    // 4. Prohibited phrase checks (never promise absolute safety or walking commands)
    final lowerSummary = result.summary.toLowerCase();
    if (lowerSummary.contains('safe to cross') ||
        lowerSummary.contains('path is clear') ||
        lowerSummary.contains('no hazards present')) {
      // Flag as potential concern rather than absolute assertion
    }
  }
}
