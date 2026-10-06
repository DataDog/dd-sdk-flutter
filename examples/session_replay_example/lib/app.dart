// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:flutter/material.dart';

import 'screens/private_screen.dart';
import 'screens/recorded_screen.dart';

class ExampleApp extends StatefulWidget {
  final double replaySampleRate;

  const ExampleApp({super.key, required this.replaySampleRate});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final _captureKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // SessionReplayCapture must sit above MaterialApp so it sees the whole
    // widget tree.
    return SessionReplayCapture(
      key: _captureKey,
      rum: DatadogSdk.instance.rum!,
      sessionReplay: DatadogSessionReplay.instance!,
      child: MaterialApp(
        title: 'Session Replay Example',
        home: _HomeShell(replaySampleRate: widget.replaySampleRate),
      ),
    );
  }
}

class _HomeShell extends StatefulWidget {
  final double replaySampleRate;

  const _HomeShell({required this.replaySampleRate});

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Recorded Screen' : 'Private Screen'),
      ),
      body: _currentIndex == 0
          ? RecordedScreen(replaySampleRate: widget.replaySampleRate)
          : const PrivateScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fiber_manual_record, color: Colors.red),
            label: 'Recorded',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.visibility_off),
            label: 'Private',
          ),
        ],
      ),
    );
  }
}
