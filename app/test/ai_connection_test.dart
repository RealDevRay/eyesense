import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eyesense/core/config/app_config.dart';
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:eyesense/features/settings/ai_connection_screen.dart';
import 'package:eyesense/models/app_operation.dart';
import 'package:eyesense/models/direct_ai_provider.dart';
import 'package:eyesense/models/scene_result.dart';
import 'package:eyesense/services/credential_service.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:eyesense/services/providers/openai_compatible_provider.dart';
import 'package:eyesense/services/vision_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:shared_preferences/shared_preferences.dart';

const _sampleResult = SceneResult(
  summary: 'PRIVATE RESPONSE MUST NOT BE ECHOED',
  possibleConcern: false,
  direction: SceneDirection.unknown,
  objects: [],
  imageQuality: ImageQuality.usable,
);

final _keyField = find.byKey(const ValueKey('provider-api-key'));
final _modelField = find.byKey(const ValueKey('provider-model'));
final _saveButton = find.byKey(const ValueKey('save-connection'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PreferencesService preferences;
  late _Credentials credentials;
  late _VisionHarness harness;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'provider_mode': 'byok',
      'cloud_consent_granted': true,
      'terms_version_accepted': AppConfig.termsVersion,
    });
    preferences = await PreferencesService.create();
    credentials = _Credentials();
    harness = _VisionHarness();
  });

  Future<void> open(
    WidgetTester tester, {
    DirectProviderFactory? factory,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AiConnectionScreen(
                    preferencesService: preferences,
                    credentialService: credentials,
                    directProviderFactory: factory ?? harness.create,
                  ),
                ),
              ),
              child: const Text('Open connection settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open connection settings'));
    await tester.pumpAndSettle();
  }

  testWidgets('Groq is the default and each preset has its own model and key', (
    tester,
  ) async {
    await open(tester);
    expect(_fieldText(tester, _modelField), DirectAiProvider.groq.defaultModel);
    expect(_fieldText(tester, _keyField), 'groq-saved');
    await _select(tester, DirectAiProvider.openai);
    expect(
      _fieldText(tester, _modelField),
      DirectAiProvider.openai.defaultModel,
    );
    expect(_fieldText(tester, _keyField), 'openai-saved');
    await _select(tester, DirectAiProvider.gemini);
    expect(
      _fieldText(tester, _modelField),
      DirectAiProvider.gemini.defaultModel,
    );
    expect(_fieldText(tester, _keyField), isEmpty);
    await _select(tester, DirectAiProvider.mistral);
    expect(_fieldText(tester, _modelField), 'mistral-small-latest');
    expect(_fieldText(tester, _keyField), isEmpty);
    expect(find.textContaining('A free / Experiment API key'), findsOneWidget);
    expect(preferences.directAiProvider, DirectAiProvider.groq);
    expect(credentials.writes, isEmpty);
  });

  testWidgets(
    'Mistral requires its own key and consent before one sample request',
    (tester) async {
      await open(tester);
      await _select(tester, DirectAiProvider.mistral);
      await _tap(tester, find.text('Test vision with sample image'));
      expect(harness.factoryCalls, 0);
      expect(
        find.textContaining('Enter an API key for Mistral'),
        findsOneWidget,
      );
      await _enter(tester, _keyField, 'mistral-test');
      await preferences.setCloudConsentGranted(false);
      await _tap(tester, find.text('Test vision with sample image'));
      expect(harness.factoryCalls, 0);
      await preferences.setCloudConsentGranted(true);
      await _tap(tester, find.text('Test vision with sample image'));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('zero-data retention is not available'),
        ),
        findsOneWidget,
      );
      await _tap(tester, find.text('Send sample image'));
      expect(harness.provider, DirectAiProvider.mistral);
      expect(harness.model, 'mistral-small-latest');
      expect(harness.key, 'mistral-test');
      expect(harness.vision.calls, 1);
      expect(credentials.writes, isEmpty);
      expect(preferences.directAiProvider, DirectAiProvider.groq);
      await _tap(tester, _saveButton);
      expect(credentials.writes, [DirectAiProvider.mistral]);
      expect(credentials.keys[DirectAiProvider.groq], 'groq-saved');
      expect(preferences.directAiProvider, DirectAiProvider.mistral);
    },
  );

  testWidgets('provider changes preserve unsaved model drafts without saving', (
    tester,
  ) async {
    await open(tester);
    await _enter(tester, _modelField, 'groq/custom-vision');
    await _select(tester, DirectAiProvider.openai);
    await _enter(tester, _modelField, 'openai-custom-vision');
    await _select(tester, DirectAiProvider.groq);
    expect(_fieldText(tester, _modelField), 'groq/custom-vision');
    await _select(tester, DirectAiProvider.openai);
    expect(_fieldText(tester, _modelField), 'openai-custom-vision');
    expect(
      preferences.visionModelFor(DirectAiProvider.openai),
      DirectAiProvider.openai.defaultModel,
    );
    expect(credentials.writes, isEmpty);
  });

  testWidgets(
    'late key loads cannot cross providers or overwrite a typed key',
    (tester) async {
      final groqLoad = Completer<String?>();
      final openaiLoad = Completer<String?>();
      credentials.loads[DirectAiProvider.groq] = [groqLoad];
      credentials.loads[DirectAiProvider.openai] = [openaiLoad];
      await open(tester);
      await _enter(tester, _keyField, 'groq-unsaved');
      await _select(tester, DirectAiProvider.openai);
      expect(_fieldText(tester, _keyField), isEmpty);
      await _enter(tester, _keyField, 'openai-unsaved');
      groqLoad.complete('groq-late');
      await tester.pump();
      expect(_fieldText(tester, _keyField), 'openai-unsaved');
      openaiLoad.complete('openai-late');
      await tester.pump();
      expect(_fieldText(tester, _keyField), 'openai-unsaved');
      await _tap(tester, _saveButton);
      expect(credentials.keys[DirectAiProvider.openai], 'openai-unsaved');
      expect(credentials.keys[DirectAiProvider.groq], 'groq-saved');
      expect(preferences.directAiProvider, DirectAiProvider.openai);
    },
  );

  testWidgets('load generation rejects an earlier visit to the same provider', (
    tester,
  ) async {
    final first = Completer<String?>();
    final second = Completer<String?>();
    credentials.loads[DirectAiProvider.groq] = [first, second];
    await open(tester);
    await _select(tester, DirectAiProvider.openai);
    await _select(tester, DirectAiProvider.groq);
    first.complete('obsolete-key');
    await tester.pump();
    expect(_fieldText(tester, _keyField), isEmpty);
    second.complete('current-key');
    await tester.pump();
    expect(_fieldText(tester, _keyField), 'current-key');
  });

  testWidgets('blank key never saves or tests using another provider key', (
    tester,
  ) async {
    await open(tester);
    await _select(tester, DirectAiProvider.gemini);
    await _tap(tester, _saveButton);
    expect(
      find.textContaining('Enter an API key for Google Gemini'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Check key and model'));
    await _tap(tester, find.text('Test vision with sample image'));
    expect(credentials.checks, isEmpty);
    expect(harness.factoryCalls, 0);
    expect(credentials.writes, isEmpty);
    expect(preferences.directAiProvider, DirectAiProvider.groq);
    expect(find.byType(AiConnectionScreen), findsOneWidget);
  });

  testWidgets('clearing a loaded field does not silently reuse its saved key', (
    tester,
  ) async {
    await open(tester);
    await _enter(tester, _keyField, '');
    await _tap(tester, _saveButton);
    expect(credentials.keys[DirectAiProvider.groq], 'groq-saved');
    expect(credentials.writes, isEmpty);
    expect(find.textContaining('Enter an API key for Groq'), findsOneWidget);
  });

  testWidgets('save persists only the selected provider key and model', (
    tester,
  ) async {
    await open(tester);
    await _enter(tester, _modelField, 'unsaved-groq-draft');
    await _select(tester, DirectAiProvider.openai);
    await _enter(tester, _keyField, '  openai-replacement  ');
    await _enter(tester, _modelField, 'my-vision-model');
    await _tap(tester, _saveButton);
    expect(credentials.keys[DirectAiProvider.openai], 'openai-replacement');
    expect(credentials.keys[DirectAiProvider.groq], 'groq-saved');
    expect(credentials.writes, [DirectAiProvider.openai]);
    expect(preferences.providerMode, ProviderMode.byok);
    expect(preferences.directAiProvider, DirectAiProvider.openai);
    expect(
      preferences.visionModelFor(DirectAiProvider.openai),
      'my-vision-model',
    );
    expect(
      preferences.visionModelFor(DirectAiProvider.groq),
      DirectAiProvider.groq.defaultModel,
    );
    expect(find.byType(AiConnectionScreen), findsNothing);
    await _tap(tester, find.text('Open connection settings'));
    expect(_fieldText(tester, _keyField), 'openai-replacement');
    expect(_fieldText(tester, _modelField), 'my-vision-model');
  });

  testWidgets('failed secure write does not activate a different provider', (
    tester,
  ) async {
    credentials.failWrites = true;
    await open(tester);
    await _select(tester, DirectAiProvider.openai);
    await _tap(tester, _saveButton);
    expect(
      find.textContaining('Could not save connection settings'),
      findsOneWidget,
    );
    expect(preferences.directAiProvider, DirectAiProvider.groq);
    expect(credentials.keys[DirectAiProvider.openai], 'openai-saved');
    expect(find.byType(AiConnectionScreen), findsOneWidget);
    expect(_visibleText(tester), isNot(contains('SECRET STORAGE ERROR')));
  });

  testWidgets(
    'remove affects only selected key and invalidates a pending load',
    (tester) async {
      final pending = Completer<String?>();
      credentials.loads[DirectAiProvider.groq] = [pending];
      await open(tester);
      await _tap(tester, find.text('Remove saved key'));
      pending.complete('groq-late');
      await tester.pump();
      expect(_fieldText(tester, _keyField), isEmpty);
      expect(credentials.keys.containsKey(DirectAiProvider.groq), isFalse);
      expect(credentials.keys[DirectAiProvider.openai], 'openai-saved');
      expect(credentials.cleared, [DirectAiProvider.groq]);
      expect(
        find.textContaining('Other provider keys were not changed'),
        findsOneWidget,
      );
    },
  );

  testWidgets('empty, whitespace and overlong models block all actions', (
    tester,
  ) async {
    await open(tester);
    for (final model in [
      '',
      '   ',
      'model with spaces',
      'model\tname',
      ' model',
      'm' * 151,
    ]) {
      await _enter(tester, _modelField, model);
      await _tap(tester, find.text('Check key and model'));
      await _tap(tester, find.text('Test vision with sample image'));
      await _tap(tester, _saveButton);
      expect(credentials.checks, isEmpty, reason: model);
      expect(credentials.writes, isEmpty, reason: model);
      expect(harness.factoryCalls, 0, reason: model);
      expect(find.byType(AlertDialog), findsNothing);
    }
    await _enter(tester, _modelField, 'm' * 150);
    await _tap(tester, find.text('Check key and model'));
    expect(credentials.checks.single.model.length, 150);
  });

  testWidgets(
    'key check is metadata only, uses current fields, and announces limits',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await open(tester);
        await _select(tester, DirectAiProvider.openai);
        await _enter(tester, _keyField, 'typed-not-saved');
        await _enter(tester, _modelField, 'custom-model');
        await _tap(tester, find.text('Check key and model'));
        expect(credentials.checks, [
          (
            provider: DirectAiProvider.openai,
            key: 'typed-not-saved',
            model: 'custom-model',
          ),
        ]);
        expect(harness.factoryCalls, 0);
        expect(credentials.writes, isEmpty);
        expect(
          find.textContaining('Vision and JSON support have not been tested'),
          findsOneWidget,
        );
        expect(
          tester
              .widgetList<Semantics>(find.byType(Semantics))
              .any((s) => s.properties.liveRegion == true),
          isTrue,
        );
        expect(_visibleText(tester), isNot(contains('typed-not-saved')));
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('late metadata check is not attributed to another provider', (
    tester,
  ) async {
    credentials.checkCompletion = Completer<bool>();
    await open(tester);
    await _tap(tester, find.text('Check key and model'));
    await _select(tester, DirectAiProvider.openai);
    credentials.checkCompletion!.complete(true);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('accepted the key and listed the model'),
      findsNothing,
    );
    expect(credentials.checks.single.provider, DirectAiProvider.groq);
  });

  testWidgets(
    'cloud consent is mandatory and never granted by the smoke test',
    (tester) async {
      await preferences.setCloudConsentGranted(false);
      await open(tester);
      await _tap(tester, find.text('Test vision with sample image'));
      expect(find.textContaining('Cloud consent is required.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(harness.factoryCalls, 0);
      expect(preferences.cloudConsentGranted, isFalse);
      await _tap(tester, find.text('Check key and model'));
      expect(credentials.checks, hasLength(1));
      expect(harness.factoryCalls, 0);
    },
  );

  testWidgets(
    'sample dialog names destination, own-account billing and no camera',
    (tester) async {
      await open(tester);
      await _select(tester, DirectAiProvider.openai);
      await _tap(tester, find.text('Test vision with sample image'));
      expect(find.textContaining('sent to OpenAI'), findsOneWidget);
      expect(
        find.textContaining('billed by your own provider account'),
        findsOneWidget,
      );
      expect(
        find.textContaining('No camera or photo is accessed or uploaded'),
        findsOneWidget,
      );
      expect(harness.factoryCalls, 0);
      await _tap(tester, find.text('Cancel'));
      expect(harness.factoryCalls, 0);
      expect(credentials.writes, isEmpty);
      expect(
        find.textContaining('No image was sent and nothing was saved'),
        findsOneWidget,
      );
    },
  );

  testWidgets('consent revoked during confirmation prevents the request', (
    tester,
  ) async {
    await open(tester);
    await _tap(tester, find.text('Test vision with sample image'));
    await preferences.setCloudConsentGranted(false);
    await _tap(tester, find.text('Send sample image'));
    expect(harness.factoryCalls, 0);
    expect(
      find.text('Cloud consent is required. No image was sent.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'sample uses current unsaved fields, a red RGB JPEG and a deadline',
    (tester) async {
      await open(tester);
      await _select(tester, DirectAiProvider.openai);
      await _enter(tester, _keyField, 'unsaved-override');
      await _enter(tester, _modelField, 'unsaved-vision-model');
      await _startVision(tester);
      expect(harness.factoryCalls, 1);
      expect(harness.provider, DirectAiProvider.openai);
      expect(harness.key, 'unsaved-override');
      expect(harness.model, 'unsaved-vision-model');
      expect(harness.vision.calls, 1);
      expect(harness.vision.timeout, AppConfig.clientTimeout);
      expect(harness.vision.cancelToken, isNotNull);
      final decoded = image.decodeJpg(
        base64Decode(harness.vision.base64Jpeg!),
      )!;
      expect(decoded.width, 64);
      expect(decoded.height, 64);
      expect(decoded.numChannels, 3);
      final pixel = decoded.getPixel(32, 32);
      expect(pixel.r, greaterThan(245));
      expect(pixel.g, lessThan(10));
      expect(pixel.b, lessThan(10));
      expect(credentials.writes, isEmpty);
      expect(credentials.keys[DirectAiProvider.openai], 'openai-saved');
      expect(preferences.directAiProvider, DirectAiProvider.groq);
      expect(
        find.textContaining('returned a supported vision and JSON response'),
        findsOneWidget,
      );
      expect(_visibleText(tester), isNot(contains(_sampleResult.summary)));
      expect(_visibleText(tester), isNot(contains('unsaved-override')));
    },
  );

  testWidgets(
    'provider errors are fixed safe text and never echoed or retried',
    (tester) async {
      harness.vision.error = const AppException(
        code: ErrorCode.upstreamAuthFailed,
        userMessage: 'SECRET KEY AND PROVIDER RESPONSE',
        technicalDetail: 'SECRET TECHNICAL DETAIL',
      );
      await open(tester);
      await _startVision(tester);
      expect(
        find.textContaining('Groq rejected the key or account access'),
        findsOneWidget,
      );
      expect(_visibleText(tester), isNot(contains('SECRET')));
      expect(harness.vision.calls, 1);
      harness.vision.error = StateError('SECRET RAW ERROR');
      await _startVision(tester);
      expect(
        find.textContaining('The Groq vision test failed.'),
        findsOneWidget,
      );
      expect(_visibleText(tester), isNot(contains('SECRET')));
      expect(harness.vision.calls, 2);
      expect(credentials.writes, isEmpty);
    },
  );

  testWidgets('provider switch cancels live test and discards late results', (
    tester,
  ) async {
    harness.vision.completion = Completer<SceneResult>();
    await open(tester);
    await _startVision(tester);
    final token = harness.vision.cancelToken!;
    await _select(tester, DirectAiProvider.openai);
    expect(token.isCancelled, isTrue);
    harness.vision.completion!.complete(_sampleResult);
    await tester.pumpAndSettle();
    expect(find.textContaining('returned a supported vision'), findsNothing);
    expect(_fieldText(tester, _keyField), 'openai-saved');
    expect(harness.vision.calls, 1);
  });

  testWidgets(
    'route disposal cancels live test without setState after disposal',
    (tester) async {
      harness.vision.completion = Completer<SceneResult>();
      await open(tester);
      await _startVision(tester);
      final token = harness.vision.cancelToken!;
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(token.isCancelled, isTrue);
      harness.vision.completion!.complete(_sampleResult);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(harness.vision.calls, 1);
      expect(credentials.writes, isEmpty);
    },
  );

  testWidgets('live test times out, cancels transport and sends no retry', (
    tester,
  ) async {
    harness.vision.completion = Completer<SceneResult>();
    await open(tester);
    await _startVision(tester);
    final liveButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Testing vision…'),
    );
    expect(liveButton.onPressed, isNull);
    await tester.pump(
      AppConfig.clientTimeout + const Duration(milliseconds: 1),
    );
    await tester.pumpAndSettle();
    expect(harness.vision.cancelToken!.isCancelled, isTrue);
    expect(harness.vision.calls, 1);
    expect(
      find.textContaining('timed out. Nothing was saved; no retry was sent'),
      findsOneWidget,
    );
    harness.vision.completion!.complete(_sampleResult);
    await tester.pump();
    expect(find.textContaining('returned a supported vision'), findsNothing);
  });

  testWidgets('hosted health check and secure token save remain separate', (
    tester,
  ) async {
    await preferences.setProviderMode(ProviderMode.hosted);
    await open(tester);
    await _tap(tester, find.text('Advanced'));
    final url = find.widgetWithText(TextField, 'Worker Base URL');
    final token = find.widgetWithText(TextField, 'Demo Access Token');
    await _enter(tester, url, 'https://worker.example');
    await _enter(tester, token, 'hosted-token-replacement');
    await _tap(tester, find.text('Test Worker Connection'));
    expect(credentials.workerChecks, ['https://worker.example']);
    expect(
      find.text('Success: Cloudflare Worker responded healthy.'),
      findsOneWidget,
    );
    expect(credentials.demoToken, 'hosted-saved');
    expect(credentials.checks, isEmpty);
    expect(harness.factoryCalls, 0);
    await _tap(tester, _saveButton);
    expect(preferences.providerMode, ProviderMode.hosted);
    expect(preferences.apiBaseUrl, 'https://worker.example');
    expect(credentials.demoToken, 'hosted-token-replacement');
    expect(credentials.writes, isEmpty);
  });

  testWidgets('invalid hosted URL blocks health checks and saves', (
    tester,
  ) async {
    await preferences.setProviderMode(ProviderMode.hosted);
    await open(tester);
    await _tap(tester, find.text('Advanced'));
    await _enter(
      tester,
      find.widgetWithText(TextField, 'Worker Base URL'),
      'not-a-url',
    );
    await _tap(tester, find.text('Test Worker Connection'));
    await _tap(tester, _saveButton);
    expect(credentials.workerChecks, isEmpty);
    expect(find.textContaining('Please enter a valid URL'), findsOneWidget);
    expect(find.byType(AiConnectionScreen), findsOneWidget);
  });

  testWidgets('credentials disable suggestions, autocorrect and autofill', (
    tester,
  ) async {
    await open(tester);
    void expectPrivate(TextField field) {
      expect(field.obscureText, isTrue);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.enableIMEPersonalizedLearning, isFalse);
      expect(field.autofillHints, isEmpty);
    }

    expectPrivate(tester.widget<TextField>(_keyField));
    await _tap(tester, find.text('EyeSense service (Hosted prototype)'));
    await _tap(tester, find.text('Advanced'));
    expectPrivate(
      tester.widget<TextField>(
        find.widgetWithText(TextField, 'Demo Access Token'),
      ),
    );
  });

  testWidgets('provider controls and save fit 320px at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester, scale: 2);
    expect(tester.takeException(), isNull);
    await _select(tester, DirectAiProvider.gemini);
    await _enter(tester, _keyField, 'gemini-test');
    await _tap(tester, find.text('Test vision with sample image'));
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('Cancel'));
    await tester.ensureVisible(_saveButton);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(_saveButton).height, greaterThan(70));
  });

  testWidgets(
    'real provider adapter uses one mocked POST and no credential fallback',
    (tester) async {
      final adapter = _Transport();
      await open(
        tester,
        factory:
            ({
              required credentialService,
              required provider,
              required model,
              required apiKeyOverride,
            }) {
              return OpenAiCompatibleVisionProvider(
                credentialService: credentialService,
                provider: provider,
                model: model,
                apiKeyOverride: apiKeyOverride,
                dio: Dio()..httpClientAdapter = adapter,
              );
            },
      );
      await _select(tester, DirectAiProvider.openai);
      await _enter(tester, _keyField, 'override-not-persisted');
      await _enter(tester, _modelField, 'custom-vision');
      await _startVision(tester);
      expect(adapter.requests, hasLength(1));
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(
        request.uri.toString(),
        DirectAiProvider.openai.chatCompletionsUrl,
      );
      expect(request.headers['Authorization'], 'Bearer override-not-persisted');
      expect(request.data['model'], 'custom-vision');
      expect(request.data['response_format'], {'type': 'json_object'});
      expect(
        find.textContaining('returned a supported vision and JSON response'),
        findsOneWidget,
      );
      expect(credentials.writes, isEmpty);
    },
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, Finder finder, String value) async {
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  await tester.pump();
}

Future<void> _select(WidgetTester tester, DirectAiProvider provider) async {
  await _tap(tester, find.byType(DropdownButtonFormField<DirectAiProvider>));
  await _tap(tester, find.text(provider.displayName).last);
}

Future<void> _startVision(WidgetTester tester) async {
  await _tap(tester, find.text('Test vision with sample image'));
  await _tap(tester, find.text('Send sample image'));
}

String _fieldText(WidgetTester tester, Finder finder) =>
    tester.widget<TextField>(finder).controller!.text;

String _visibleText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? '')
    .join('\n');

class _Credentials extends CredentialService {
  final keys = <DirectAiProvider, String>{
    DirectAiProvider.groq: 'groq-saved',
    DirectAiProvider.openai: 'openai-saved',
  };
  final loads = <DirectAiProvider, List<Completer<String?>>>{};
  final writes = <DirectAiProvider>[];
  final cleared = <DirectAiProvider>[];
  final checks = <({DirectAiProvider provider, String key, String model})>[];
  final workerChecks = <String>[];
  String demoToken = 'hosted-saved';
  bool failWrites = false;
  Completer<bool>? checkCompletion;

  @override
  Future<String?> getProviderApiKey(DirectAiProvider provider) async {
    final pending = loads[provider];
    if (pending != null && pending.isNotEmpty) {
      return pending.removeAt(0).future;
    }
    return keys[provider];
  }

  @override
  Future<void> setProviderApiKey(DirectAiProvider provider, String key) async {
    if (failWrites) throw StateError('SECRET STORAGE ERROR');
    writes.add(provider);
    keys[provider] = key;
  }

  @override
  Future<void> clearProviderApiKey(DirectAiProvider provider) async {
    cleared.add(provider);
    keys.remove(provider);
  }

  @override
  Future<bool> testProviderModel(
    DirectAiProvider provider,
    String apiKey,
    String model,
  ) async {
    checks.add((provider: provider, key: apiKey, model: model));
    return checkCompletion?.future ?? Future.value(true);
  }

  @override
  Future<String?> getDemoAccessToken() async => demoToken;

  @override
  Future<void> setDemoAccessToken(String token) async => demoToken = token;

  @override
  Future<bool> testWorkerHealth(String baseUrl) async {
    workerChecks.add(baseUrl);
    return true;
  }
}

class _VisionHarness {
  final vision = _Vision();
  int factoryCalls = 0;
  DirectAiProvider? provider;
  String? model;
  String? key;

  VisionApiService create({
    required CredentialService credentialService,
    required DirectAiProvider provider,
    required String model,
    required String apiKeyOverride,
  }) {
    factoryCalls++;
    this.provider = provider;
    this.model = model;
    key = apiKeyOverride;
    return vision;
  }
}

class _Vision implements VisionApiService {
  int calls = 0;
  CancelToken? cancelToken;
  Duration? timeout;
  String? base64Jpeg;
  Object? error;
  Completer<SceneResult>? completion;

  @override
  Future<SceneResult> describeScene({
    required String requestId,
    required String base64Jpeg,
    required String language,
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    calls++;
    this.base64Jpeg = base64Jpeg;
    this.cancelToken = cancelToken;
    this.timeout = timeout;
    if (error != null) throw error!;
    return completion?.future ?? Future.value(_sampleResult);
  }

  @override
  Future<SceneResult> askQuestion({
    required String requestId,
    required String base64Jpeg,
    required String question,
    required String language,
    CancelToken? cancelToken,
    Duration? timeout,
  }) => throw StateError('Settings must not call askQuestion');
}

class _Transport implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'choices': [
          {
            'message': {
              'content': jsonEncode({
                'summary': 'Red sample.',
                'possibleConcern': false,
                'direction': 'unknown',
                'objects': [],
                'imageQuality': 'usable',
              }),
            },
          },
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
