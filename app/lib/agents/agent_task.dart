import 'package:eyesense/core/config/app_config.dart';
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
  final Stopwatch _elapsedClock;
  final Duration Function()? elapsedOverride;
  int executedCalls;

  AgentTask({
    required this.requestId,
    required this.generation,
    required this.role,
    required this.providerMode,
    Duration? timeout,
    int? maxCalls,
    DateTime? captureTimestamp,
    this.executedCalls = 0,
    Stopwatch? elapsedClock,
    this.elapsedOverride,
  })  : timeout = timeout ?? AppConfig.clientTimeout,
        maxCalls = maxCalls ?? AppConfig.maxModelCallsPerOperation,
        captureTimestamp = captureTimestamp ?? DateTime.now(),
        _elapsedClock = elapsedClock ?? (Stopwatch()..start());

  bool get canExecuteMoreCalls => executedCalls < maxCalls;

  void recordCall() {
    executedCalls++;
  }

  /// Monotonic time since the task started. Wall-clock jumps do not shrink
  /// or extend the request deadline. Tests inject [elapsedOverride].
  Duration get elapsed => elapsedOverride?.call() ?? _elapsedClock.elapsed;

  Duration get remainingTimeBudget {
    final remaining = timeout - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
