import 'package:eyesense/core/config/app_config.dart';
import 'package:eyesense/core/speech/speech_rate.dart';
import 'package:eyesense/models/app_operation.dart';
import 'package:eyesense/models/direct_ai_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AssistanceProfile { screenReader, lowVision, sightedAssistant }

class PreferencesService extends ChangeNotifier {
  static const _keySpeechRate = 'speech_rate';
  static const _keyLanguage = 'app_language';
  static const _keyHapticsEnabled = 'haptics_enabled';
  static const _keyAutoRead = 'auto_read';
  static const _keyDiagnosticLogging = 'diagnostic_logging_enabled';
  static const _keyCloudConsent = 'cloud_consent_granted';
  static const _keyProviderMode = 'provider_mode';
  static const _keyAwarenessEnabled = 'awareness_enabled';
  static const _keyThemeMode = 'theme_mode';
  static const _keyCompletedOnboarding = 'completed_onboarding';
  static const _keyOnboardingStep = 'onboarding_step';
  static const _keyApiBaseUrl = 'api_base_url';
  static const _keyProfile = 'assistance_profile';
  static const _keyProfileChosen = 'assistance_profile_chosen';
  static const _keyEarcons = 'earcons_enabled';
  static const _keyAiming = 'aiming_guidance';
  static const _keyAppMode = 'app_mode';
  static const _keyTermsVersion = 'terms_version_accepted';
  static const _keyTermsAcceptedAt = 'terms_accepted_at';
  static const _keySafetyBriefing = 'safety_briefing_acknowledged_version';
  static const _keyLaunchOrientationCount = 'launch_orientation_count';
  static const _keyPreferredTextScale = 'preferred_text_scale';

  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  String get apiBaseUrl =>
      _prefs.getString(_keyApiBaseUrl) ?? AppConfig.defaultApiBaseUrl;
  Future<void> setApiBaseUrl(String url) async {
    await _prefs.setString(_keyApiBaseUrl, url.trim());
    notifyListeners();
  }

  String get themeModeString => _prefs.getString(_keyThemeMode) ?? 'system';
  Future<void> setThemeModeString(String mode) async {
    await _prefs.setString(_keyThemeMode, mode);
    notifyListeners();
  }

  bool get hasCompletedOnboarding =>
      _prefs.getBool(_keyCompletedOnboarding) ?? false;
  Future<void> setCompletedOnboarding(bool val) async {
    await _prefs.setBool(_keyCompletedOnboarding, val);
    notifyListeners();
  }

  int get onboardingStep => _prefs.getInt(_keyOnboardingStep) ?? 0;
  Future<void> setOnboardingStep(int step) async {
    await _prefs.setInt(_keyOnboardingStep, step);
    notifyListeners();
  }

  double get speechRate {
    final stored = _prefs.getDouble(_keySpeechRate) ?? 1.0;
    return stored
        .clamp(SpeechRateScale.minProduct, SpeechRateScale.maxProduct)
        .toDouble();
  }

  Future<void> setSpeechRate(double rate) async {
    await _prefs.setDouble(_keySpeechRate, rate);
    notifyListeners();
  }

  String get language => _prefs.getString(_keyLanguage) ?? 'en';
  Future<void> setLanguage(String lang) async {
    await _prefs.setString(_keyLanguage, lang);
    notifyListeners();
  }

  bool get hapticsEnabled => _prefs.getBool(_keyHapticsEnabled) ?? true;
  Future<void> setHapticsEnabled(bool val) async {
    await _prefs.setBool(_keyHapticsEnabled, val);
    notifyListeners();
  }

  bool get autoRead => _prefs.getBool(_keyAutoRead) ?? true;
  Future<void> setAutoRead(bool val) async {
    await _prefs.setBool(_keyAutoRead, val);
    notifyListeners();
  }

  bool get diagnosticLoggingEnabled =>
      _prefs.getBool(_keyDiagnosticLogging) ?? false;
  Future<void> setDiagnosticLoggingEnabled(bool val) async {
    await _prefs.setBool(_keyDiagnosticLogging, val);
    notifyListeners();
  }

  bool get cloudConsentGranted =>
      (_prefs.getBool(_keyCloudConsent) ?? false) &&
      acceptedTermsVersion == AppConfig.termsVersion;
  Future<void> setCloudConsentGranted(bool val) async {
    await _prefs.setBool(_keyCloudConsent, val);
    if (val) {
      await _prefs.setString(_keyTermsVersion, AppConfig.termsVersion);
      await _prefs.setString(
        _keyTermsAcceptedAt,
        DateTime.now().toUtc().toIso8601String(),
      );
    }
    notifyListeners();
  }

  ProviderMode get providerMode {
    final modeStr = _prefs.getString(_keyProviderMode);
    if (modeStr == 'byok') return ProviderMode.byok;
    return ProviderMode.hosted;
  }

  Future<void> setProviderMode(ProviderMode mode) async {
    await _prefs.setString(
      _keyProviderMode,
      mode == ProviderMode.byok ? 'byok' : 'hosted',
    );
    notifyListeners();
  }

  DirectAiProvider get directAiProvider {
    final saved = _prefs.get('direct_ai_provider');
    // Accept legacy indices; subsequent explicit saves use stable names.
    if (saved is int && saved >= 0 && saved < DirectAiProvider.values.length) {
      return DirectAiProvider.values[saved];
    }
    return DirectAiProvider.values.firstWhere(
      (provider) => provider.name == saved,
      orElse: () => DirectAiProvider.groq,
    );
  }

  String visionModelFor(DirectAiProvider provider) =>
      _prefs.getString('vision_model_${provider.name}') ??
      provider.defaultModel;

  Future<void> setDirectAiProvider(DirectAiProvider provider) async {
    await _prefs.setString('direct_ai_provider', provider.name);
    notifyListeners();
  }

  Future<void> setVisionModel(DirectAiProvider provider, String model) async {
    final trimmed = model.trim();
    if (trimmed.isEmpty ||
        trimmed.length > 150 ||
        RegExp(r'\s').hasMatch(trimmed)) {
      throw ArgumentError(
        'Enter a model ID without spaces (maximum 150 characters).',
      );
    }
    await _prefs.setString('vision_model_${provider.name}', trimmed);
    notifyListeners();
  }

  bool get awarenessEnabled => _prefs.getBool(_keyAwarenessEnabled) ?? false;
  Future<void> setAwarenessEnabled(bool val) async {
    await _prefs.setBool(_keyAwarenessEnabled, val);
    notifyListeners();
  }

  bool get hasChosenProfile => _prefs.getBool(_keyProfileChosen) ?? false;

  AssistanceProfile get assistanceProfile {
    switch (_prefs.getString(_keyProfile)) {
      case 'lowVision':
        return AssistanceProfile.lowVision;
      case 'sightedAssistant':
        return AssistanceProfile.sightedAssistant;
      case 'screenReader':
        return AssistanceProfile.screenReader;
      default:
        return AssistanceProfile.screenReader;
    }
  }

  /// Applies defaults once. Later changes in Settings are left alone.
  Future<void> applyProfileDefaults(AssistanceProfile profile) async {
    await _prefs.setString(_keyProfile, profile.name);
    await _prefs.setBool(_keyProfileChosen, true);
    switch (profile) {
      case AssistanceProfile.screenReader:
        await _prefs.setBool(_keyAutoRead, true);
        await _prefs.setBool(_keyEarcons, true);
        await _prefs.setBool(_keyAiming, true);
        await _prefs.setDouble(_keyPreferredTextScale, 1.0);
        await _prefs.setString(
          _keyThemeMode,
          _prefs.getString(_keyThemeMode) ?? 'system',
        );
      case AssistanceProfile.lowVision:
        await _prefs.setBool(_keyAutoRead, true);
        await _prefs.setBool(_keyEarcons, false);
        await _prefs.setBool(_keyAiming, false);
        await _prefs.setDouble(_keyPreferredTextScale, 1.4);
        await _prefs.setString(_keyThemeMode, 'contrast');
      case AssistanceProfile.sightedAssistant:
        await _prefs.setBool(_keyAutoRead, true);
        await _prefs.setBool(_keyEarcons, false);
        await _prefs.setBool(_keyAiming, false);
        await _prefs.setDouble(_keyPreferredTextScale, 1.0);
    }
    notifyListeners();
  }

  bool get earconsEnabled => _prefs.getBool(_keyEarcons) ?? true;
  Future<void> setEarconsEnabled(bool val) async {
    await _prefs.setBool(_keyEarcons, val);
    notifyListeners();
  }

  bool get aimingGuidance => _prefs.getBool(_keyAiming) ?? false;
  Future<void> setAimingGuidance(bool val) async {
    await _prefs.setBool(_keyAiming, val);
    notifyListeners();
  }

  double get preferredTextScale =>
      _prefs.getDouble(_keyPreferredTextScale) ?? 1.0;

  AppMode get appMode {
    switch (_prefs.getString(_keyAppMode)) {
      case 'readText':
        return AppMode.readText;
      case 'ask':
        return AppMode.ask;
      default:
        return AppMode.describe;
    }
  }

  Future<void> setAppMode(AppMode mode) async {
    await _prefs.setString(_keyAppMode, mode.name);
    notifyListeners();
  }

  String? get acceptedTermsVersion => _prefs.getString(_keyTermsVersion);
  String? get acceptedTermsAt => _prefs.getString(_keyTermsAcceptedAt);

  Future<void> recordTermsAcceptance() async {
    // Accepting terms alone must not reactivate a legacy cloud opt-in.
    if (!cloudConsentGranted) {
      await _prefs.setBool(_keyCloudConsent, false);
    }
    await _prefs.setString(_keyTermsVersion, AppConfig.termsVersion);
    await _prefs.setString(
      _keyTermsAcceptedAt,
      DateTime.now().toUtc().toIso8601String(),
    );
    notifyListeners();
  }

  /// Tracked against the terms version so that a change to the safety wording
  /// is shown again rather than assumed to have been read years ago.
  bool get hasAcknowledgedSafety =>
      _prefs.getString(_keySafetyBriefing) == AppConfig.termsVersion;

  Future<void> recordSafetyAcknowledgement() async {
    await _prefs.setString(_keySafetyBriefing, AppConfig.termsVersion);
    notifyListeners();
  }

  int get launchOrientationCount =>
      _prefs.getInt(_keyLaunchOrientationCount) ?? 0;
  Future<void> incrementLaunchOrientationCount() async {
    await _prefs.setInt(_keyLaunchOrientationCount, launchOrientationCount + 1);
  }
}
