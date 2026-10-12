import 'package:eyesense/core/theme/app_theme.dart';
import 'package:eyesense/models/app_operation.dart';
import 'package:eyesense/services/credential_service.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:flutter/material.dart';

class AiConnectionScreen extends StatefulWidget {
  final PreferencesService preferencesService;
  final CredentialService credentialService;

  const AiConnectionScreen({
    super.key,
    required this.preferencesService,
    required this.credentialService,
  });

  @override
  State<AiConnectionScreen> createState() => _AiConnectionScreenState();
}

class _AiConnectionScreenState extends State<AiConnectionScreen> {
  late ProviderMode _selectedMode;
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _demoTokenController = TextEditingController();
  final TextEditingController _workerUrlController = TextEditingController();
  bool _isTestingKey = false;
  String? _testStatusMessage;
  bool? _testSuccess;

  bool _isTestingWorker = false;
  String? _workerTestStatusMessage;
  bool? _workerTestSuccess;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.preferencesService.providerMode;
    _workerUrlController.text = widget.preferencesService.apiBaseUrl;
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final key = await widget.credentialService.getUserGroqApiKey();
    final token = await widget.credentialService.getDemoAccessToken();
    if (mounted) {
      setState(() {
        if (key != null) _apiKeyController.text = key;
        if (token != null) _demoTokenController.text = token;
      });
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _demoTokenController.dispose();
    _workerUrlController.dispose();
    super.dispose();
  }

  Future<void> _testPersonalKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _testStatusMessage = 'Please enter a Groq API key first.';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _isTestingKey = true;
      _testStatusMessage = 'Testing connection with Groq...';
      _testSuccess = null;
    });

    final success = await widget.credentialService.testGroqApiKey(key);
    if (mounted) {
      setState(() {
        _isTestingKey = false;
        _testSuccess = success;
        _testStatusMessage = success
            ? 'Success: Authenticated with Groq.'
            : 'Error: Key was rejected or network error.';
      });
    }
  }

  Future<void> _testWorker() async {
    final url = _workerUrlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _workerTestStatusMessage = 'Please enter a Worker URL first.';
        _workerTestSuccess = false;
      });
      return;
    }

    setState(() {
      _isTestingWorker = true;
      _workerTestStatusMessage = 'Pinging Cloudflare Worker health endpoint...';
      _workerTestSuccess = null;
    });

    final success = await widget.credentialService.testWorkerHealth(url);
    if (mounted) {
      setState(() {
        _isTestingWorker = false;
        _workerTestSuccess = success;
        _workerTestStatusMessage = success
            ? 'Success: Cloudflare Worker responded healthy.'
            : 'Error: Unable to connect to Worker or invalid response.';
      });
    }
  }

  Future<void> _saveSettings() async {
    await widget.preferencesService.setProviderMode(_selectedMode);
    if (_workerUrlController.text.trim().isNotEmpty) {
      await widget.preferencesService.setApiBaseUrl(_workerUrlController.text.trim());
    }
    if (_selectedMode == ProviderMode.byok) {
      if (_apiKeyController.text.trim().isNotEmpty) {
        await widget.credentialService.setUserGroqApiKey(_apiKeyController.text.trim());
      }
    } else {
      if (_demoTokenController.text.trim().isNotEmpty) {
        await widget.credentialService.setDemoAccessToken(_demoTokenController.text.trim());
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI connection settings saved.')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _clearKey() async {
    await widget.credentialService.clearUserGroqApiKey();
    _apiKeyController.clear();
    setState(() {
      _testStatusMessage = 'API key removed from secure storage.';
      _testSuccess = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Connection'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Connection Mode',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            RadioListTile<ProviderMode>(
              activeColor: AppTheme.tealAccent,
              title: const Text('EyeSense service (Hosted prototype)'),
              subtitle: const Text('Connects through the secure EyeSense Worker proxy.'),
              value: ProviderMode.hosted,
              groupValue: _selectedMode,
              onChanged: (val) {
                if (val != null) setState(() => _selectedMode = val);
              },
            ),
            RadioListTile<ProviderMode>(
              activeColor: AppTheme.tealAccent,
              title: const Text('Use my Groq key (BYOK mode)'),
              subtitle: const Text('Direct device-to-Groq connection using your own account.'),
              value: ProviderMode.byok,
              groupValue: _selectedMode,
              onChanged: (val) {
                if (val != null) setState(() => _selectedMode = val);
              },
            ),
            const SizedBox(height: 24),
            if (_selectedMode == ProviderMode.byok) ...[
              Text(
                'Personal Groq API Key',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _apiKeyController,
                obscureText: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Groq API Key (gsk_...)',
                  hintText: 'Enter your key',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.tealAccent,
                      foregroundColor: AppTheme.backgroundNavy,
                    ),
                    icon: _isTestingKey
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.backgroundNavy),
                          )
                        : const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text('Test Key'),
                    onPressed: _isTestingKey ? null : _testPersonalKey,
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorRed),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: const Text('Remove'),
                    onPressed: _clearKey,
                  ),
                ],
              ),
              if (_testStatusMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _testStatusMessage!,
                  style: TextStyle(
                    color: _testSuccess == true
                        ? AppTheme.tealLight
                        : _testSuccess == false
                            ? AppTheme.errorRed
                            : AppTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ] else ...[
              Text(
                'Cloudflare Worker API URL',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _workerUrlController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Worker Base URL',
                  hintText: 'https://eyesense-api.<subdomain>.workers.dev',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.tealAccent,
                      foregroundColor: AppTheme.backgroundNavy,
                    ),
                    icon: _isTestingWorker
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.backgroundNavy),
                          )
                        : const Icon(Icons.cloud_done_outlined, size: 20),
                    label: const Text('Test Worker Connection'),
                    onPressed: _isTestingWorker ? null : _testWorker,
                  ),
                ],
              ),
              if (_workerTestStatusMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _workerTestStatusMessage!,
                  style: TextStyle(
                    color: _workerTestSuccess == true
                        ? AppTheme.tealLight
                        : _workerTestSuccess == false
                            ? AppTheme.errorRed
                            : AppTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Prototype Demo Token',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _demoTokenController,
                obscureText: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Demo Access Token',
                  hintText: 'Enter prototype bearer token',
                ),
              ),
            ],
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: AppTheme.primaryButtonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tealAccent,
                  foregroundColor: AppTheme.backgroundNavy,
                ),
                onPressed: _saveSettings,
                child: const Text('Save Connection Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
