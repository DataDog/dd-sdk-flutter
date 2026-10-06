// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The full screen Flutter view the native host pushes on top of its own
/// screen.
class FullScreenApp extends StatefulWidget {
  const FullScreenApp({super.key});

  @override
  State<FullScreenApp> createState() => _FullScreenAppState();
}

class _FullScreenAppState extends State<FullScreenApp> {
  final _captureKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // SessionReplayCapture must sit above MaterialApp so it sees the whole
    // widget tree.
    return SessionReplayCapture(
      key: _captureKey,
      rum: DatadogSdk.instance.rum!,
      sessionReplay: DatadogSessionReplay.instance!,
      child: const MaterialApp(
        title: 'Flutter Inputs',
        home: InputsScreen(),
      ),
    );
  }
}

class InputsScreen extends StatefulWidget {
  const InputsScreen({super.key});

  @override
  State<InputsScreen> createState() => _InputsScreenState();
}

class _InputsScreenState extends State<InputsScreen> {
  /// Both native hosts handle `dismiss` on this channel by closing the
  /// Flutter view.
  static const _navigationChannel =
      MethodChannel('hybrid_session_replay_example/navigation');

  double _sliderValue = 0.5;
  bool _switchValue = false;
  bool _checkboxValue = false;
  int _iconTaps = 0;
  String _radioValue = 'a';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Inputs')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to native'),
              onPressed: () => _navigationChannel.invokeMethod('dismiss'),
            ),
          ),
          _row(
            'Slider',
            Slider(
              value: _sliderValue,
              onChanged: (value) => setState(() => _sliderValue = value),
            ),
          ),
          _row(
            'Switch',
            Switch(
              value: _switchValue,
              onChanged: (value) => setState(() => _switchValue = value),
            ),
          ),
          _row(
            'Icon button (tapped $_iconTaps)',
            IconButton(
              icon: const Icon(Icons.favorite),
              onPressed: () => setState(() => _iconTaps++),
            ),
          ),
          _row(
            'Checkbox',
            Checkbox(
              value: _checkboxValue,
              onChanged: (value) =>
                  setState(() => _checkboxValue = value ?? false),
            ),
          ),
          RadioGroup<String>(
            groupValue: _radioValue,
            onChanged: (value) => setState(() => _radioValue = value ?? 'a'),
            child: Column(
              children: [
                _row('Radio A', const Radio<String>(value: 'a')),
                _row('Radio B', const Radio<String>(value: 'b')),
              ],
            ),
          ),
          _row(
            'Password',
            // Masked in the replay: the privacy level is
            // maskSensitiveInputs, and this field is obscured.
            const TextField(obscureText: true),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 200, child: Text(label)),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: child)),
        ],
      ),
    );
  }
}
