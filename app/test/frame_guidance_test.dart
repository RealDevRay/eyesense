import 'dart:typed_data';

import 'package:eyesense/services/frame_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Uint8List plane(int value, {int width = 64, int height = 64}) {
    return Uint8List(width * height)..fillRange(0, width * height, value);
  }

  test('a uniform black frame is treated as a covered lens', () {
    final assessment = FrameGuidance.assess(plane(0), 64, 64);
    expect(assessment.correction, 'The lens may be covered.');
    expect(assessment.readyToCapture, isFalse);
  });

  test('a uniform mid-gray frame asks the user to hold steady', () {
    final assessment = FrameGuidance.assess(plane(128), 64, 64);
    expect(assessment.correction, 'Hold steady.');
    expect(assessment.readyToCapture, isFalse);
  });
}
