import 'package:dio/dio.dart';
import 'package:eyesense/agents/agent_task.dart';
import 'package:eyesense/agents/output_policy.dart';
import 'package:eyesense/core/errors/app_exceptions.dart';
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
    CancelToken? cancelToken,
    DateTime Function()? nowProvider,
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
          cancelToken: cancelToken,
        );
      } else {
        result = await visionApi.describeScene(
          requestId: task.requestId,
          base64Jpeg: base64Jpeg,
          language: language,
          cancelToken: cancelToken,
        );
      }

      // Output policy verification (freshness, generation match, safety bounds)
      final validatedResult = OutputPolicy.validateSceneResult(
        result: result,
        captureTimestamp: task.captureTimestamp,
        taskGeneration: task.generation,
        currentGeneration: currentGeneration,
        nowProvider: nowProvider,
        language: language,
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

      return validatedResult;
    } catch (e) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      final errorCode = e is AppException ? e.code.name : 'unknown_error';
      await logService.logEvent(
        requestId: task.requestId,
        agent: 'scene',
        providerMode: task.providerMode.name,
        event: 'agent_failed',
        durationMs: duration,
        outcome: 'failed',
        errorCode: errorCode,
      );
      rethrow;
    }
  }
}
