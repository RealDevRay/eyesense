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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              activeColor: colorScheme.primary,
              contentPadding: EdgeInsets.zero,
              title: Text('Enable Diagnostic Logging', style: theme.textTheme.titleMedium),
              subtitle: const Text('Records technical event metadata locally to assist debugging. Disabled by default.'),
              value: _loggingEnabled,
              onChanged: _toggleLogging,
            ),
            const Divider(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF132240) : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, color: colorScheme.primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Privacy Protection Notice',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Diagnostic files contain strictly technical event metrics (operation durations, error codes, and token counts). Camera images, recognized text, voice questions, and credentials are NEVER written to logs.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Retained Log Size:', style: theme.textTheme.titleSmall),
                _isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      )
                    : Text(
                        _formatBytes(_totalLogBytes),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    minimumSize: const Size(140, AppTheme.minTouchTarget),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.share, size: 20),
                  label: const Text('Export Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: _totalLogBytes > 0 ? _exportLogs : null,
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error),
                    minimumSize: const Size(140, AppTheme.minTouchTarget),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('Clear Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: _totalLogBytes > 0 ? _clearLogs : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
