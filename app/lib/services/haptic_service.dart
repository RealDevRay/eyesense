import 'package:eyesense/services/preferences_service.dart';
import 'package:flutter/services.dart';

class HapticService {
  final PreferencesService _prefs;

  HapticService(this._prefs);

  Future<void> confirmAction() async {
    if (!_prefs.hapticsEnabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  Future<void> indicateConcern() async {
    if (!_prefs.hapticsEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }
}
