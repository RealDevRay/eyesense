import 'dart:io';

import 'package:eyesense/services/diagnostic_log_service.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rotation never deletes the only current log, and clear reports failure', () async {
    SharedPreferences.setMockInitialValues({'diagnostic_logging_enabled': true});
    final prefs = await PreferencesService.create();
    final dir = await Directory.systemTemp.createTemp('eyesense-logs');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final logs = DiagnosticLogService(prefs, directory: dir);
    await logs.logEvent(
      requestId: 'req-1',
      agent: 'scene',
      providerMode: 'hosted',
      event: 'agent_started',
    );
    final files = dir.listSync().whereType<File>().toList();
    expect(files, hasLength(1));
    await files.single.writeAsString('x' * (5 * 1024 * 1024 + 32), mode: FileMode.append);
    await logs.logEvent(
      requestId: 'req-2',
      agent: 'scene',
      providerMode: 'hosted',
      event: 'agent_finished',
    );
    expect(await files.single.exists(), isTrue);
    expect(await files.single.length(), greaterThan(5 * 1024 * 1024));

    final blocker = File('${dir.path}-not-a-directory');
    await blocker.writeAsString('x');
    addTearDown(() async {
      if (await blocker.exists()) await blocker.delete();
    });
    final failing = DiagnosticLogService(prefs, directory: Directory(blocker.path));
    expect(await failing.clearLogs(), isFalse);
  });
}
