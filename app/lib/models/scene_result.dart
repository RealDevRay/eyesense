import 'package:eyesense/core/errors/app_exceptions.dart';

enum SceneDirection {
  left,
  centre,
  right,
  multiple,
  unknown;

  static SceneDirection fromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'left':
        return SceneDirection.left;
      case 'centre':
      case 'center':
        return SceneDirection.centre;
      case 'right':
        return SceneDirection.right;
      case 'multiple':
        return SceneDirection.multiple;
      case 'unknown':
        return SceneDirection.unknown;
      default:
        throw const AppException(
          code: ErrorCode.validationFailed,
          userMessage: 'Invalid direction value in scene result.',
        );
    }
  }

  String toJson() {
    switch (this) {
      case SceneDirection.left:
        return 'left';
      case SceneDirection.centre:
        return 'centre';
      case SceneDirection.right:
        return 'right';
      case SceneDirection.multiple:
        return 'multiple';
      case SceneDirection.unknown:
        return 'unknown';
    }
  }
}

enum ImageQuality {
  usable,
  unclear;

  static ImageQuality fromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'usable':
        return ImageQuality.usable;
      case 'unclear':
        return ImageQuality.unclear;
      default:
        throw const AppException(
          code: ErrorCode.validationFailed,
          userMessage: 'Invalid imageQuality value in scene result.',
        );
    }
  }

  String toJson() => this == ImageQuality.usable ? 'usable' : 'unclear';
}

class SceneResult {
  final String summary;
  final String? answer;
  final bool possibleConcern;
  final String? concernDescription;
  final SceneDirection direction;
  final List<String> objects;
  final ImageQuality imageQuality;
  final String? uncertainty;

  const SceneResult({
    required this.summary,
    this.answer,
    required this.possibleConcern,
    this.concernDescription,
    required this.direction,
    required this.objects,
    required this.imageQuality,
    this.uncertainty,
  });

  factory SceneResult.fromJson(Map<String, dynamic> json) {
    final rawSummary = json['summary'];
    if (rawSummary is! String || rawSummary.trim().isEmpty) {
      throw const AppException(
        code: ErrorCode.validationFailed,
        userMessage: 'Invalid or missing summary in scene result.',
      );
    }

    final rawQuality = json['imageQuality'];
    if (rawQuality is! String) {
      throw const AppException(
        code: ErrorCode.validationFailed,
        userMessage: 'Missing imageQuality field in scene result.',
      );
    }
    final quality = ImageQuality.fromString(rawQuality);

    final rawDirection = json['direction'];
    if (rawDirection is! String) {
      throw const AppException(
        code: ErrorCode.validationFailed,
        userMessage: 'Missing direction field in scene result.',
      );
    }
    final direction = SceneDirection.fromString(rawDirection);

    final rawPossibleConcern = json['possibleConcern'];
    if (rawPossibleConcern is! bool) {
      throw const AppException(
        code: ErrorCode.validationFailed,
        userMessage: 'Missing or non-boolean possibleConcern field in scene result.',
      );
    }

    final rawConcernDesc = json['concernDescription'] as String?;
    if (rawPossibleConcern && (rawConcernDesc == null || rawConcernDesc.trim().isEmpty)) {
      throw const AppException(
        code: ErrorCode.validationFailed,
        userMessage: 'Missing concernDescription when possibleConcern is true.',
      );
    }

    final rawAnswer = json['answer'] as String?;
    final rawUncertainty = json['uncertainty'] as String?;

    final rawObjects = json['objects'];
    final List<String> parsedObjects = [];
    if (rawObjects is List) {
      for (final item in rawObjects) {
        if (item is String && item.trim().isNotEmpty) {
          parsedObjects.add(item.trim());
        }
      }
    }

    final trimmedSummary = rawSummary.trim();
    final boundedSummary = trimmedSummary.length > 350
        ? trimmedSummary.substring(0, 350)
        : trimmedSummary;

    final trimmedAnswer = rawAnswer?.trim();
    final boundedAnswer = trimmedAnswer != null && trimmedAnswer.length > 350
        ? trimmedAnswer.substring(0, 350)
        : trimmedAnswer;

    final trimmedConcernDesc = rawConcernDesc?.trim();
    final boundedConcernDesc = trimmedConcernDesc != null && trimmedConcernDesc.length > 250
        ? trimmedConcernDesc.substring(0, 250)
        : trimmedConcernDesc;

    final trimmedUncertainty = rawUncertainty?.trim();
    final boundedUncertainty = trimmedUncertainty != null && trimmedUncertainty.length > 250
        ? trimmedUncertainty.substring(0, 250)
        : trimmedUncertainty;

    return SceneResult(
      summary: boundedSummary,
      answer: boundedAnswer,
      possibleConcern: rawPossibleConcern,
      concernDescription: boundedConcernDesc,
      direction: direction,
      objects: parsedObjects.take(8).toList(),
      imageQuality: quality,
      uncertainty: boundedUncertainty,
    );
  }

  SceneResult copyWith({
    String? summary,
    String? answer,
    bool? possibleConcern,
    String? concernDescription,
    SceneDirection? direction,
    List<String>? objects,
    ImageQuality? imageQuality,
    String? uncertainty,
  }) {
    return SceneResult(
      summary: summary ?? this.summary,
      answer: answer ?? this.answer,
      possibleConcern: possibleConcern ?? this.possibleConcern,
      concernDescription: concernDescription ?? this.concernDescription,
      direction: direction ?? this.direction,
      objects: objects ?? this.objects,
      imageQuality: imageQuality ?? this.imageQuality,
      uncertainty: uncertainty ?? this.uncertainty,
    );
  }

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'answer': answer,
    'possibleConcern': possibleConcern,
    'concernDescription': concernDescription,
    'direction': direction.toJson(),
    'objects': objects,
    'imageQuality': imageQuality.toJson(),
    'uncertainty': uncertainty,
  };
}
