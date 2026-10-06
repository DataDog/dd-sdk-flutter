// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:flutter/material.dart';

import 'recording_status.dart';

/// A sensitive screen. Recording, including touches, pauses while it is shown
/// and resumes when the user goes back to RecordedScreen.
class PrivateScreen extends StatefulWidget {
  const PrivateScreen({super.key});

  @override
  State<PrivateScreen> createState() => _PrivateScreenState();
}

class _PrivateScreenState extends State<PrivateScreen> {
  bool _switchOn = false;
  double _sliderValue = 0.5;
  final _secretController = TextEditingController();

  @override
  void initState() {
    super.initState();
    DatadogSessionReplay.instance?.stopRecording();
  }

  @override
  void dispose() {
    _secretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const RecordingStatus(),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Toggle setting'),
            value: _switchOn,
            onChanged: (v) => setState(() => _switchOn = v),
          ),
          const SizedBox(height: 12),
          Text('Slider: ${(_sliderValue * 100).round()}%'),
          Slider(
            value: _sliderValue,
            onChanged: (v) => setState(() => _sliderValue = v),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _secretController,
            obscureText: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Secret input (not captured)',
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => setState(() {
              _switchOn = false;
              _sliderValue = 0.5;
              _secretController.clear();
            }),
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
