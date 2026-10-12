import 'package:eyesense/models/scene_result.dart';

abstract class VisionApiService {
  Future<SceneResult> describeScene({
    required String requestId,
    required String base64Jpeg,
    required String language,
  });

  Future<SceneResult> askQuestion({
    required String requestId,
    required String base64Jpeg,
    required String question,
    required String language,
  });
}
