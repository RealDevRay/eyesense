import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/core/config/app_config.dart';
import 'package:eyesense/core/errors/app_exceptions.dart';
import 'package:eyesense/core/theme/app_theme.dart';
import 'package:eyesense/models/app_operation.dart';
import 'package:eyesense/models/direct_ai_provider.dart';
import 'package:eyesense/services/credential_service.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:eyesense/services/providers/openai_compatible_provider.dart';
import 'package:eyesense/services/vision_api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

const _kMistralPilotNotice =
    'Mistral is an optional pilot provider and has not been live tested by EyeSense. '
    'A free / Experiment API key does not guarantee model access or available quota. '
    'Free mode has limited evaluation quotas. Mistral may retain API data and use '
    'inputs and outputs for training unless you opt out in the Mistral Admin '
    'panel under Privacy → Anonymous improvement data. Training opt-out is not '
    'zero-data retention; zero-data retention is not available on free mode. '
    'Review your account limits and data terms before sending images.';

/// Allows tests to exercise the explicit smoke test without a live transport.
typedef DirectProviderFactory = VisionApiService Function({
  required CredentialService credentialService,
  required DirectAiProvider provider,
  required String model,
  required String apiKeyOverride,
});

class AiConnectionScreen extends StatefulWidget {
  final PreferencesService preferencesService;
  final CredentialService credentialService;
  final AgentCoordinator? coordinator;
  final DirectProviderFactory? directProviderFactory;

  const AiConnectionScreen({
    super.key,
    required this.preferencesService,
    required this.credentialService,
    this.coordinator,
    this.directProviderFactory,
  });

  @override
  State<AiConnectionScreen> createState() => _AiConnectionScreenState();
}

class _AiConnectionScreenState extends State<AiConnectionScreen> {
  late ProviderMode _selectedMode;
  late DirectAiProvider _selectedProvider;
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _demoTokenController = TextEditingController();
  final _workerUrlController = TextEditingController();
  final _modelDrafts = <DirectAiProvider, String>{};
  int _credentialGeneration = 0;
  int _testGeneration = 0;
  bool _keyDirty = false;
  bool _demoTokenDirty = false;
  bool _isLoadingKey = true;
  bool _isCheckingKey = false;
  bool _isTestingVision = false;
  bool _isRemovingKey = false;
  bool _isSaving = false;
  String? _modelError;
  String? _testStatusMessage;
  bool? _testSuccess;
  String? _saveStatusMessage;
  CancelToken? _visionCancelToken;

  bool _isTestingWorker = false;
  String? _workerTestStatusMessage;
  bool? _workerTestSuccess;

  bool get _canEdit => !_isSaving && !_isRemovingKey;
  bool get _directTestBusy => _isCheckingKey || _isTestingVision;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.preferencesService.providerMode;
    _selectedProvider = widget.preferencesService.directAiProvider;
    _modelController.text = widget.preferencesService.visionModelFor(
      _selectedProvider,
    );
    _workerUrlController.text = widget.preferencesService.apiBaseUrl;
    _loadProviderKey(_selectedProvider, _credentialGeneration);
    _loadDemoToken();
  }

  Future<void> _loadProviderKey(
    DirectAiProvider provider,
    int generation,
  ) async {
    String? key;
    bool failed = false;
    try {
      key = await widget.credentialService.getProviderApiKey(provider);
    } catch (_) {
      failed = true;
    }
    if (!mounted ||
        generation != _credentialGeneration ||
        provider != _selectedProvider) {
      return;
    }
    setState(() {
      _isLoadingKey = false;
      // A secure-storage read must never replace a key the user has typed.
      if (!_keyDirty) {
        _apiKeyController.text = key ?? '';
        if (failed) {
          _testStatusMessage = 'Could not load the saved key. Enter a key or reopen this screen to try again.';
          _testSuccess = false;
        }
      }
    });
  }

  Future<void> _loadDemoToken() async {
    try {
      final token = await widget.credentialService.getDemoAccessToken();
      if (mounted && !_demoTokenDirty && !_isSaving) {
        setState(() => _demoTokenController.text = token ?? '');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _workerTestStatusMessage = 'Could not load the saved demo token.',
        );
      }
    }
  }

  void _invalidateTests() {
    _testGeneration++;
    _visionCancelToken?.cancel();
    _visionCancelToken = null;
    _testStatusMessage = null;
    _testSuccess = null;
  }

  void _selectProvider(DirectAiProvider provider) {
    if (!_canEdit || provider == _selectedProvider) return;
    setState(() {
      _modelDrafts[_selectedProvider] = _modelController.text;
      _invalidateTests();
      _credentialGeneration++;
      _selectedProvider = provider;
      _apiKeyController.clear();
      _keyDirty = false;
      _isLoadingKey = true;
      _modelError = null;
      _saveStatusMessage = null;
      _modelController.text =
          _modelDrafts[provider] ??
          widget.preferencesService.visionModelFor(provider);
    });
    _loadProviderKey(provider, _credentialGeneration);
  }

  @override
  void dispose() {
    _visionCancelToken?.cancel();
    _apiKeyController.dispose();
    _modelController.dispose();
    _demoTokenController.dispose();
    _workerUrlController.dispose();
    super.dispose();
  }

  String? _validateWorkerUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return 'Worker Base URL cannot be empty.';
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Please enter a valid URL (e.g. https://eyesense-api.example.workers.dev).';
    }
    if (kReleaseMode && uri.scheme != 'https') {
      return 'Release builds require a secure HTTPS URL.';
    }
    if (!kReleaseMode && uri.scheme != 'https' && uri.scheme != 'http') {
      return 'URL scheme must be http or https.';
    }
    return null;
  }

  bool _validateDirectSettings() {
    final model = _modelController.text;
    final error = model.trim().isEmpty
        ? 'Enter a model ID.'
        : RegExp(r'\s').hasMatch(model)
        ? 'Model IDs cannot contain spaces or other whitespace.'
        : model.length > 150
        ? 'Model IDs must be 150 characters or fewer.'
        : null;
    setState(() {
      _modelError = error;
      if (error != null || _apiKeyController.text.trim().isEmpty) {
        _testSuccess = false;
        _testStatusMessage =
            error ??
            'Enter an API key for ${_selectedProvider.displayName}. A blank key will not reuse another provider’s key.';
      }
    });
    return error == null && _apiKeyController.text.trim().isNotEmpty;
  }

  Future<void> _checkKeyAndModel() async {
    if (_directTestBusy || !_validateDirectSettings()) return;
    final generation = ++_testGeneration;
    final provider = _selectedProvider;
    final key = _apiKeyController.text.trim();
    final model = _modelController.text;
    setState(() {
      _isCheckingKey = true;
      _testSuccess = null;
      _testStatusMessage =
          'Checking ${provider.displayName} authentication and model availability. No image is sent.';
    });
    bool success = false;
    try {
      success = await widget.credentialService
          .testProviderModel(provider, key, model)
          .timeout(AppConfig.clientTimeout);
    } catch (_) {
      // Transport details can contain credentials; show only a fixed message.
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingKey = false;
          if (generation == _testGeneration) {
            _testSuccess = success;
            _testStatusMessage = success
                ? '${provider.displayName} accepted the key and listed the model. Vision and JSON support have not been tested. Nothing was saved.'
                : 'Could not verify the key and model with ${provider.displayName}. Check the key, model ID, account access and connection.';
          }
        });
      }
    }
  }

  String _safeVisionError(Object error, DirectAiProvider provider) {
    final name = provider.displayName;
    if (error is TimeoutException) {
      return 'The $name vision test timed out. Nothing was saved; no retry was sent.';
    }
    if (error is AppException) {
      return switch (error.code) {
        ErrorCode.upstreamAuthFailed =>
          '$name rejected the key or account access. Check this provider’s key, model permissions and account or regional restrictions in its console.',
        ErrorCode.upstreamRateLimited =>
          '$name reported an account rate or quota limit. Check model limits, remaining quota and billing in its console; wait for the limit to reset before retrying.',
        ErrorCode.requestTimeout =>
          'The $name vision test timed out. Nothing was saved; no retry was sent.',
        ErrorCode.networkOffline =>
          'Could not reach $name. Check your connection.',
        ErrorCode.validationFailed =>
          '$name did not return a supported image and JSON response. Check that the model supports both.',
        ErrorCode.operationCancelled =>
          'Vision test cancelled. Nothing was saved.',
        ErrorCode.cloudConsentRequired =>
          'Cloud consent is required before sending a sample image.',
        _ =>
          'The $name vision test failed. Check the key, model capabilities and account access.',
      };
    }
    return 'The $name vision test failed. Check the key, model capabilities and account access. Nothing was saved.';
  }

  Future<void> _testVision() async {
    if (_directTestBusy || !_validateDirectSettings()) return;
    if (!widget.preferencesService.cloudConsentGranted) {
      setState(() {
        _testSuccess = false;
        _testStatusMessage = 'Cloud consent is required. Enable cloud processing in Settings before testing vision. This test does not grant consent.';
      });
      return;
    }
    final generation = ++_testGeneration;
    final provider = _selectedProvider;
    final key = _apiKeyController.text.trim();
    final model = _modelController.text;
    setState(() => _isTestingVision = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Send generated sample image?'),
          scrollable: true,
          content: Text(
            'A generated 64 × 64 red sample image will be sent to ${provider.displayName} using the key and model currently entered. This request is billed by your own provider account and may incur a charge. No camera or photo is accessed or uploaded. One request will be sent, with no retry. Nothing is saved.'
            '${provider == DirectAiProvider.mistral ? '\n\n$_kMistralPilotNotice' : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send sample image'),
            ),
          ],
        ),
      );
      if (!mounted || generation != _testGeneration) return;
      if (confirmed != true) {
        setState(() {
          _testSuccess = null;
          _testStatusMessage =
              'Vision test cancelled. No image was sent and nothing was saved.';
        });
        return;
      }
      if (!widget.preferencesService.cloudConsentGranted) {
        setState(() {
          _testSuccess = false;
          _testStatusMessage = 'Cloud consent is required. No image was sent.';
        });
        return;
      }
      final cancelToken = CancelToken();
      _visionCancelToken = cancelToken;
      setState(() {
        _testSuccess = null;
        _testStatusMessage =
            'Testing vision with a generated sample image at ${provider.displayName}. One request; no retry.';
      });
      final sample = image.Image(width: 64, height: 64, numChannels: 3);
      image.fill(sample, color: image.ColorRgb8(255, 0, 0));
      final base64Jpeg = base64Encode(image.encodeJpg(sample));
      final vision =
          widget.directProviderFactory?.call(
            credentialService: widget.credentialService,
            provider: provider,
            model: model,
            apiKeyOverride: key,
          ) ??
          OpenAiCompatibleVisionProvider(
            credentialService: widget.credentialService,
            provider: provider,
            model: model,
            apiKeyOverride: key,
          );
      await vision
          .describeScene(
            requestId:
                'settings-sample-${DateTime.now().microsecondsSinceEpoch}',
            base64Jpeg: base64Jpeg,
            language: widget.preferencesService.language,
            cancelToken: cancelToken,
            timeout: AppConfig.clientTimeout,
          )
          .timeout(
            AppConfig.clientTimeout,
            onTimeout: () {
              cancelToken.cancel();
              throw TimeoutException('Vision test deadline');
            },
          );
      if (mounted && generation == _testGeneration) {
        setState(() {
          _testSuccess = true;
          _testStatusMessage =
              '${provider.displayName} returned a supported vision and JSON response for the generated sample image. Nothing was saved.';
        });
      }
    } catch (error) {
      if (mounted && generation == _testGeneration) {
        setState(() {
          _testSuccess = false;
          _testStatusMessage = _safeVisionError(error, provider);
        });
      }
    } finally {
      if (generation == _testGeneration) _visionCancelToken = null;
      if (mounted) setState(() => _isTestingVision = false);
    }
  }

  Future<void> _testWorker() async {
    final url = _workerUrlController.text.trim();
    final validationError = _validateWorkerUrl(url);
    if (validationError != null) {
      setState(() {
        _workerTestStatusMessage = validationError;
        _workerTestSuccess = false;
      });
      return;
    }
    setState(() {
      _isTestingWorker = true;
      _workerTestStatusMessage = 'Pinging Cloudflare Worker health endpoint...';
      _workerTestSuccess = null;
    });
    bool success = false;
    try {
      success = await widget.credentialService
          .testWorkerHealth(url)
          .timeout(AppConfig.clientTimeout);
    } catch (_) {
      // Do not expose transport errors or stored credentials.
    }
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
    if (!_canEdit || _directTestBusy || _isTestingWorker) return;
    final mode = _selectedMode;
    final provider = _selectedProvider;
    final key = _apiKeyController.text.trim();
    final model = _modelController.text;
    final url = _workerUrlController.text.trim();
    final token = _demoTokenController.text.trim();
    if (mode == ProviderMode.byok) {
      if (!_validateDirectSettings()) return;
    } else {
      final error = _validateWorkerUrl(url);
      if (error != null) {
        setState(() {
          _workerTestStatusMessage = error;
          _workerTestSuccess = false;
        });
        return;
      }
    }
    setState(() {
      _isSaving = true;
      _saveStatusMessage = 'Saving connection settings securely...';
      _credentialGeneration++;
    });
    try {
      // Write credentials before activating the new connection.
      if (mode == ProviderMode.byok) {
        await widget.credentialService.setProviderApiKey(provider, key);
        await widget.preferencesService.setVisionModel(provider, model);
        await widget.preferencesService.setDirectAiProvider(provider);
      } else {
        if (token.isNotEmpty) {
          await widget.credentialService.setDemoAccessToken(token);
        }
        await widget.preferencesService.setApiBaseUrl(url);
      }
      await widget.preferencesService.setProviderMode(mode);
      widget.coordinator?.refreshVisionProvider();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI connection settings saved.')),
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _saveStatusMessage = 'Could not save connection settings. Check secure storage and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _clearKey() async {
    if (!_canEdit) return;
    final provider = _selectedProvider;
    setState(() {
      _invalidateTests();
      _credentialGeneration++;
      _apiKeyController.clear();
      _keyDirty = true;
      _isLoadingKey = false;
      _isRemovingKey = true;
    });
    try {
      await widget.credentialService.clearProviderApiKey(provider);
      if (mounted) {
        setState(() {
          _testStatusMessage =
              '${provider.displayName} API key removed from secure storage. Other provider keys were not changed.';
          _testSuccess = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _testStatusMessage =
              'Could not remove the saved ${provider.displayName} key. Try again.';
          _testSuccess = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isRemovingKey = false);
    }
  }

  Widget _status(String message, bool? success) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: TextStyle(
            color: success == true
                ? colors.primary
                : success == false
                ? colors.error
                : colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonStyle = ElevatedButton.styleFrom(
      minimumSize: const Size(88, AppTheme.minTouchTarget),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('AI Connection')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Connection Mode', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            RadioGroup<ProviderMode>(
              groupValue: _selectedMode,
              onChanged: (value) {
                if (value != null && _canEdit) {
                  setState(() {
                    _invalidateTests();
                    _selectedMode = value;
                    _saveStatusMessage = null;
                  });
                }
              },
              child: Column(
                children: [
                  RadioListTile<ProviderMode>(
                    enabled: _canEdit,
                    title: const Text('EyeSense service (Hosted prototype)'),
                    subtitle: const Text(
                      'Connects through the secure EyeSense Worker proxy.',
                    ),
                    value: ProviderMode.hosted,
                  ),
                  RadioListTile<ProviderMode>(
                    enabled: _canEdit,
                    title: const Text('Use my own AI provider'),
                    subtitle: const Text(
                      'Connect directly using your own provider account and API key.',
                    ),
                    value: ProviderMode.byok,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_selectedMode == ProviderMode.byok) ...[
              DropdownButtonFormField<DirectAiProvider>(
                key: ValueKey(_selectedProvider),
                initialValue: _selectedProvider,
                isExpanded: true,
                itemHeight: null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'AI provider',
                ),
                items: [
                  for (final provider in DirectAiProvider.values)
                    DropdownMenuItem(
                      value: provider,
                      child: Text(provider.displayName),
                    ),
                ],
                onChanged: _canEdit
                    ? (provider) {
                        if (provider != null) _selectProvider(provider);
                      }
                    : null,
              ),
              if (_selectedProvider == DirectAiProvider.mistral) ...[
                const SizedBox(height: 16),
                const Text(_kMistralPilotNotice),
              ],
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('provider-api-key'),
                controller: _apiKeyController,
                enabled: _canEdit,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                autofillHints: const [],
                onChanged: (_) => setState(() {
                  _keyDirty = true;
                  _invalidateTests();
                  _saveStatusMessage = null;
                }),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: '${_selectedProvider.displayName} API key',
                  helperText: _isLoadingKey
                      ? 'Loading this provider’s saved key. You can enter a replacement.'
                      : 'Stored securely on this device only when you save.',
                  helperMaxLines: 5,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('provider-model'),
                controller: _modelController,
                enabled: _canEdit,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() {
                  _modelError = null;
                  _invalidateTests();
                  _saveStatusMessage = null;
                }),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: 'Advanced model ID',
                  helperText: 'Must support images and JSON responses. Model availability depends on your provider account.',
                  helperMaxLines: 6,
                  errorText: _modelError,
                  errorMaxLines: 5,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Checking the key and model only checks authentication and the model list. It does not send an image or verify vision support.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton(
                    style: buttonStyle,
                    onPressed: _canEdit && !_directTestBusy
                        ? _checkKeyAndModel
                        : null,
                    child: Text(
                      _isCheckingKey
                          ? 'Checking key and model…'
                          : 'Check key and model',
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(88, AppTheme.minTouchTarget),
                    ),
                    onPressed: _canEdit ? _clearKey : null,
                    child: Text(
                      _isRemovingKey ? 'Removing key…' : 'Remove saved key',
                    ),
                  ),
                  ElevatedButton(
                    style: buttonStyle,
                    onPressed: _canEdit && !_directTestBusy
                        ? _testVision
                        : null,
                    child: Text(
                      _isTestingVision
                          ? 'Testing vision…'
                          : 'Test vision with sample image',
                    ),
                  ),
                ],
              ),
              if (_testStatusMessage != null)
                _status(_testStatusMessage!, _testSuccess),
            ] else ...[
              ExpansionTile(
                title: const Text('Advanced'),
                children: [
                  TextField(
                    controller: _workerUrlController,
                    enabled: _canEdit,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Worker Base URL',
                      hintText: 'https://eyesense-api.example.workers.dev',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: buttonStyle,
                    onPressed: _canEdit && !_isTestingWorker
                        ? _testWorker
                        : null,
                    child: Text(
                      _isTestingWorker
                          ? 'Testing Worker…'
                          : 'Test Worker Connection',
                    ),
                  ),
                  if (_workerTestStatusMessage != null)
                    _status(_workerTestStatusMessage!, _workerTestSuccess),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _demoTokenController,
                    enabled: _canEdit,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    autofillHints: const [],
                    onChanged: (_) => _demoTokenDirty = true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Demo Access Token',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ],
            if (_saveStatusMessage != null) _status(_saveStatusMessage!, null),
            const SizedBox(height: 36),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppTheme.primaryButtonHeight,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const ValueKey('save-connection'),
                  style: buttonStyle,
                  onPressed: _canEdit && !_directTestBusy && !_isTestingWorker
                      ? _saveSettings
                      : null,
                  child: Text(
                    _isSaving ? 'Saving…' : 'Save Connection Settings',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
