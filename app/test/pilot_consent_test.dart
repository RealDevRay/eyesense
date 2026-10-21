import 'package:eyesense/core/config/app_config.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('new installations do not grant cloud consent', () async {
    final preferences = await PreferencesService.create();

    expect(preferences.cloudConsentGranted, isFalse);
    expect(preferences.acceptedTermsVersion, isNull);
  });

  for (final version in <String?>[null, '1.0']) {
    test(
      'stored opt-in with terms version $version requires reconsent',
      () async {
        SharedPreferences.setMockInitialValues({
          'cloud_consent_granted': true,
          'terms_version_accepted': ?version,
          'completed_onboarding': true,
          'safety_briefing_acknowledged_version': '1.0',
          'provider_mode': 'byok',
          'direct_ai_provider': 'groq',
          'app_mode': 'readText',
        });
        final preferences = await PreferencesService.create();

        expect(preferences.cloudConsentGranted, isFalse);
        expect(preferences.hasAcknowledgedSafety, isFalse);
        expect(preferences.hasCompletedOnboarding, isTrue);
        expect(preferences.acceptedTermsVersion, version);
        final stored = await SharedPreferences.getInstance();
        expect(stored.getString('provider_mode'), 'byok');
        expect(stored.getString('direct_ai_provider'), 'groq');
        expect(stored.getString('app_mode'), 'readText');
        expect(
          (await PreferencesService.create()).cloudConsentGranted,
          isFalse,
        );
      },
    );

    test('explicit regrant upgrades terms version $version', () async {
      SharedPreferences.setMockInitialValues({
        'cloud_consent_granted': true,
        'terms_version_accepted': ?version,
        'terms_accepted_at': '2026-10-18T00:00:00.000Z',
      });
      final preferences = await PreferencesService.create();
      final before = DateTime.now().toUtc();

      await preferences.setCloudConsentGranted(true);

      final stored = await SharedPreferences.getInstance();
      expect(stored.getBool('cloud_consent_granted'), isTrue);
      expect(
        stored.getString('terms_version_accepted'),
        AppConfig.termsVersion,
      );
      expect(preferences.acceptedTermsVersion, AppConfig.termsVersion);
      final acceptedAt = DateTime.parse(preferences.acceptedTermsAt!);
      expect(acceptedAt.isUtc, isTrue);
      expect(acceptedAt.isBefore(before), isFalse);
      expect(acceptedAt.isAfter(DateTime.now().toUtc()), isFalse);
      expect((await PreferencesService.create()).cloudConsentGranted, isTrue);
    });

    test(
      'terms acceptance alone cannot revive version $version opt-in',
      () async {
        SharedPreferences.setMockInitialValues({
          'cloud_consent_granted': true,
          'terms_version_accepted': ?version,
        });
        final preferences = await PreferencesService.create();

        await preferences.recordTermsAcceptance();

        expect(preferences.acceptedTermsVersion, AppConfig.termsVersion);
        expect(preferences.cloudConsentGranted, isFalse);
        expect(
          (await PreferencesService.create()).cloudConsentGranted,
          isFalse,
        );
      },
    );
  }

  test(
    'current version consent persists without rewriting acceptance',
    () async {
      const acceptedAt = '2026-10-21T00:00:00.000Z';
      SharedPreferences.setMockInitialValues({
        'cloud_consent_granted': true,
        'terms_version_accepted': AppConfig.termsVersion,
        'terms_accepted_at': acceptedAt,
        'safety_briefing_acknowledged_version': AppConfig.termsVersion,
      });
      final preferences = await PreferencesService.create();

      expect(preferences.cloudConsentGranted, isTrue);
      expect(preferences.hasAcknowledgedSafety, isTrue);
      expect(preferences.acceptedTermsAt, acceptedAt);
      final reopened = await PreferencesService.create();
      expect(reopened.cloudConsentGranted, isTrue);
      expect(reopened.acceptedTermsAt, acceptedAt);
      await reopened.recordTermsAcceptance();
      expect(reopened.cloudConsentGranted, isTrue);
    },
  );

  test(
    'current accepted terms without cloud opt-in do not grant consent',
    () async {
      SharedPreferences.setMockInitialValues({
        'terms_version_accepted': AppConfig.termsVersion,
      });
      final preferences = await PreferencesService.create();

      await preferences.recordTermsAcceptance();

      expect(preferences.cloudConsentGranted, isFalse);
    },
  );

  test('explicit grant from defaults records current version', () async {
    final preferences = await PreferencesService.create();

    await preferences.setCloudConsentGranted(true);

    expect(preferences.cloudConsentGranted, isTrue);
    expect(preferences.acceptedTermsVersion, AppConfig.termsVersion);
    expect(preferences.acceptedTermsAt, isNotNull);
    expect((await PreferencesService.create()).cloudConsentGranted, isTrue);
  });

  test('revocation persists and accepting terms cannot undo it', () async {
    final preferences = await PreferencesService.create();
    await preferences.setCloudConsentGranted(true);
    final acceptedAt = preferences.acceptedTermsAt;

    await preferences.setCloudConsentGranted(false);

    expect(preferences.cloudConsentGranted, isFalse);
    expect(preferences.acceptedTermsVersion, AppConfig.termsVersion);
    expect(preferences.acceptedTermsAt, acceptedAt);
    expect(
      (await SharedPreferences.getInstance()).getBool('cloud_consent_granted'),
      isFalse,
    );
    final reopened = await PreferencesService.create();
    await reopened.recordTermsAcceptance();
    expect(reopened.cloudConsentGranted, isFalse);
  });
}
