import 'dart:async';
import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/app.dart';
import 'package:eyesense/core/theme/app_theme.dart';
import 'package:eyesense/services/camera_service.dart';
import 'package:eyesense/services/credential_service.dart';
import 'package:eyesense/services/diagnostic_log_service.dart';
import 'package:eyesense/services/haptic_service.dart';
import 'package:eyesense/services/ocr_service.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:eyesense/services/speech_service.dart';
import 'package:eyesense/services/tts_service.dart';
import 'package:eyesense/widgets/eye_sense_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final stored = await SharedPreferences.getInstance();
  final themeMode = stored.getString('theme_mode') ?? 'system';
  runApp(EyeSenseBootstrapApp(initialThemeMode: themeMode));
}

class EyeSenseBootstrapApp extends StatefulWidget {
  final String initialThemeMode;

  const EyeSenseBootstrapApp({super.key, this.initialThemeMode = 'system'});

  @override
  State<EyeSenseBootstrapApp> createState() => _EyeSenseBootstrapAppState();
}

class _EyeSenseBootstrapAppState extends State<EyeSenseBootstrapApp> {
  AgentCoordinator? _coordinator;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final preferencesService = await PreferencesService.create();
      final credentialService = CredentialService();
      final logService = DiagnosticLogService(preferencesService);

      final cameraService = CameraService();
      unawaited(cameraService.sweepOrphanedCaptures());
      final ttsService = TtsService(preferencesService);
      final speechService = SpeechService();
      final ocrService = OcrService();
      final hapticService = HapticService(preferencesService);

      final coordinator = AgentCoordinator(
        cameraService: cameraService,
        ttsService: ttsService,
        speechService: speechService,
        ocrService: ocrService,
        hapticService: hapticService,
        preferencesService: preferencesService,
        credentialService: credentialService,
        logService: logService,
      );

      if (mounted) {
        setState(() {
          _coordinator = coordinator;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('EyeSense bootstrap error: $e\n$stack');
      if (mounted) {
        setState(() {
          _error = 'EyeSense could not start. Use Retry startup.';
          _isLoading = false;
        });
        unawaited(FlutterTts().speak('EyeSense could not start. Use Retry startup.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_coordinator != null) {
      return EyeSenseApp(coordinator: _coordinator!);
    }

    final platform = View.of(context).platformDispatcher.platformBrightness;
    final bootstrapTheme = AppTheme.themeFor(widget.initialThemeMode, platform);
    final colors = bootstrapTheme.extension<EyeSenseColors>() ?? EyeSenseColors.dark;
    return MaterialApp(
      title: 'EyeSense',
      debugShowCheckedModeBanner: false,
      theme: bootstrapTheme,
      home: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _error != null
                  ? Semantics(
                      liveRegion: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning_amber_rounded, color: colors.concern, size: 48),
                          const SizedBox(height: 16),
                          Text('EyeSense could not start', style: bootstrapTheme.textTheme.headlineSmall),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center, style: bootstrapTheme.textTheme.bodyMedium),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _bootstrap,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry startup'),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        EyeSenseMark(size: 72, color: colors.accent),
                        const SizedBox(height: 24),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: 'Eye', style: TextStyle(color: colors.textPrimary)),
                              TextSpan(text: 'Sense', style: TextStyle(color: colors.accent)),
                            ],
                            style: bootstrapTheme.textTheme.displaySmall,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('Your world, described.', style: bootstrapTheme.textTheme.bodyMedium),
                        const SizedBox(height: 48),
                        if (_isLoading) CircularProgressIndicator(color: colors.accent),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
