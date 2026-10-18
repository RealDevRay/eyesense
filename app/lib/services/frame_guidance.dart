import 'dart:typed_data';

/// On-device framing estimate from a luminance plane.
///
/// Every phrase describes the image, never the physical world. Nothing here
/// asserts distance, proximity, or a safe path.
class FrameAssessment {
  final double meanLuminance;
  final double variance;
  final double sharpness;
  final double textCoverage;
  final String? correction;

  const FrameAssessment({
    required this.meanLuminance,
    required this.variance,
    required this.sharpness,
    required this.textCoverage,
    required this.correction,
  });

  bool get readyToCapture => correction == null;

  bool isStableWith(FrameAssessment other) {
    return (meanLuminance - other.meanLuminance).abs() < 8 &&
        (textCoverage - other.textCoverage).abs() < 0.08 &&
        correction == other.correction;
  }
}

class FrameGuidance {
  /// [bytes] is a luminance (Y) plane. [bytesPerRow] may exceed [width].
  static FrameAssessment assess(
    Uint8List bytes,
    int width,
    int height, {
    int? bytesPerRow,
  }) {
    if (width < 8 || height < 8 || bytes.isEmpty) {
      return const FrameAssessment(
        meanLuminance: 0,
        variance: 0,
        sharpness: 0,
        textCoverage: 0,
        correction: 'Hold steady.',
      );
    }

    final stride = bytesPerRow ?? width;
    const sample = 4;
    double sum = 0;
    double sumSq = 0;
    int count = 0;
    double edgeSum = 0;
    int edgeCount = 0;

    final blocksX = 4;
    final blocksY = 4;
    final blockScores = List<double>.filled(blocksX * blocksY, 0);
    final blockCounts = List<int>.filled(blocksX * blocksY, 0);

    for (var y = 0; y < height; y += sample) {
      final row = y * stride;
      if (row >= bytes.length) break;
      for (var x = 0; x < width; x += sample) {
        final index = row + x;
        if (index >= bytes.length) break;
        final value = bytes[index].toDouble();
        sum += value;
        sumSq += value * value;
        count++;

        final right = index + sample;
        if (x + sample < width && right < bytes.length) {
          edgeSum += (value - bytes[right]).abs();
          edgeCount++;
        }

        final bx = (x * blocksX) ~/ width;
        final by = (y * blocksY) ~/ height;
        final block = by * blocksX + bx;
        blockScores[block] += value;
        blockCounts[block]++;
      }
    }

    if (count == 0) {
      return const FrameAssessment(
        meanLuminance: 0,
        variance: 0,
        sharpness: 0,
        textCoverage: 0,
        correction: 'Hold steady.',
      );
    }

    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    final sharpness = edgeCount == 0 ? 0.0 : edgeSum / edgeCount;

    var busyBlocks = 0;
    var topBusy = 0;
    var bottomBusy = 0;
    for (var i = 0; i < blockScores.length; i++) {
      if (blockCounts[i] == 0) continue;
      final blockMean = blockScores[i] / blockCounts[i];
      // A block is "busy" when its mean differs from the frame, a cheap
      // stand-in for text or other high-contrast content.
      if ((blockMean - mean).abs() > 18 || (variance > 400 && sharpness > 12)) {
        busyBlocks++;
        if (i < blocksX) topBusy++;
        if (i >= blocksX * (blocksY - 1)) bottomBusy++;
      }
    }
    final coverage = busyBlocks / (blocksX * blocksY);

    String? correction;
    if (mean < 18 && variance < 40) {
      correction = 'The lens may be covered.';
    } else if (mean < 42) {
      correction = 'More light is needed.';
    } else if (sharpness < 6) {
      correction = 'Hold steady.';
    } else if (coverage < 0.12) {
      correction = 'Move closer.';
    } else if (coverage > 0.85 && topBusy > 0 && bottomBusy > 0) {
      correction = 'The whole page is not visible.';
    } else if (bottomBusy >= 3 && topBusy == 0) {
      correction = 'Tilt up.';
    } else if (topBusy >= 3 && bottomBusy == 0) {
      correction = 'Tilt down.';
    }

    return FrameAssessment(
      meanLuminance: mean,
      variance: variance < 0 ? 0 : variance,
      sharpness: sharpness,
      textCoverage: coverage,
      correction: correction,
    );
  }
}
