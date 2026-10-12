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
      default:
        return SceneDirection.unknown;
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
    if (val.toLowerCase().trim() == 'unclear') {
      return ImageQuality.unclear;
    }
    return ImageQuality.usable;
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
    final rawSummary = json['summary'] as String? ?? '';
    final rawAnswer = json['answer'] as String?;
    final rawConcern = json['possibleConcern'] as bool? ?? false;
    final rawConcernDesc = json['concernDescription'] as String?;
    final rawDirection = json['direction'] as String? ?? 'unknown';
    final rawQuality = json['imageQuality'] as String? ?? 'usable';
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

    return SceneResult(
      summary: rawSummary.length > 350 ? rawSummary.substring(0, 350) : rawSummary,
      answer: rawAnswer != null && rawAnswer.length > 350 ? rawAnswer.substring(0, 350) : rawAnswer,
      possibleConcern: rawConcern,
      concernDescription: rawConcernDesc != null && rawConcernDesc.length > 250
          ? rawConcernDesc.substring(0, 250)
          : rawConcernDesc,
      direction: SceneDirection.fromString(rawDirection),
      objects: parsedObjects.take(8).toList(),
      imageQuality: ImageQuality.fromString(rawQuality),
      uncertainty: rawUncertainty != null && rawUncertainty.length > 250
          ? rawUncertainty.substring(0, 250)
          : rawUncertainty,
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
