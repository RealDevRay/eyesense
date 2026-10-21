import 'dart:typed_data';

/// Conservative image-quality estimates from a luminance plane.
///
/// Luminance and contrast cannot establish physical tilt, distance, text, page
/// boundaries, or a safe path. Cues describe only observable image quality.
class FrameAssessment {
  final double meanLuminance;
  final double variance;

  /// Sampled edge contrast, not a reliable measure of focus or motion blur.
  final double sharpness;

  /// Legacy name for the fraction of sampled edges with noticeable contrast.
  /// This does not identify text or measure how much of a page is visible.
  final double textCoverage;
  final String? correction;

  const FrameAssessment({
    required this.meanLuminance,
    required this.variance,
    required this.sharpness,
    required this.textCoverage,
    required this.correction,
  });

  /// No quality cue is pending; this does not guarantee readable text or framing.
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
        correction: 'Image quality could not be assessed.',
      );
    }

    final stride = bytesPerRow ?? width;
    const sample = 4;
    double sum = 0;
    double sumSq = 0;
    int count = 0;
    double edgeSum = 0;
    int edgeCount = 0;
    int contrastingEdges = 0;

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
          final contrast = (value - bytes[right]).abs();
          edgeSum += contrast;
          edgeCount++;
          if (contrast > 12) contrastingEdges++;
        }
      }
    }

    if (count == 0) {
      return const FrameAssessment(
        meanLuminance: 0,
        variance: 0,
        sharpness: 0,
        textCoverage: 0,
        correction: 'Image quality could not be assessed.',
      );
    }

    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    final sharpness = edgeCount == 0 ? 0.0 : edgeSum / edgeCount;

    final coverage = edgeCount == 0 ? 0.0 : contrastingEdges / edgeCount;

    String? correction;
    if (mean < 42) {
      correction = 'The image is dark. More light may help.';
    } else if (sharpness < 6) {
      correction = 'The image has little detail.';
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
