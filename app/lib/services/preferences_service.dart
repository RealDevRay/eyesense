import 'package:eyesense/core/config/app_config.dart';
import 'package:eyesense/models/app_operation.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  String get apiBaseUrl => _prefs.getString(_keyApiBaseUrl) ?? AppConfig.defaultApiBaseUrl;
  Future<void> setApiBaseUrl(String url) async {
    await _prefs.setString(_keyApiBaseUrl, url.trim());
    notifyListeners();
  }

  String get themeModeString => _prefs.getString(_keyThemeMode) ?? 'system';
  Future<void> setThemeModeString(String mode) async {
    await _prefs.setString(_keyThemeMode, mode);
    notifyListeners();
  }

  bool get hasCompletedOnboarding => _prefs.getBool(_keyCompletedOnboarding) ?? false;
  Future<void> setCompletedOnboarding(bool val) async {
    await _prefs.setBool(_keyCompletedOnboarding, val);
    notifyListeners();
  }

  int get onboardingStep => _prefs.getInt(_keyOnboardingStep) ?? 0;
  Future<void> setOnboardingStep(int step) async {
    await _prefs.setInt(_keyOnboardingStep, step);
    notifyListeners();
  }

  double get speechRate => _prefs.getDouble(_keySpeechRate) ?? 1.0;
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

  bool get diagnosticLoggingEnabled => _prefs.getBool(_keyDiagnosticLogging) ?? false;
  Future<void> setDiagnosticLoggingEnabled(bool val) async {
    await _prefs.setBool(_keyDiagnosticLogging, val);
    notifyListeners();
  }

  bool get cloudConsentGranted => _prefs.getBool(_keyCloudConsent) ?? false;
  Future<void> setCloudConsentGranted(bool val) async {
    await _prefs.setBool(_keyCloudConsent, val);
    notifyListeners();
  }

  ProviderMode get providerMode {
    final modeStr = _prefs.getString(_keyProviderMode);
    if (modeStr == 'byok') return ProviderMode.byok;
    return ProviderMode.hosted;
  }

  Future<void> setProviderMode(ProviderMode mode) async {
    await _prefs.setString(_keyProviderMode, mode == ProviderMode.byok ? 'byok' : 'hosted');
    notifyListeners();
  }

  bool get awarenessEnabled => _prefs.getBool(_keyAwarenessEnabled) ?? false;
  Future<void> setAwarenessEnabled(bool val) async {
    await _prefs.setBool(_keyAwarenessEnabled, val);
    notifyListeners();
  }
}
