import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/app.dart';
import 'package:eyesense/services/camera_service.dart';
import 'package:eyesense/services/credential_service.dart';
import 'package:eyesense/services/diagnostic_log_service.dart';
import 'package:eyesense/services/haptic_service.dart';
import 'package:eyesense/services/ocr_service.dart';
import 'package:eyesense/services/preferences_service.dart';
import 'package:eyesense/services/speech_service.dart';
import 'package:eyesense/services/tts_service.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(EyeSenseApp(coordinator: coordinator));
}
