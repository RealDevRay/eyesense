/// Maps the product speech-rate scale onto the range `flutter_tts` accepts.
///
/// The slider is 0.5×–2.0× in seven steps. On Android the plugin accepts
/// 0.0–1.0, where 0.5 is normal speed. Dividing the product rate by 2 maps
/// 1.0× to that normal rate and 2.0× to the platform maximum, so every slider
/// step stays distinct. Persisted values are already on the product scale
/// (the old slider stored 0.5–2.0), so their meaning does not change and no
/// stored-value migration is required.
class SpeechRateScale {
  static const double minProduct = 0.5;
  static const double maxProduct = 2.0;
  static const int divisions = 6;

  static double toPlatformRate(double productRate) {
    final clamped = productRate.clamp(minProduct, maxProduct);
    return clamped / maxProduct;
  }

  static List<double> get divisionValues {
    final step = (maxProduct - minProduct) / divisions;
    return List<double>.generate(divisions + 1, (index) => minProduct + index * step);
  }

  static String labelFor(double productRate) {
    return '${productRate.toStringAsFixed(2)} times normal speed';
  }
}
