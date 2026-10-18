import 'package:eyesense/agents/agent_task.dart';
import 'package:eyesense/models/app_operation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AgentTask task({Duration Function()? elapsed, int calls = 0}) {
    return AgentTask(
      requestId: 'req',
      generation: 1,
      role: AgentRole.scene,
      providerMode: ProviderMode.hosted,
      timeout: const Duration(seconds: 10),
      maxCalls: 2,
      executedCalls: calls,
      elapsedOverride: elapsed,
    );
  }

  test('refuses another call once the budget is spent', () {
    final spent = task(calls: 2);
    expect(spent.canExecuteMoreCalls, isFalse);
  });

  test('remaining time follows the injected monotonic clock', () {
    final fresh = task(elapsed: () => Duration.zero);
    expect(fresh.remainingTimeBudget, const Duration(seconds: 10));

    final late = task(elapsed: () => const Duration(seconds: 10));
    expect(late.remainingTimeBudget, Duration.zero);
    expect(late.canExecuteMoreCalls, isTrue);
  });
}
