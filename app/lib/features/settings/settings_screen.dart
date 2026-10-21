import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/core/config/app_config.dart';
import 'package:eyesense/core/speech/speech_rate.dart';
import 'package:eyesense/features/diagnostics/diagnostics_screen.dart';
import 'package:eyesense/features/legal/legal_document_screen.dart';
import 'package:eyesense/features/onboarding/onboarding_screen.dart';
import 'package:eyesense/features/settings/ai_connection_screen.dart';
import 'package:eyesense/features/settings/device_support_screen.dart';
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
    _assignFromService();
    widget.preferencesService.addListener(_syncFromService);
  }

  void _assignFromService() {
    _speechRate = widget.preferencesService.speechRate;
    _language = widget.preferencesService.language;
    _haptics = widget.preferencesService.hapticsEnabled;
    _autoRead = widget.preferencesService.autoRead;
    _cloudConsent = widget.preferencesService.cloudConsentGranted;
    _themeMode = widget.preferencesService.themeModeString;
  }

  @override
  void dispose() {
    widget.preferencesService.removeListener(_syncFromService);
    super.dispose();
  }

  void _syncFromService() {
    if (!mounted) return;
    setState(_assignFromService);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const Text(
            'Theme Mode',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Text('System, dark, light, or maximum contrast'),
          DropdownButton<String>(
            isExpanded: true,
            dropdownColor: Theme.of(context).colorScheme.surface,
            value: _themeMode,
            items: const [
              DropdownMenuItem(value: 'system', child: Text('System')),
              DropdownMenuItem(value: 'dark', child: Text('Dark')),
              DropdownMenuItem(value: 'light', child: Text('Light')),
              DropdownMenuItem(
                value: 'contrast',
                child: Text('Maximum contrast'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _themeMode = val);
                widget.preferencesService.setThemeModeString(val);
              }
            },
          ),
          const Divider(height: 32),

          Text(
            'How you use EyeSense',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Choosing a profile resets its starting preferences. All profiles start with spoken results, including when a sighted person helps. You can change each option afterwards.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          RadioGroup<AssistanceProfile>(
            groupValue: widget.preferencesService.assistanceProfile,
            onChanged: (value) {
              if (value == null) return;
              widget.preferencesService.applyProfileDefaults(value);
            },
            child: const Column(
              children: [
                RadioListTile<AssistanceProfile>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('I use a screen reader'),
                  value: AssistanceProfile.screenReader,
                ),
                RadioListTile<AssistanceProfile>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('I have some usable vision'),
                  value: AssistanceProfile.lowVision,
                ),
                RadioListTile<AssistanceProfile>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('I am sighted and assisting someone'),
                  value: AssistanceProfile.sightedAssistant,
                ),
              ],
            ),
          ),
          const Divider(height: 32),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.sensors),
            title: const Text('Phone & capture guidance'),
            subtitle: const Text(
              'Optional motion and lighting cues, available sensors, and a local sensor check',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    DeviceSupportScreen(coordinator: widget.coordinator),
              ),
            ),
          ),
          const Divider(height: 32),
          Text('Speech & Audio', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text('Speech rate: ${SpeechRateScale.labelFor(_speechRate)}'),
          Slider(
            value: _speechRate,
            min: SpeechRateScale.minProduct,
            max: SpeechRateScale.maxProduct,
            divisions: SpeechRateScale.divisions,
            label: SpeechRateScale.labelFor(_speechRate),
            semanticFormatterCallback: SpeechRateScale.labelFor,
            onChanged: (val) {
              widget.preferencesService.setSpeechRate(val);
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () => widget.coordinator.ttsService.speak(
                'This is EyeSense at the selected speaking rate.',
              ),
              child: const Text('Preview voice'),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Language',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Text('Spoken language and response translations'),
          DropdownButton<String>(
            isExpanded: true,
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Automatic Spoken Reading',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Automatically speak new visual results aloud via TTS',
            ),
            value: _autoRead,
            onChanged: (val) {
              setState(() => _autoRead = val);
              widget.preferencesService.setAutoRead(val);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Haptic Vibration Feedback',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Vibrate phone on confirmation and potential concerns',
            ),
            value: _haptics,
            onChanged: (val) {
              setState(() => _haptics = val);
              widget.preferencesService.setHapticsEnabled(val);
            },
          ),
          const Divider(height: 36),

          Text(
            'Privacy & Cloud Processing',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (widget.preferencesService.acceptedTermsVersion != null &&
              widget.preferencesService.acceptedTermsVersion !=
                  AppConfig.termsVersion)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Privacy notice updated for the pilot. Previous cloud consent is off. Review Privacy and Terms below before enabling cloud processing again.',
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Cloud Processing Consent',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Allow sending single snapshots and questions to your configured AI provider. Read Text OCR stays on your phone; system speech may need internet.',
            ),
            value: _cloudConsent,
            onChanged: (val) {
              setState(() => _cloudConsent = val);
              widget.preferencesService.setCloudConsentGranted(val);
            },
          ),
          const Divider(height: 36),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.cloud_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            title: const Text(
              'AI Connection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'EyeSense service, Groq, Mistral, OpenAI or Google Gemini',
            ),
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
            leading: Icon(
              Icons.analytics_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            title: const Text(
              'Diagnostics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Manage technical event logging, view file size, and export',
            ),
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
          const SizedBox(height: 24),
          Text('Legal', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'EyeSense is a supplementary visual assistant. It is not a medical device, not a mobility aid, and not a navigation aid.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Privacy Policy'),
            subtitle: Text(
              'Version ${AppConfig.termsVersion}. Accepted: ${widget.preferencesService.acceptedTermsVersion ?? 'not yet'}',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LegalDocumentScreen(
                  title: 'Privacy Policy',
                  documentBase: 'assets/legal/privacy-policy',
                  language: _language,
                ),
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Terms of Use'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LegalDocumentScreen(
                  title: 'Terms of Use',
                  documentBase: 'assets/legal/terms-of-service',
                  language: _language,
                ),
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Open-source licences'),
            subtitle: Text('Version ${AppConfig.appVersionLabel}'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'EyeSense',
              applicationVersion: AppConfig.appVersionLabel,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.help_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            title: const Text(
              'Tutorial & Practice',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Replay the introductory onboarding walkthrough',
            ),
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
