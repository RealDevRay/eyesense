import 'dart:async';

import 'package:eyesense/agents/agent_coordinator.dart';
import 'package:eyesense/services/device_sensor_service.dart';
import 'package:eyesense/widgets/accessible_action_button.dart';
import 'package:flutter/material.dart';

/// Explicit hardware check; nothing is sampled just by opening this screen.
class DeviceSupportScreen extends StatefulWidget {
  const DeviceSupportScreen({super.key, required this.coordinator});

  final AgentCoordinator coordinator;

  @override
  State<DeviceSupportScreen> createState() => _DeviceSupportScreenState();
}

class _DeviceSupportScreenState extends State<DeviceSupportScreen> {
  SensorCapabilities? _capabilities;
  String? _result;
  bool _checking = false;
  int _generation = 0;

  DeviceSensorService get _sensors =>
      widget.coordinator.cameraService.sensorService;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCapabilities());
  }

  Future<void> _loadCapabilities() async {
    final capabilities = await _sensors.getCapabilities();
    if (mounted) setState(() => _capabilities = capabilities);
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_sensors.stop());
    unawaited(widget.coordinator.speechFeedbackCoordinator.stopAll());
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking) return;
    final generation = ++_generation;
    setState(() {
      _checking = true;
      _result =
          'Checking phone sensors briefly. No image or location is collected.';
    });
    final assessment = await _sensors.check();
    if (!mounted || generation != _generation) return;
    final text = switch (assessment.status) {
      DeviceSensorStatus.cancelled => 'Sensor check stopped.',
      DeviceSensorStatus.unsupported => 'Sensor checks are unavailable on this device. Camera tasks still work.',
      DeviceSensorStatus.unavailable =>
        'No sensor readings were available. Camera tasks still work.',
      DeviceSensorStatus.stale =>
        'Sensor readings were out of date. No guidance was generated.',
      DeviceSensorStatus.completed => _describe(assessment),
    };
    setState(() {
      _checking = false;
      _capabilities = assessment.capabilities;
      _result = text;
    });
    if (widget.coordinator.preferencesService.autoRead) {
      await widget.coordinator.speechFeedbackCoordinator.speakResult(text);
    }
  }

  String _describe(DeviceSensorAssessment assessment) {
    final details = <String>['Sensor check complete.'];
    if (assessment.highAngularMotion) details.add('Hold the phone steady.');
    if (assessment.lowLight) {
      details.add('Ambient light is low. More light may help.');
    }
    if (assessment.frontSensorCovered) {
      details.add(
        'The front proximity sensor reports covered. This is not the rear camera or object distance.',
      );
    }
    if (assessment.pose != DevicePose.unknown) {
      details.add(switch (assessment.pose) {
        DevicePose.faceUp => 'Approximate phone pose: screen facing up.',
        DevicePose.faceDown => 'Approximate phone pose: screen facing down.',
        DevicePose.topEdgeUp => 'Approximate phone pose: top edge up.',
        DevicePose.topEdgeDown => 'Approximate phone pose: top edge down.',
        DevicePose.sideEdgeUp => 'Approximate phone pose: side edge up.',
        DevicePose.unknown => '',
      });
    }
    details.add(
      'These readings do not establish image quality, distance, or a safe route.',
    );
    return details.join(' ');
  }

  void _stop() {
    _generation++;
    unawaited(_sensors.stop());
    unawaited(widget.coordinator.speechFeedbackCoordinator.stopAll());
    setState(() {
      _checking = false;
      _result = 'Sensor check stopped.';
    });
  }

  String _name(DeviceSensor sensor) => switch (sensor) {
    DeviceSensor.accelerometer =>
      'Accelerometer — approximate phone orientation',
    DeviceSensor.gravity => 'Gravity sensor — phone orientation',
    DeviceSensor.gyroscope => 'Gyroscope — phone rotation',
    DeviceSensor.light => 'Ambient light — lighting cue',
    DeviceSensor.proximity => 'Front proximity — covered-sensor cue only',
  };

  @override
  Widget build(BuildContext context) {
    final prefs = widget.coordinator.preferencesService;
    return Scaffold(
      appBar: AppBar(title: const Text('Phone & capture guidance')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([prefs, widget.coordinator.ttsService]),
          builder: (context, _) => Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Optional on-device help for taking a picture. Missing sensors never prevent Describe, Read text, or Ask.',
                    ),
                    SwitchListTile(
                      key: const Key('capture-guidance-toggle'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Capture guidance'),
                      subtitle: const Text(
                        'Brief motion, lighting, or covered front-sensor cues before capture. Read text also checks image quality. Sensors are not uploaded.',
                      ),
                      value: prefs.aimingGuidance,
                      onChanged: _checking ? null : prefs.setAimingGuidance,
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text(
                        'Sensors on this phone',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_capabilities == null)
                      const Text(
                        'Checking hardware availability. Sensors are not sampling.',
                      )
                    else if (!_capabilities!.supported)
                      const Text(
                        'Sensor integration is unavailable. Camera tasks still work.',
                      )
                    else
                      for (final sensor in DeviceSensor.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '${_name(sensor)}: ${switch (_capabilities!.sensors[sensor]) {
                              SensorAvailability.available => 'available',
                              SensorAvailability.missing => 'not present',
                              _ => 'unavailable',
                            }}',
                          ),
                        ),
                    const SizedBox(height: 16),
                    AccessibleActionButton(
                      key: const Key('sensor-check'),
                      label: 'Check sensors now',
                      semanticHint: 'Sample available phone sensors for less than one second. No camera, location or internet.',
                      icon: Icons.sensors,
                      onPressed: _checking ? null : _check,
                    ),
                    const SizedBox(height: 16),
                    if (_result != null)
                      Semantics(
                        liveRegion: !prefs.autoRead,
                        child: Text(_result!),
                      ),
                    const SizedBox(height: 24),
                    const Text(
                      'No GPS, compass, barometer, step counter or depth tracking is active. Proximity is normally on the front of the phone: it cannot find rear-camera obstacles. Never use EyeSense for navigation or crossing decisions.',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: AccessibleActionButton(
                  key: const Key('sensor-stop'),
                  label: 'Stop',
                  semanticHint: 'Stop the sensor check and app speech',
                  icon: Icons.stop_circle_outlined,
                  isDestructive: true,
                  onPressed:
                      _checking || widget.coordinator.ttsService.isSpeaking
                      ? _stop
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
