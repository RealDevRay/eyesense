import 'package:eyesense/models/app_operation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _keySpeechRate = 'speech_rate';
  static const _keyLanguage = 'app_language';
  static const _keyHapticsEnabled = 'haptics_enabled';
  static const _keyAutoRead = 'auto_read';
  static const _keyDiagnosticLogging = 'diagnostic_logging_enabled';
  static const _keyCloudConsent = 'cloud_consent_granted';
  static const _keyProviderMode = 'provider_mode';
  static const _keyAwarenessEnabled = 'awareness_enabled';

  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  double get speechRate => _prefs.getDouble(_keySpeechRate) ?? 1.0;
  Future<void> setSpeechRate(double rate) => _prefs.setDouble(_keySpeechRate, rate);

  String get language => _prefs.getString(_keyLanguage) ?? 'en';
  Future<void> setLanguage(String lang) => _prefs.setString(_keyLanguage, lang);

  bool get hapticsEnabled => _prefs.getBool(_keyHapticsEnabled) ?? true;
  Future<void> setHapticsEnabled(bool val) => _prefs.setBool(_keyHapticsEnabled, val);

  bool get autoRead => _prefs.getBool(_keyAutoRead) ?? true;
  Future<void> setAutoRead(bool val) => _prefs.setBool(_keyAutoRead, val);

  bool get diagnosticLoggingEnabled => _prefs.getBool(_keyDiagnosticLogging) ?? false;
  Future<void> setDiagnosticLoggingEnabled(bool val) =>
      _prefs.setBool(_keyDiagnosticLogging, val);

  bool get cloudConsentGranted => _prefs.getBool(_keyCloudConsent) ?? false;
  Future<void> setCloudConsentGranted(bool val) =>
      _prefs.setBool(_keyCloudConsent, val);

  ProviderMode get providerMode {
    final modeStr = _prefs.getString(_keyProviderMode);
    if (modeStr == 'byok') return ProviderMode.byok;
    return ProviderMode.hosted;
  }

  Future<void> setProviderMode(ProviderMode mode) =>
      _prefs.setString(_keyProviderMode, mode == ProviderMode.byok ? 'byok' : 'hosted');

  bool get awarenessEnabled => _prefs.getBool(_keyAwarenessEnabled) ?? false;
  Future<void> setAwarenessEnabled(bool val) =>
      _prefs.setBool(_keyAwarenessEnabled, val);
}
