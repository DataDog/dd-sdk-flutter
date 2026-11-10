// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:flutter/material.dart';

/// A small Flutter panel the native host shows between its own controls.
class EmbeddedPanelApp extends StatefulWidget {
  const EmbeddedPanelApp({super.key});

  @override
  State<EmbeddedPanelApp> createState() => _EmbeddedPanelAppState();
}

class _EmbeddedPanelAppState extends State<EmbeddedPanelApp> {
  final _captureKey = GlobalKey();
  bool _partyOn = false;

  @override
  Widget build(BuildContext context) {
    // SessionReplayCapture must sit above MaterialApp so it sees the whole
    // widget tree.
    return SessionReplayCapture(
      key: _captureKey,
      rum: DatadogSdk.instance.rum!,
      sessionReplay: DatadogSessionReplay.instance!,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.amber.shade50,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _partyOn ? Icons.celebration : Icons.bedtime,
                  size: 56,
                  color: _partyOn ? Colors.deepOrange : Colors.indigo,
                ),
                const SizedBox(height: 8),
                Text(
                  _partyOn ? 'Party time!' : 'Sleepy...',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Switch(
                  value: _partyOn,
                  onChanged: (value) => setState(() => _partyOn = value),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
