import 'package:eyesense/core/speech/speech_rate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every speech-rate division maps to a distinct platform rate', () {
    final rates = SpeechRateScale.divisionValues.map(SpeechRateScale.toPlatformRate).toList();
    expect(rates.toSet(), hasLength(SpeechRateScale.divisions + 1));
    expect(rates.first, closeTo(0.25, 0.0001));
    expect(rates[2], closeTo(0.5, 0.0001));
    expect(rates.last, closeTo(1.0, 0.0001));
    for (var i = 1; i < rates.length; i++) {
      expect(rates[i], greaterThan(rates[i - 1]));
    }
  });
}
