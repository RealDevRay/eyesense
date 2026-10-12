import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/core/theme/app_theme.dart';
import 'package:eyesense/features/home/home_screen.dart';
import 'package:eyesense/features/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';

class EyeSenseApp extends StatefulWidget {
  final AgentCoordinator coordinator;

  const EyeSenseApp({super.key, required this.coordinator});

  @override
  State<EyeSenseApp> createState() => _EyeSenseAppState();
}

class _EyeSenseAppState extends State<EyeSenseApp> {
  late bool _showOnboarding;

  @override
  void initState() {
    super.initState();
    _showOnboarding = !widget.coordinator.preferencesService.hasCompletedOnboarding;
  }

  ThemeMode _resolveThemeMode() {
    final mode = widget.coordinator.preferencesService.themeModeString;
    if (mode == 'dark') return ThemeMode.dark;
    if (mode == 'light') return ThemeMode.light;
    return ThemeMode.system;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.coordinator.preferencesService,
      builder: (context, _) {
        return MaterialApp(
          title: 'EyeSense',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _resolveThemeMode(),
          home: _showOnboarding
              ? OnboardingScreen(
                  coordinator: widget.coordinator,
                  onFinish: () {
                    setState(() {
                      _showOnboarding = false;
                    });
                  },
                )
              : HomeScreen(coordinator: widget.coordinator),
        );
      },
    );
  }
}
