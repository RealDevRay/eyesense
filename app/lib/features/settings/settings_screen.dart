import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/features/diagnostics/diagnostics_screen.dart';
import 'package:eyesense/features/onboarding/onboarding_screen.dart';
import 'package:eyesense/features/settings/ai_connection_screen.dart';
import 'package:eyesense/services/credential_service.dart';
import 'package:eyesense/services/diagnostic_log_service.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final PreferencesService preferencesService;
  final CredentialService credentialService;
  final DiagnosticLogService logService;
  final AgentCoordinator coordinator;

  const SettingsScreen({
    super.key,
    required this.preferencesService,
    required this.credentialService,
    required this.logService,
    required this.coordinator,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _speechRate;
  late String _language;
  late bool _haptics;
  late bool _autoRead;
  late bool _cloudConsent;
  late String _themeMode;

  @override
  void initState() {
    super.initState();
    _speechRate = widget.preferencesService.speechRate;
    _language = widget.preferencesService.language;
    _haptics = widget.preferencesService.hapticsEnabled;
    _autoRead = widget.preferencesService.autoRead;
    _cloudConsent = widget.preferencesService.cloudConsentGranted;
    _themeMode = widget.preferencesService.themeModeString;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Theme Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            subtitle: const Text('System default, high-contrast dark, or light'),
            trailing: DropdownButton<String>(
              dropdownColor: Theme.of(context).colorScheme.surface,
              value: _themeMode,
              items: const [
                DropdownMenuItem(value: 'system', child: Text('System')),
                DropdownMenuItem(value: 'dark', child: Text('Dark Navy')),
                DropdownMenuItem(value: 'light', child: Text('Light Teal')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _themeMode = val);
                  widget.preferencesService.setThemeModeString(val);
                }
              },
            ),
          ),
          const Divider(height: 32),

          Text('Speech & Audio', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text('Speech Rate: ${_speechRate.toStringAsFixed(1)}x', style: const TextStyle(fontSize: 16)),
          Slider(
            value: _speechRate,
            min: 0.5,
            max: 2.0,
            divisions: 6,
            onChanged: (val) {
              setState(() => _speechRate = val);
              widget.preferencesService.setSpeechRate(val);
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Language', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            subtitle: const Text('Spoken language and response translations'),
            trailing: DropdownButton<String>(
              dropdownColor: Theme.of(context).colorScheme.surface,
              value: _language,
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English (Default)')),
                DropdownMenuItem(value: 'sw', child: Text('Kiswahili')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _language = val);
                  widget.preferencesService.setLanguage(val);
                }
              },
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Automatic Spoken Reading', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            subtitle: const Text('Automatically speak new visual results aloud via TTS'),
            value: _autoRead,
            onChanged: (val) {
              setState(() => _autoRead = val);
              widget.preferencesService.setAutoRead(val);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Haptic Vibration Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            subtitle: const Text('Vibrate phone on confirmation and potential concerns'),
            value: _haptics,
            onChanged: (val) {
              setState(() => _haptics = val);
              widget.preferencesService.setHapticsEnabled(val);
            },
          ),
          const Divider(height: 36),

          Text('Privacy & Cloud Processing', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cloud Processing Consent', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            subtitle: const Text('Allow sending single snapshots and questions to your configured AI provider. Read Text operates offline without consent.'),
            value: _cloudConsent,
            onChanged: (val) {
              setState(() => _cloudConsent = val);
              widget.preferencesService.setCloudConsentGranted(val);
            },
          ),
          const Divider(height: 36),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.cloud_outlined, color: Theme.of(context).colorScheme.primary, size: 28),
            title: const Text('AI Connection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            subtitle: const Text('Configure EyeSense service or Bring Your Own Groq Key'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AiConnectionScreen(
                    preferencesService: widget.preferencesService,
                    credentialService: widget.credentialService,
                    coordinator: widget.coordinator,
                  ),
                ),
              );
              if (mounted) {
                widget.coordinator.refreshVisionProvider();
              }
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.analytics_outlined, color: Theme.of(context).colorScheme.primary, size: 28),
            title: const Text('Diagnostics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            subtitle: const Text('Manage technical event logging, view file size, and export'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DiagnosticsScreen(
                    preferencesService: widget.preferencesService,
                    logService: widget.logService,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.primary, size: 28),
            title: const Text('Tutorial & Practice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            subtitle: const Text('Replay the introductory onboarding walkthrough'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => OnboardingScreen(
                    coordinator: widget.coordinator,
                    onFinish: () => Navigator.of(ctx).pop(),
                  ),
                ),
              );
              if (mounted) {
                setState(() {
                  _speechRate = widget.preferencesService.speechRate;
                  _language = widget.preferencesService.language;
                  _haptics = widget.preferencesService.hapticsEnabled;
                  _autoRead = widget.preferencesService.autoRead;
                  _cloudConsent = widget.preferencesService.cloudConsentGranted;
                  _themeMode = widget.preferencesService.themeModeString;
                });
                widget.coordinator.refreshVisionProvider();
              }
            },
          ),
        ],
      ),
    );
  }
}
