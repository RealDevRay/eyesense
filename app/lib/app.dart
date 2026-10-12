import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/core/theme/app_theme.dart';
import 'package:eyesense/features/home/home_screen.dart';
import 'package:flutter/material.dart';

class EyeSenseApp extends StatelessWidget {
  final AgentCoordinator coordinator;

  const EyeSenseApp({super.key, required this.coordinator});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EyeSense',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: HomeScreen(coordinator: coordinator),
    );
  }
}
