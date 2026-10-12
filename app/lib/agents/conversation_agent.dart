import 'package:eyesense/agents/agent_task.dart';
import 'package:eyesense/services/diagnostic_log_service.dart';

class ConversationTurn {
  final String userMessage;
  final String agentResponse;
  final DateTime timestamp;

  ConversationTurn({
    required this.userMessage,
    required this.agentResponse,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp) > const Duration(seconds: 60);
}

class ConversationAgent {
  final DiagnosticLogService logService;
  final List<ConversationTurn> _shortContext = [];

  ConversationAgent({
    required this.logService,
  });

  void addTurn(String userMessage, String agentResponse) {
    _shortContext.removeWhere((t) => t.isExpired);
    if (_shortContext.length >= 2) {
      _shortContext.removeAt(0);
    }
    _shortContext.add(ConversationTurn(
      userMessage: userMessage,
      agentResponse: agentResponse,
    ));
  }

  void clearContext() {
    _shortContext.clear();
  }

  /// Determines plan for user command or voice input
  Future<String> resolveIntent({
    required AgentTask task,
    required String input,
    required String language,
  }) async {
    task.recordCall();
    await logService.logEvent(
      requestId: task.requestId,
      agent: 'conversation',
      providerMode: task.providerMode.name,
      event: 'agent_started',
    );

    final clean = input.toLowerCase().trim();
    if (clean.contains('describe') || clean.contains('what is this') || clean.contains('tazama')) {
      return 'describe_scene';
    }
    if (clean.contains('read') || clean.contains('soma') || clean.contains('text')) {
      return 'read_text';
    }
    if (clean.contains('where') || clean.contains('how') || clean.contains('wapi') || clean.contains('?')) {
      return 'ask_scene';
    }

    return 'clarify';
  }
}
