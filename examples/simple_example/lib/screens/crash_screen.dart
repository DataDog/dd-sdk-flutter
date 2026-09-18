// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CrashTestScreen extends StatelessWidget {
  final methodChannel = const MethodChannel('com.datadog.crash_channel');

  const CrashTestScreen({super.key});

  void _onThrow() {
    throw UnsupportedError('Tapping that button was unsupported');
  }

  void _onCrash() {
    methodChannel.invokeMethod('crash');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crash Test Screen'),
      ),
      body: Center(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: ElevatedButton(
                onPressed: _onThrow,
                child: const Text('Throw Error'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: ElevatedButton(
                onPressed: _onCrash,
                child: const Text('Crash'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
