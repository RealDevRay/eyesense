import 'package:eyesense/core/theme/app_theme.dart';
import 'package:eyesense/services/diagnostic_log_service.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:flutter/material.dart';

class DiagnosticsScreen extends StatefulWidget {
  final PreferencesService preferencesService;
  final DiagnosticLogService logService;

  const DiagnosticsScreen({
    super.key,
    required this.preferencesService,
    required this.logService,
  });

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  late bool _loggingEnabled;
  int _totalLogBytes = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loggingEnabled = widget.preferencesService.diagnosticLoggingEnabled;
    _refreshLogSize();
  }

  Future<void> _refreshLogSize() async {
    final bytes = await widget.logService.getTotalLogSize();
    if (mounted) {
      setState(() {
        _totalLogBytes = bytes;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLogging(bool val) async {
    await widget.preferencesService.setDiagnosticLoggingEnabled(val);
    setState(() {
      _loggingEnabled = val;
    });
  }

  Future<void> _clearLogs() async {
    await widget.logService.clearLogs();
    await _refreshLogSize();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All diagnostic logs cleared.')),
      );
    }
  }

  Future<void> _exportLogs() async {
    final success = await widget.logService.exportLogs();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No diagnostic logs available to export.')),
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              activeColor: AppTheme.tealAccent,
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Diagnostic Logging', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              subtitle: const Text('Records technical event metadata locally to assist debugging. Disabled by default.'),
              value: _loggingEnabled,
              onChanged: _toggleLogging,
            ),
            const Divider(height: 32),
            Text(
              'Privacy Protection Notice',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.tealLight),
            ),
            const SizedBox(height: 6),
            const Text(
              'Diagnostic files contain strictly technical event metrics (operation durations, error codes, and token counts). Camera images, recognized text, voice questions, and credentials are NEVER written to logs.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Retained Log Size:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                _isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_formatBytes(_totalLogBytes), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.tealAccent,
                      foregroundColor: AppTheme.backgroundNavy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.share, size: 20),
                    label: const Text('Export Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: _totalLogBytes > 0 ? _exportLogs : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
                      side: const BorderSide(color: AppTheme.errorRed),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: const Text('Clear Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: _totalLogBytes > 0 ? _clearLogs : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
