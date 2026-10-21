import 'package:eyesense/services/preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'every profile starts with audible results, including a sighted helper',
    () async {
      final preferences = await PreferencesService.create();
      for (final profile in AssistanceProfile.values) {
        await preferences.applyProfileDefaults(profile);
        expect(preferences.assistanceProfile, profile);
        expect(preferences.autoRead, isTrue, reason: profile.name);
      }
    },
  );

  test('a helper can still turn automatic speech off explicitly', () async {
    final preferences = await PreferencesService.create();
    await preferences.applyProfileDefaults(AssistanceProfile.sightedAssistant);
    await preferences.setAutoRead(false);
    expect(preferences.autoRead, isFalse);
  });
}
