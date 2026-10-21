import 'dart:math' as math;

import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/core/theme/app_theme.dart';
import 'package:eyesense/features/home/home_screen.dart';
import 'package:eyesense/features/onboarding/onboarding_screen.dart';
import 'package:eyesense/features/profile/profile_choice_screen.dart';
import 'package:flutter/material.dart';

class EyeSenseApp extends StatefulWidget {
  final AgentCoordinator coordinator;

  const EyeSenseApp({super.key, required this.coordinator});

  @override
  State<EyeSenseApp> createState() => _EyeSenseAppState();
}

class _EyeSenseAppState extends State<EyeSenseApp> with WidgetsBindingObserver {
  late bool _showOnboarding;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _showOnboarding =
        !widget.coordinator.preferencesService.hasCompletedOnboarding;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission dialogs may be inactive; only leaving the app cancels work.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.coordinator.suspend();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  ThemeMode _resolveThemeMode() {
    final mode = widget.coordinator.preferencesService.themeModeString;
    if (mode == 'light') return ThemeMode.light;
    if (mode == 'dark' || mode == 'contrast') return ThemeMode.dark;
    return ThemeMode.system;
  }

  @override
  Widget build(BuildContext context) {
    final prefs = widget.coordinator.preferencesService;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) {
        final contrast = prefs.themeModeString == 'contrast';
        return MaterialApp(
          title: 'EyeSense',
          debugShowCheckedModeBanner: false,
          theme: contrast ? AppTheme.maximumContrastTheme : AppTheme.lightTheme,
          darkTheme: contrast
              ? AppTheme.maximumContrastTheme
              : AppTheme.darkTheme,
          themeMode: _resolveThemeMode(),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final scale = math.max(
              media.textScaler.scale(1),
              prefs.preferredTextScale,
            );
            return MediaQuery(
              data: media.copyWith(textScaler: TextScaler.linear(scale)),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: !prefs.hasChosenProfile
              ? ProfileChoiceScreen(
                  preferences: prefs,
                  onChosen: () => setState(() {}),
                )
              : _showOnboarding
              ? OnboardingScreen(
                  coordinator: widget.coordinator,
                  onFinish: () => setState(() => _showOnboarding = false),
                )
              : HomeScreen(coordinator: widget.coordinator),
        );
      },
    );
  }
}
