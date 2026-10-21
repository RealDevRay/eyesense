import 'dart:typed_data';

import 'package:eyesense/services/frame_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Uint8List plane(int Function(int x, int y) pixel, {int stride = 64}) {
    final bytes = Uint8List(stride * 64);
    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        bytes[y * stride + x] = pixel(x, y);
      }
    }
    return bytes;
  }

  test('black and dim images get quality cues, not a covered-lens claim', () {
    for (final value in [0, 30]) {
      final assessment = FrameGuidance.assess(plane((_, _) => value), 64, 64);
      expect(assessment.correction, 'The image is dark. More light may help.');
      expect(assessment.readyToCapture, isFalse);
    }
  });

  test(
    'a uniform image reports little detail without claiming motion blur',
    () {
      final assessment = FrameGuidance.assess(plane((_, _) => 128), 64, 64);
      expect(assessment.correction, 'The image has little detail.');
      expect(assessment.readyToCapture, isFalse);
      expect(assessment.variance, 0);
      expect(assessment.sharpness, 0);
      expect(assessment.textCoverage, 0);
    },
  );

  test('high global variance does not imply a cropped page', () {
    final bytes = plane((x, _) => (x ~/ 4).isEven ? 64 : 192);
    final assessment = FrameGuidance.assess(bytes, 64, 64);
    expect(assessment.variance, greaterThan(400));
    expect(assessment.correction, isNull);
    expect(assessment.readyToCapture, isTrue);
  });

  test('fine contrast does not imply a need to move closer', () {
    final bytes = plane((x, _) => (x ~/ 4).isEven ? 118 : 138);
    final assessment = FrameGuidance.assess(bytes, 64, 64);
    expect(assessment.sharpness, greaterThan(6));
    expect(assessment.correction, isNull);
  });

  for (final top in [true, false]) {
    test(
      'detail at the ${top ? 'top' : 'bottom'} does not imply physical tilt',
      () {
        final bytes = plane((x, y) {
          final inBand = top ? y < 16 : y >= 48;
          return inBand ? ((x ~/ 4).isEven ? 154 : 186) : 128;
        });
        final assessment = FrameGuidance.assess(bytes, 64, 64);
        expect(assessment.variance, lessThan(400));
        expect(assessment.sharpness, greaterThan(6));
        expect(assessment.correction, isNull);
      },
    );
  }

  test('row padding does not change the quality assessment', () {
    int pixel(int x, int y) => (x ~/ 4).isEven ? 64 : 192;
    final packed = FrameGuidance.assess(plane(pixel), 64, 64);
    final padded = FrameGuidance.assess(
      plane(pixel, stride: 80),
      64,
      64,
      bytesPerRow: 80,
    );
    expect(padded.meanLuminance, packed.meanLuminance);
    expect(padded.variance, packed.variance);
    expect(padded.sharpness, packed.sharpness);
    expect(padded.textCoverage, packed.textCoverage);
    expect(padded.correction, packed.correction);
    expect(padded.isStableWith(packed), isTrue);
  });

  test(
    'similar quality measurements can be stable without claiming framing',
    () {
      final first = FrameGuidance.assess(
        plane((x, _) => (x ~/ 4).isEven ? 64 : 192),
        64,
        64,
      );
      final similar = FrameGuidance.assess(
        plane((x, _) => (x ~/ 4).isEven ? 66 : 194),
        64,
        64,
      );
      final different = FrameGuidance.assess(plane((_, _) => 30), 64, 64);
      expect(first.isStableWith(similar), isTrue);
      expect(first.isStableWith(different), isFalse);
    },
  );

  test('unusable input does not invent a physical correction', () {
    for (final bytes in [Uint8List(0), Uint8List(16)]) {
      final assessment = FrameGuidance.assess(bytes, 4, 4);
      expect(assessment.correction, 'Image quality could not be assessed.');
      expect(assessment.readyToCapture, isFalse);
    }
  });
}
