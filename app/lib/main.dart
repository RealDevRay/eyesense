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
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EyeSenseBootstrapApp());
}

class EyeSenseBootstrapApp extends StatefulWidget {
  const EyeSenseBootstrapApp({super.key});

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
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_coordinator != null) {
      return EyeSenseApp(coordinator: _coordinator!);
    }

    return MaterialApp(
      title: 'EyeSense',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Scaffold(
        backgroundColor: const Color(0xFF0B1630),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: _error != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFFFB300),
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Initialization Notice',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFD5DEF0),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 28),
                        ElevatedButton.icon(
                          onPressed: _bootstrap,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry Startup'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF35D6C4),
                            foregroundColor: const Color(0xFF0B1630),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: const Color(0xFF132247),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF35D6C4),
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.visibility,
                            color: Color(0xFF35D6C4),
                            size: 52,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'EyeSense',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your world, described.',
                          style: TextStyle(
                            color: Color(0xFF35D6C4),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 40),
                        if (_isLoading)
                          const CircularProgressIndicator(
                            color: Color(0xFF35D6C4),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
