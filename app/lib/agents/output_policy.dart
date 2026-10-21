import 'package:eyesense/core/config/app_config.dart';
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:eyesense/models/scene_result.dart';

class OutputPolicy {
  static const List<String> prohibitedPhrasesEn = [
    'safe to cross',
    'clear to cross',
    'cross the road',
    'cross the street',
    'cross now',
    'path is clear',
    'clear path',
    'no hazards present',
    'no hazards',
    'no obstacles',
    'safe to proceed',
    'walk forward',
    'turn left now',
    'turn right now',
    'imminent collision',
    'about to hit',
  ];

  static const List<String> prohibitedPhrasesSw = [
    'salama kuvuka',
    'vuka barabara',
    'vuka sasa',
    'njia iko wazi',
    'njia ni wazi',
    'hakuna vikwazo',
    'salama kuendelea',
    'tembea mbele',
    'karibu kugongana',
  ];

  // Normalization closes formatting bypasses, but is not semantic safety proof.
  static String _normalize(String text) => text
      .toLowerCase()
      .replaceAll(
        RegExp(r'[\u200b-\u200f\u202a-\u202e\u2060-\u2069\ufeff]'),
        '',
      )
      .replaceAll(RegExp(r'[^a-z0-9\s.]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static final _movement = RegExp(
    r'\b(?:take|walk|move|go|proceed|step|turn)\s+(?:(?:one|two|three|four|five|six|seven|eight|nine|ten|\d+)\s+(?:steps?\s+)?)?(?:forward|backward|back|ahead|left|right|straight)\b|'
    r'\b(?:take|walk|move|go)\s+(?:one|two|three|four|five|six|seven|eight|nine|ten|\d+)\s+steps?\b|'
    r'\b(?:you|it)\s+(?:may|can|is)\s+(?:safely\s+)?(?:cross|proceed|walk)\b|'
    r'\b(?:safe|safely|clear)\s+(?:to\s+)?(?:cross|walk|proceed)\b|'
    r'\b(?:tembea|songa|geuka)\s+(?:mbele|nyuma|kushoto|kulia)\b|'
    r'\bpiga\s+hatua\b',
  );
  static final _distance = RegExp(
    r'\b(?:\d+(?:\.\d+)?|one|two|three|four|five|six|seven|eight|nine|ten)\s*'
    r'(?:m|cm|mm|km|meters?|metres?|centimeters?|centimetres?|feet|foot|ft|inches?|in)\s*'
    r'(?:away|ahead|behind|from|to|in front|on your)\b|'
    r'\b(?:distance|depth)\s+(?:is|of|approximately|about)\s+\d|'
    r'\b(?:mita|sentimita)\s+(?:\d+|moja|mbili|tatu|nne|tano)\b',
  );

  /// Conservative pilot gate, not a general natural-language classifier.
  static bool isNavigationQuestion(String text) {
    final normalized = _normalize(text);
    return containsProhibitedSafetyGuidance(text) ||
        RegExp(
          r'\b(?:cross|crossing|navigate|navigation|directions|distance)\b|'
          r'\bhow\s+(?:far|many\s+steps)\b|'
          r'\b(?:safe|clear)\b.*\b(?:walk|go|move|path|route|road|street|proceed)\b|'
          r'\b(?:can|should|may|where|which way)\b.*\b(?:walk|step|turn|go|move)\b|'
          r'\b(?:kuvuka|vuka|nitembee|nigeuke|umbali|hatua ngapi|njia salama)\b',
        ).hasMatch(normalized);
  }

  static String navigationLimitation(String language) => language == 'sw'
      ? 'EyeSense haiwezi kuamua usalama wa njia, umbali, au kutoa maelekezo ya kutembea. Tumia msaada wako wa kawaida wa uhamaji au mtu unayemwamini.'
      : 'EyeSense cannot decide whether a route is safe, measure distance, or give walking directions. Use your usual mobility aids or a trusted person.';

  static bool containsProhibitedSafetyGuidance(String text) {
    final lower = _normalize(text);
    for (final phrase in prohibitedPhrasesEn) {
      if (lower.contains(phrase)) return true;
    }
    for (final phrase in prohibitedPhrasesSw) {
      if (lower.contains(phrase)) return true;
    }
    return _movement.hasMatch(lower) || _distance.hasMatch(lower);
  }

  /// Validates a SceneResult before display and speech.
  /// Throws [AppException] if stale, cancelled, or schema-invalid.
  /// If prohibited safety claims are present, replaces them with a conservative limitation response.
  static SceneResult validateSceneResult({
    required SceneResult result,
    required DateTime captureTimestamp,
    required int taskGeneration,
    required int currentGeneration,
    DateTime Function()? nowProvider,
    String language = 'en',
  }) {
    // 1. Generation check (ensure task wasn't cancelled or superseded)
    if (taskGeneration != currentGeneration) {
      throw const AppException(
        code: ErrorCode.operationCancelled,
        userMessage: 'Operation was cancelled.',
      );
    }

    // Freshness is decided once, at delivery, before anything is spoken.
    final now = nowProvider != null ? nowProvider() : DateTime.now();
    final elapsed = now.difference(captureTimestamp);
    if (elapsed > AppConfig.sceneFreshnessLimit) {
      throw const AppException(
        code: ErrorCode.staleResultDiscarded,
        userMessage: 'This observation is out of date. Take the picture again.',
      );
    }

    // 3. Schema & content validation
    if (result.summary.trim().isEmpty) {
      throw const AppException(
        code: ErrorCode.validationFailed,
        userMessage: 'Could not obtain a clear scene description.',
      );
    }

    return applyFieldReplacements(result, language);
  }

  /// Replaces only the fields that contain prohibited guidance.
  /// A violation in one field does not discard text in another.
  static SceneResult applyFieldReplacements(
    SceneResult result,
    String language,
  ) {
    final isSwahili = language == 'sw';
    final limitationSummary = isSwahili
        ? 'Picha inaonekana. EyeSense haiwezi kuthibitisha njia salama au kutoa maelekezo ya kuvuka. Tafadhali tumia msaada wako wa kawaida wa uhamaji.'
        : 'Scene detected. EyeSense cannot confirm navigation safety or crossing decisions. Please rely on your mobility aids and physical orientation.';
    final limitationAnswer = isSwahili
        ? 'EyeSense haiwezi kuamua usalama wa njia au kuvuka. Tafadhali tegemea vifaa vyako vya uhamaji.'
        : 'EyeSense cannot determine path safety or crossing decisions. Please rely on your mobility aids.';
    final limitationNote = isSwahili
        ? 'Tahadhari ya usalama: Maelekezo ya kutembea au kuvuka hayawezi kutolewa kutoka kwa picha.'
        : 'Safety limitation: Walking or crossing guidance cannot be provided from images.';
    final unspecified = isSwahili ? 'haijabainishwa' : 'unspecified';

    final summaryViolates = containsProhibitedSafetyGuidance(result.summary);
    final answerViolates =
        result.answer != null &&
        containsProhibitedSafetyGuidance(result.answer!);
    final concernViolates =
        result.concernDescription != null &&
        containsProhibitedSafetyGuidance(result.concernDescription!);
    final uncertaintyViolates =
        result.uncertainty != null &&
        containsProhibitedSafetyGuidance(result.uncertainty!);
    final objects = result.objects
        .map(
          (object) =>
              containsProhibitedSafetyGuidance(object) ? unspecified : object,
        )
        .toList();
    final objectsChanged = !_sameStrings(objects, result.objects);

    if (!summaryViolates &&
        !answerViolates &&
        !concernViolates &&
        !uncertaintyViolates &&
        !objectsChanged) {
      return result;
    }

    return result.copyWith(
      summary: summaryViolates ? limitationSummary : result.summary,
      answer: answerViolates ? limitationAnswer : result.answer,
      concernDescription: concernViolates
          ? limitationNote
          : result.concernDescription,
      uncertainty: uncertaintyViolates ? limitationNote : result.uncertainty,
      objects: objects,
      possibleConcern: result.possibleConcern || concernViolates,
    );
  }

  static bool _sameStrings(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
