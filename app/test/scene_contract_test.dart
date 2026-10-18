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

    test('rejects missing or empty summary with validation exception', () {
      final json = {
        'summary': '   ',
        'direction': 'centre',
        'objects': <String>[],
        'imageQuality': 'usable',
        'possibleConcern': false,
      };

      expect(
        () => SceneResult.fromJson(json),
        throwsA(isA<AppException>().having((e) => e.code, 'code', ErrorCode.validationFailed)),
      );
    });

    test('rejects missing or invalid imageQuality with validation exception', () {
      final json = {
        'summary': 'A valid scene',
        'direction': 'centre',
        'objects': <String>[],
        'imageQuality': 'perfect', // invalid enum
        'possibleConcern': false,
      };

      expect(
        () => SceneResult.fromJson(json),
        throwsA(isA<AppException>().having((e) => e.code, 'code', ErrorCode.validationFailed)),
      );
    });

    test('rejects possibleConcern=true when concernDescription is missing or empty', () {
      final json = {
        'summary': 'A valid scene',
        'direction': 'centre',
        'objects': <String>[],
        'imageQuality': 'usable',
        'possibleConcern': true,
        'concernDescription': '', // empty description for concern
      };

      expect(
        () => SceneResult.fromJson(json),
        throwsA(isA<AppException>().having((e) => e.code, 'code', ErrorCode.validationFailed)),
      );
    });
  });

  group('OutputPolicy Verification and Limitation Enforcement', () {
    test('throws AppException when operation generation is mismatched', () {
      final result = const SceneResult(
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

    test('throws AppException when result is older than the 25s freshness limit', () {
      final result = const SceneResult(
        summary: 'Scene test',
        possibleConcern: false,
        direction: SceneDirection.centre,
        objects: [],
        imageQuality: ImageQuality.usable,
      );

      final staleTimestamp = DateTime.now().subtract(const Duration(seconds: 26));

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
      final result = const SceneResult(
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

    test('replaces English road-crossing and navigation guidance with conservative limitation', () {
      final result = const SceneResult(
        summary: 'The street is safe to cross and path is clear.',
        answer: 'You can cross now, no obstacles ahead.',
        possibleConcern: false,
        direction: SceneDirection.centre,
        objects: ['street'],
        imageQuality: ImageQuality.usable,
      );

      final validated = OutputPolicy.validateSceneResult(
        result: result,
        captureTimestamp: DateTime.now(),
        taskGeneration: 1,
        currentGeneration: 1,
        language: 'en',
      );

      expect(validated.summary, contains('EyeSense cannot confirm navigation safety or crossing decisions'));
      expect(validated.answer, contains('EyeSense cannot determine path safety or crossing decisions'));
      expect(validated.possibleConcern, false);
      expect(validated.concernDescription, isNull);
    });

    test('a violation in the answer keeps a legitimate concern description', () {
      final result = const SceneResult(
        summary: 'A doorway is ahead.',
        answer: 'It is safe to cross.',
        possibleConcern: true,
        concernDescription: 'The doorway is partly blocked by a box.',
        direction: SceneDirection.centre,
        objects: ['door', 'safe to cross'],
        imageQuality: ImageQuality.usable,
        uncertainty: 'The path is clear.',
      );

      final validated = OutputPolicy.validateSceneResult(
        result: result,
        captureTimestamp: DateTime.now(),
        taskGeneration: 1,
        currentGeneration: 1,
      );

      expect(validated.summary, 'A doorway is ahead.');
      expect(validated.answer, contains('cannot determine path safety'));
      expect(validated.concernDescription, 'The doorway is partly blocked by a box.');
      expect(validated.objects, ['door', 'unspecified']);
      expect(validated.uncertainty, contains('Safety limitation'));
    });

    test('replaces Kiswahili road-crossing guidance with conservative limitation', () {
      final result = const SceneResult(
        summary: 'Ni salama kuvuka barabara.',
        answer: 'Vuka sasa.',
        possibleConcern: false,
        direction: SceneDirection.centre,
        objects: ['barabara'],
        imageQuality: ImageQuality.usable,
      );

      final validated = OutputPolicy.validateSceneResult(
        result: result,
        captureTimestamp: DateTime.now(),
        taskGeneration: 1,
        currentGeneration: 1,
        language: 'sw',
      );

      expect(validated.summary, contains('haiwezi kuthibitisha njia salama'));
      expect(validated.answer, contains('haiwezi kuamua usalama wa njia au kuvuka'));
      expect(validated.possibleConcern, false);
      expect(validated.concernDescription, isNull);
    });
  });
}
