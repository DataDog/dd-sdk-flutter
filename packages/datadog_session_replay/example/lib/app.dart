// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:flutter/material.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final captureKey = GlobalKey();

  @override
  void initState() {
    DatadogSdk.instance.rum?.startView('First View');
    super.initState();
  }

  void _onCapture() {
    DatadogSessionReplay.instance?.performCapture();
  }

  @override
  Widget build(BuildContext context) {
    return SessionReplayCapture(
      key: captureKey,
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Plugin example app'),
          ),
          body: Center(
            child: Column(
              children: [
                const Text('Running'),
                ElevatedButton(
                  onPressed: _onCapture,
                  child: const Text('Capture'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
