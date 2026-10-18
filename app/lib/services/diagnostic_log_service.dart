// ignore_for_file: use_null_aware_elements
import 'dart:convert';
import 'dart:io';
import 'package:eyesense/services/preferences_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DiagnosticLogService {
  final PreferencesService _prefs;
  Directory? _logDir;

  DiagnosticLogService(this._prefs, {Directory? directory}) : _logDir = directory;

  Future<Directory> _getLogDirectory() async {
    if (_logDir != null) return _logDir!;
    final baseDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(baseDir.path, 'diagnostics'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _logDir = dir;
    return dir;
  }

  String _getTodayFileName() {
    final now = DateTime.now().toUtc();
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return 'eyesense-$yyyy-$mm-$dd-001.jsonl';
  }

  Future<void> logEvent({
    required String requestId,
    required String agent,
    required String providerMode,
    required String event,
    int? durationMs,
    String? outcome,
    int? inputTokens,
    int? outputTokens,
    String? errorCode,
  }) async {
    // Only record if user explicitly opted in
    if (!_prefs.diagnosticLoggingEnabled) return;

    try {
      final dir = await _getLogDirectory();
      final file = File(p.join(dir.path, _getTodayFileName()));

      final logData = {
        'schemaVersion': 1,
        'timestampUtc': DateTime.now().toUtc().toIso8601String(),
        'requestId': requestId,
        'agent': agent,
        'providerMode': providerMode,
        'event': event,
        if (durationMs != null) 'durationMs': durationMs,
        if (outcome != null) 'outcome': outcome,
        if (inputTokens != null) 'inputTokens': inputTokens,
        if (outputTokens != null) 'outputTokens': outputTokens,
        if (errorCode != null) 'errorCode': errorCode,
      };

      await file.writeAsString('${jsonEncode(logData)}\n', mode: FileMode.append, flush: true);
      await _enforceRotation();
    } catch (_) {
      // Diagnostic logging failure must never disrupt assistance
    }
  }

  Future<void> _enforceRotation() async {
    try {
      final dir = await _getLogDirectory();
      final files = await dir.list().where((f) => f is File && f.path.endsWith('.jsonl')).toList();

      int totalBytes = 0;
      final fileList = <File>[];
      for (final f in files) {
        if (f is File) {
          totalBytes += await f.length();
          fileList.add(f);
        }
      }

      // If total exceeds 5 MiB or older than 7 days, delete oldest
      fileList.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
      // A single current file is never deleted, even when it alone exceeds the ceiling.
      if (fileList.length <= 1) return;

      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      final newest = fileList.last;

      for (final f in fileList) {
        if (identical(f, newest)) continue;
        final agedOut = f.lastModifiedSync().isBefore(cutoff);
        final overCeiling = totalBytes > 5 * 1024 * 1024;
        if (agedOut || overCeiling) {
          final len = await f.length();
          await f.delete();
          totalBytes -= len;
        }
      }
    } catch (_) {}
  }

  Future<int> getTotalLogSize() async {
    try {
      final dir = await _getLogDirectory();
      final files = await dir.list().where((f) => f is File && f.path.endsWith('.jsonl')).toList();
      int total = 0;
      for (final f in files) {
        if (f is File) {
          total += await f.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Returns false when deletion fails so the screen can say so.
  Future<bool> clearLogs() async {
    try {
      final dir = await _getLogDirectory();
      final files = await dir.list().where((f) => f is File && f.path.endsWith('.jsonl')).toList();
      for (final f in files) {
        await f.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> exportLogs() async {
    try {
      final dir = await _getLogDirectory();
      final files = await dir.list().where((f) => f is File && f.path.endsWith('.jsonl')).toList();
      if (files.isEmpty) return false;

      final xFiles = files.map((f) => XFile(f.path)).toList();
      final result = await Share.shareXFiles(
        xFiles,
        subject: 'EyeSense Diagnostic Logs',
        text: 'Exported technical diagnostic metadata (contains no private images or text).',
      );
      return result.status == ShareResultStatus.success;
    } catch (_) {
      return false;
    }
  }
}
