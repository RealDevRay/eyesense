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

/// Local intent router. This does not call a model.
///
/// Matching is exact on the token list after punctuation and filler are
/// removed, so "stop sign", "bread" and "textile" are not commands.
class ConversationAgent {
  final DiagnosticLogService logService;
  final List<ConversationTurn> _shortContext = [];

  ConversationAgent({
    required this.logService,
  });

  static const _fillers = {
    'please',
    'the',
    'a',
    'an',
    'um',
    'uh',
    'er',
    'hey',
    'ok',
    'okay',
    'tafadhali',
    'just',
  };

  static const _prefixes = <List<String>>[
    ['can', 'you'],
    ['could', 'you'],
    ['would', 'you'],
    ['will', 'you'],
  ];

  static const _phrases = <String, List<List<String>>>{
    'stop': [
      ['stop'],
      ['stop', 'now'],
      ['acha'],
      ['nyamaza'],
      ['simama'],
    ],
    'repeat': [
      ['repeat'],
      ['repeat', 'that'],
      ['repeat', 'last'],
      ['say', 'again'],
      ['rudia'],
      ['rudia', 'tena'],
      ['sema', 'tena'],
    ],
    'describe_scene': [
      ['describe'],
      ['describe', 'scene'],
      ['describe', 'this'],
      ['what', 'is', 'this'],
      ['what', 'is', 'that'],
      ['tazama'],
      ['eleza'],
      ['eleza', 'mandhari'],
      ['nini', 'hii'],
      ['nini', 'hiki'],
      ['nini', 'kile'],
    ],
    'read_text': [
      ['read'],
      ['read', 'text'],
      ['read', 'this'],
      ['read', 'this', 'label'],
      ['read', 'label'],
      ['read', 'page'],
      ['soma'],
      ['soma', 'maandishi'],
      ['soma', 'hii'],
      ['soma', 'lebo'],
      ['soma', 'hii', 'lebo'],
    ],
  };

  static const _questionTokens = {
    'where',
    'how',
    'which',
    'when',
    'why',
    'who',
    'what',
    'wapi',
    'vipi',
    'lini',
    'nani',
    'je',
  };

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

  /// Returns `stop`, `repeat`, `describe_scene`, `read_text`, `ask_scene`, or `clarify`.
  Future<String> resolveIntent({
    required AgentTask task,
    required String input,
    required String language,
  }) async {
    final intent = matchIntent(input);
    await logService.logEvent(
      requestId: task.requestId,
      agent: 'conversation',
      providerMode: task.providerMode.name,
      event: 'intent_resolved',
      outcome: intent,
    );
    return intent;
  }

  static String matchIntent(String input) {
    final original = input.toLowerCase().trim();
    final tokens = _tokens(original);
    if (tokens.isEmpty) return 'clarify';

    final matches = <String>[];
    for (final entry in _phrases.entries) {
      for (final phrase in entry.value) {
        if (_sameTokens(tokens, phrase)) {
          matches.add(entry.key);
          break;
        }
      }
    }
    if (matches.length == 1) return matches.single;
    if (matches.length > 1) return 'clarify';

    final asks = original.contains('?') || tokens.any(_questionTokens.contains);
    if (asks) return 'ask_scene';
    return 'clarify';
  }

  static List<String> _tokens(String input) {
    var cleaned = input
        .replaceAll('’', "'")
        .replaceAll("what's", 'what is')
        .replaceAll('whats', 'what is');
    cleaned = cleaned.replaceAll(RegExp(r"[^a-z0-9\s']"), ' ');
    final raw = cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final withoutPrefix = _stripPrefix(raw);
    return withoutPrefix.where((token) => !_fillers.contains(token)).toList();
  }

  static List<String> _stripPrefix(List<String> tokens) {
    var remaining = List<String>.from(tokens);
    var changed = true;
    while (changed && remaining.isNotEmpty) {
      changed = false;
      for (final prefix in _prefixes) {
        if (remaining.length >= prefix.length &&
            _sameTokens(remaining.sublist(0, prefix.length), prefix)) {
          remaining = remaining.sublist(prefix.length);
          changed = true;
          break;
        }
      }
    }
    return remaining;
  }

  static bool _sameTokens(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
