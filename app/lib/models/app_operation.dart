enum OperationState {
  idle,
  listening,
  capturing,
  processingLocal,
  processingCloud,
  speaking,
  error;

  String get localizedAnnouncement {
    switch (this) {
      case OperationState.idle:
        return 'Ready';
      case OperationState.listening:
        return 'Listening';
      case OperationState.capturing:
        return 'Taking a picture';
      case OperationState.processingLocal:
        return 'Reading';
      case OperationState.processingCloud:
        return 'Describing';
      case OperationState.speaking:
        return 'Speaking';
      case OperationState.error:
        return 'Error occurred';
    }
  }
}

enum AppMode {
  describe,
  readText,
  ask,
  awareness;

  String get displayName {
    switch (this) {
      case AppMode.describe:
        return 'Describe';
      case AppMode.readText:
        return 'Read Text';
      case AppMode.ask:
        return 'Ask';
      case AppMode.awareness:
        return 'Awareness (Experimental)';
    }
  }
}

enum ProviderMode {
  hosted,
  byok;

  String get displayName {
    switch (this) {
      case ProviderMode.hosted:
        return 'EyeSense service';
      case ProviderMode.byok:
        return 'Use my own AI provider';
    }
  }
}

class OperationToken {
  final String requestId;
  final int generation;
  final DateTime createdAt;

  OperationToken({
    required this.requestId,
    required this.generation,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool isStale(Duration freshnessLimit) {
    return DateTime.now().difference(createdAt) > freshnessLimit;
  }
}
