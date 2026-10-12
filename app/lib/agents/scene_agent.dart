import 'package:eyesense/agents/agent_task.dart';
import 'package:eyesense/agents/output_policy.dart';
import 'package:eyesense/models/scene_result.dart';
import 'package:eyesense/services/diagnostic_log_service.dart';
import 'package:eyesense/services/vision_api_service.dart';

class SceneAgent {
  final VisionApiService visionApi;
  final DiagnosticLogService logService;

  SceneAgent({
    required this.visionApi,
    required this.logService,
  });

  Future<SceneResult> execute({
    required AgentTask task,
    required String base64Jpeg,
    String? question,
    required String language,
    required int currentGeneration,
  }) async {
    final startTime = DateTime.now();
    task.recordCall();

    await logService.logEvent(
      requestId: task.requestId,
      agent: 'scene',
      providerMode: task.providerMode.name,
      event: 'agent_started',
    );

    try {
      final SceneResult result;
      if (question != null && question.trim().isNotEmpty) {
        result = await visionApi.askQuestion(
          requestId: task.requestId,
          base64Jpeg: base64Jpeg,
          question: question.trim(),
          language: language,
        );
      } else {
        result = await visionApi.describeScene(
          requestId: task.requestId,
          base64Jpeg: base64Jpeg,
          language: language,
        );
      }

      // Output policy verification (freshness, generation match, safety bounds)
      OutputPolicy.validateSceneResult(
        result: result,
        captureTimestamp: task.captureTimestamp,
        taskGeneration: task.generation,
        currentGeneration: currentGeneration,
      );

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      await logService.logEvent(
        requestId: task.requestId,
        agent: 'scene',
        providerMode: task.providerMode.name,
        event: 'agent_finished',
        durationMs: duration,
        outcome: 'success',
      );

      return result;
    } catch (e) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      await logService.logEvent(
        requestId: task.requestId,
        agent: 'scene',
        providerMode: task.providerMode.name,
        event: 'agent_failed',
        durationMs: duration,
        outcome: 'failed',
        errorCode: e.toString(),
      );
      rethrow;
    }
  }
}
