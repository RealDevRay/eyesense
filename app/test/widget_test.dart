import 'package:eyesense/agents/output_policy.dart';
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:eyesense/models/scene_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SceneResult Contract and Parsing', () {
    test('parses valid hosted vision contract JSON', () {
      final json = {
        'summary': 'A chair is visible near the centre. A doorway is on the right.',
        'answer': 'The doorway is on the right.',
        'possibleConcern': true,
        'concernDescription': 'A chair is near the centre.',
        'direction': 'centre',
        'objects': ['chair', 'doorway'],
        'imageQuality': 'usable',
        'uncertainty': null,
      };

      final result = SceneResult.fromJson(json);

      expect(result.summary, 'A chair is visible near the centre. A doorway is on the right.');
      expect(result.answer, 'The doorway is on the right.');
      expect(result.possibleConcern, true);
      expect(result.direction, SceneDirection.centre);
      expect(result.objects, ['chair', 'doorway']);
      expect(result.imageQuality, ImageQuality.usable);
      expect(result.uncertainty, isNull);
    });

    test('truncates oversized strings to bounded limits', () {
      final longText = 'A' * 500;
      final json = {
        'summary': longText,
        'answer': longText,
        'possibleConcern': false,
        'direction': 'unknown',
        'objects': List.generate(20, (i) => 'item$i'),
        'imageQuality': 'usable',
      };

      final result = SceneResult.fromJson(json);

      expect(result.summary.length, 350);
      expect(result.answer?.length, 350);
      expect(result.objects.length, 8);
    });
  });

  group('OutputPolicy Verification', () {
    test('throws AppException when operation generation is mismatched', () {
      final result = SceneResult(
        summary: 'Scene test',
        possibleConcern: false,
        direction: SceneDirection.centre,
        objects: [],
        imageQuality: ImageQuality.usable,
      );

      expect(
        () => OutputPolicy.validateSceneResult(
          result: result,
          captureTimestamp: DateTime.now(),
          taskGeneration: 1,
          currentGeneration: 2,
        ),
        throwsA(isA<AppException>().having((e) => e.code, 'code', ErrorCode.operationCancelled)),
      );
    });

    test('throws AppException when result is older than 15s freshness limit', () {
      final result = SceneResult(
        summary: 'Scene test',
        possibleConcern: false,
        direction: SceneDirection.centre,
        objects: [],
        imageQuality: ImageQuality.usable,
      );

      final staleTimestamp = DateTime.now().subtract(const Duration(seconds: 16));

      expect(
        () => OutputPolicy.validateSceneResult(
          result: result,
          captureTimestamp: staleTimestamp,
          taskGeneration: 1,
          currentGeneration: 1,
        ),
        throwsA(isA<AppException>().having((e) => e.code, 'code', ErrorCode.staleResultDiscarded)),
      );
    });

    test('passes when fresh and generations match', () {
      final result = SceneResult(
        summary: 'Valid fresh scene',
        possibleConcern: false,
        direction: SceneDirection.centre,
        objects: [],
        imageQuality: ImageQuality.usable,
      );

      expect(
        () => OutputPolicy.validateSceneResult(
          result: result,
          captureTimestamp: DateTime.now(),
          taskGeneration: 3,
          currentGeneration: 3,
        ),
        returnsNormally,
      );
    });
  });
}
