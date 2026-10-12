import 'package:eyesense/models/app_operation.dart';

enum AgentRole {
  scene,
  reading,
  conversation,
}

class AgentTask {
  final String requestId;
  final int generation;
  final AgentRole role;
  final ProviderMode providerMode;
  final Duration timeout;
  final int maxCalls;
  final DateTime captureTimestamp;
  int executedCalls;

  AgentTask({
    required this.requestId,
    required this.generation,
    required this.role,
    required this.providerMode,
    this.timeout = const Duration(seconds: 15),
    this.maxCalls = 2,
    DateTime? captureTimestamp,
    this.executedCalls = 0,
  }) : captureTimestamp = captureTimestamp ?? DateTime.now();

  bool get canExecuteMoreCalls => executedCalls < maxCalls;

  void recordCall() {
    executedCalls++;
  }

  Duration get remainingTimeBudget {
    final elapsed = DateTime.now().difference(captureTimestamp);
    final remaining = timeout - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
