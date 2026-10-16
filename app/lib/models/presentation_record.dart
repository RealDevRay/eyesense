enum TaskKind {
  describe,
  readText,
  askQuestion,
}

enum PresentationStatus {
  current,
  previous,
}

class PresentationRecord {
  final TaskKind kind;
  final DateTime timestamp;
  final String responseText;
  final bool possibleConcern;
  final String? concernDescription;
  final String? uncertainty;
  final PresentationStatus status;

  const PresentationRecord({
    required this.kind,
    required this.timestamp,
    required this.responseText,
    this.possibleConcern = false,
    this.concernDescription,
    this.uncertainty,
    this.status = PresentationStatus.current,
  });

  /// Formats the single source of truth spoken representation.
  String toSpokenText() {
    final buffer = StringBuffer();
    if (status == PresentationStatus.previous) {
      buffer.write('Previous result: ');
    }
    if (possibleConcern && concernDescription != null && concernDescription!.trim().isNotEmpty) {
      buffer.write('Notice: ${concernDescription!.trim()}. ');
    }
    buffer.write(responseText.trim());
    if (uncertainty != null && uncertainty!.trim().isNotEmpty) {
      buffer.write(' Note: ${uncertainty!.trim()}');
    }
    return buffer.toString();
  }

  /// Copies this record labelled as previous.
  PresentationRecord asPrevious() {
    return PresentationRecord(
      kind: kind,
      timestamp: timestamp,
      responseText: responseText,
      possibleConcern: possibleConcern,
      concernDescription: concernDescription,
      uncertainty: uncertainty,
      status: PresentationStatus.previous,
    );
  }
}
