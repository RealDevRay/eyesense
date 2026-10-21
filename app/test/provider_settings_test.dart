import 'package:dio/dio.dart';
import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/models/app_operation.dart';
import 'package:eyesense/models/direct_ai_provider.dart';
import 'package:eyesense/services/credential_service.dart';
import 'package:eyesense/services/diagnostic_log_service.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:eyesense/services/providers/openai_compatible_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coordinator_test.dart';
import 'provider_contract_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'provider_mode': 'byok',
      'earcons_enabled': false,
    });
    FlutterSecureStorage.setMockInitialValues({
      'user_groq_api_key': 'legacy-test-key',
    });
  });

  test(
    'existing BYOK settings keep Groq and each provider retains its model',
    () async {
      final prefs = await PreferencesService.create();
      expect(prefs.providerMode, ProviderMode.byok);
      expect(prefs.directAiProvider, DirectAiProvider.groq);
      for (final provider in DirectAiProvider.values) {
        expect(prefs.visionModelFor(provider), provider.defaultModel);
        await prefs.setVisionModel(provider, 'test-${provider.name}');
      }
      for (final provider in DirectAiProvider.values) {
        await prefs.setDirectAiProvider(provider);
        expect(prefs.visionModelFor(provider), 'test-${provider.name}');
      }
    },
  );

  test(
    'existing provider names and legacy indices retain their destination',
    () async {
      const existing = [
        DirectAiProvider.groq,
        DirectAiProvider.openai,
        DirectAiProvider.gemini,
      ];
      for (var index = 0; index < existing.length; index++) {
        for (final saved in <Object>[index, existing[index].name]) {
          SharedPreferences.setMockInitialValues({
            'provider_mode': 'byok',
            'direct_ai_provider': saved,
            'vision_model_${existing[index].name}': 'saved-model',
          });
          final prefs = await PreferencesService.create();
          expect(prefs.directAiProvider, existing[index]);
          expect(prefs.visionModelFor(existing[index]), 'saved-model');
          await prefs.setDirectAiProvider(prefs.directAiProvider);
          final stored = await SharedPreferences.getInstance();
          expect(stored.getString('direct_ai_provider'), existing[index].name);
        }
      }
    },
  );

  test(
    'missing or invalid selection stays Groq, never opts into Mistral',
    () async {
      for (final saved in <Object?>[null, -1, 999, 'unknown', true]) {
        SharedPreferences.setMockInitialValues({'direct_ai_provider': ?saved});
        final prefs = await PreferencesService.create();
        expect(prefs.directAiProvider, DirectAiProvider.groq);
        expect(prefs.providerMode, ProviderMode.hosted);
        expect(prefs.cloudConsentGranted, isFalse);
      }
    },
  );

  test('Mistral selection and model survive reload without changing other settings', () async {
    final prefs = await PreferencesService.create();
    for (final provider in DirectAiProvider.values.where(
      (p) => p != DirectAiProvider.mistral,
    )) {
      await prefs.setVisionModel(provider, 'saved-${provider.name}');
    }
    expect(
      prefs.visionModelFor(DirectAiProvider.mistral),
      'mistral-small-latest',
    );
    await prefs.setVisionModel(
      DirectAiProvider.mistral,
      ' mistral-small-latest ',
    );
    await prefs.setDirectAiProvider(DirectAiProvider.mistral);
    final reloaded = await PreferencesService.create();
    expect(reloaded.directAiProvider, DirectAiProvider.mistral);
    expect(
      reloaded.visionModelFor(DirectAiProvider.mistral),
      'mistral-small-latest',
    );
    for (final provider in DirectAiProvider.values.where(
      (p) => p != DirectAiProvider.mistral,
    )) {
      expect(reloaded.visionModelFor(provider), 'saved-${provider.name}');
    }
    expect(reloaded.providerMode, ProviderMode.byok);
    expect(reloaded.cloudConsentGranted, isFalse);
  });

  test(
    'provider keys are isolated and the legacy Groq key is preserved',
    () async {
      final credentials = CredentialService();
      expect(
        await credentials.getProviderApiKey(DirectAiProvider.groq),
        'legacy-test-key',
      );
      expect(
        await credentials.getProviderApiKey(DirectAiProvider.openai),
        isNull,
      );
      expect(
        await credentials.getProviderApiKey(DirectAiProvider.gemini),
        isNull,
      );
      expect(
        await credentials.getProviderApiKey(DirectAiProvider.mistral),
        isNull,
      );
      await credentials.setProviderApiKey(
        DirectAiProvider.mistral,
        ' mistral-test ',
      );
      await credentials.setProviderApiKey(
        DirectAiProvider.openai,
        ' openai-test ',
      );
      await credentials.setProviderApiKey(
        DirectAiProvider.gemini,
        'gemini-test',
      );
      await credentials.clearProviderApiKey(DirectAiProvider.openai);
      expect(
        await credentials.getProviderApiKey(DirectAiProvider.openai),
        isNull,
      );
      expect(
        await credentials.getProviderApiKey(DirectAiProvider.gemini),
        'gemini-test',
      );
      expect(
        await credentials.getProviderApiKey(DirectAiProvider.mistral),
        'mistral-test',
      );
      // Removal never affects another provider's credential or hosted token.
      await credentials.setDemoAccessToken('hosted-test');
      await credentials.clearProviderApiKey(DirectAiProvider.mistral);
      expect(
        await credentials.getProviderApiKey(DirectAiProvider.mistral),
        isNull,
      );
      expect(
        await credentials.getProviderApiKey(DirectAiProvider.gemini),
        'gemini-test',
      );
      expect(await credentials.getDemoAccessToken(), 'hosted-test');
      expect(await credentials.getUserGroqApiKey(), 'legacy-test-key');
    },
  );

  test('metadata checks use the selected provider and require the model to be listed', () async {
    for (final provider in DirectAiProvider.values) {
      final adapter = ScriptedAdapter(
        (_) async => jsonBody({
          'data': [
            {'id': provider.defaultModel},
          ],
        }),
      );
      final credentials = CredentialService(
        dio: Dio()..httpClientAdapter = adapter,
      );
      expect(
        await credentials.testProviderModel(
          provider,
          'metadata-test',
          provider.defaultModel,
        ),
        isTrue,
      );
      expect(adapter.last?.uri.toString(), provider.modelsUrl);
      expect(adapter.last?.headers['Authorization'], 'Bearer metadata-test');
      expect(adapter.last?.followRedirects, isFalse);
      expect(
        await credentials.testProviderModel(
          provider,
          'metadata-test',
          'unavailable',
        ),
        isFalse,
      );
    }
  });

  test(
    'Mistral metadata accepts documented aliases only for Mistral',
    () async {
      final adapter = ScriptedAdapter(
        (_) async => jsonBody({
          'data': [
            null,
            {'id': 'not-the-model', 'aliases': 'mistral-small-latest'},
            {
              'id': 'versioned-model',
              'aliases': ['mistral-small-latest'],
            },
          ],
        }),
      );
      final credentials = CredentialService(
        dio: Dio()..httpClientAdapter = adapter,
      );
      for (final provider in DirectAiProvider.values) {
        expect(
          await credentials.testProviderModel(
            provider,
            'metadata-test',
            'mistral-small-latest',
          ),
          provider == DirectAiProvider.mistral,
        );
        expect(adapter.last?.method, 'GET');
        expect(adapter.last?.data, isNull);
        expect(adapter.last?.followRedirects, isFalse);
      }
    },
  );

  test(
    'Mistral metadata rejects redirects and account errors without inference',
    () async {
      for (final status in [302, 401, 403, 429]) {
        var requests = 0;
        final adapter = ScriptedAdapter((_) async {
          requests++;
          return ResponseBody.fromString(
            'SECRET RAW ERROR',
            status,
            headers: {
              'location': ['https://untrusted.example/collect'],
            },
          );
        });
        final credentials = CredentialService(
          dio: Dio()..httpClientAdapter = adapter,
        );
        expect(
          await credentials.testProviderModel(
            DirectAiProvider.mistral,
            'metadata-test',
            'mistral-small-latest',
          ),
          isFalse,
        );
        expect(requests, 1);
        expect(
          adapter.last?.uri.toString(),
          'https://api.mistral.ai/v1/models',
        );
        expect(adapter.last?.followRedirects, isFalse);
      }
    },
  );

  test(
    'coordinator creates the selected provider and model after refresh',
    () async {
      final prefs = await PreferencesService.create();
      final coordinator = AgentCoordinator(
        cameraService: FakeCameraService(),
        ttsService: FakeTtsService(prefs),
        speechService: FakeSpeechService(),
        ocrService: FakeOcrService(),
        hapticService: FakeHapticService(prefs),
        preferencesService: prefs,
        credentialService: MemoryCredentials(),
        logService: DiagnosticLogService(prefs),
      );
      for (final provider in DirectAiProvider.values) {
        await prefs.setDirectAiProvider(provider);
        await prefs.setVisionModel(provider, 'chosen-${provider.name}');
        coordinator.refreshVisionProvider();
        final transport =
            coordinator.sceneAgent.visionApi as OpenAiCompatibleVisionProvider;
        expect(transport.provider, provider);
        expect(transport.model, 'chosen-${provider.name}');
      }
      coordinator.dispose();
    },
  );
}
