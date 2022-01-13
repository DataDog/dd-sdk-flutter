// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:io';

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Helper class to crash in native code
class NativeCrashPlugin {
  final _methodChannel =
      const MethodChannel('datadog_sdk_flutter.example.crash');

  Future<void> crashNative() {
    return _methodChannel.invokeListMethod('crashNative');
  }
}

class CrashReportingScreen extends StatefulWidget {
  const CrashReportingScreen({Key? key}) : super(key: key);

  @override
  _CrashReportingScreenState createState() => _CrashReportingScreenState();
}

class _CrashReportingScreenState extends State<CrashReportingScreen> {
  var _viewName = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Crash Reporting')),
      body: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Crash after starting RUM Session',
                style: theme.textTheme.headline6),
            Container(
              padding: const EdgeInsets.all(4),
              child: TextField(
                onChanged: (value) => _viewName = value,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), labelText: 'RUM view name'),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () => _crashAfterRumSession(false),
                  child: const Text('Crash in Flutter'),
                ),
                ElevatedButton(
                  onPressed: () => _crashAfterRumSession(true),
                  child: const Text('Crash in Native Code'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Crash before starting RUM Session',
                style: theme.textTheme.headline6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () => _crashBeforeRumSession(false),
                  child: const Text('Crash in Flutter'),
                ),
                ElevatedButton(
                  onPressed: () => _crashBeforeRumSession(true),
                  child: const Text('Crash in Native Code'),
                ),
              ],
            ),
            const SizedBox(height: 200),
            const Text(
                'This text is here to cause an overflow error when the keyboard is displayed'),
          ],
        ),
      ),
    );
  }

  Future<void> _crashAfterRumSession(bool native) async {
    await DatadogSdk.instance.rum?.startView(_viewName, _viewName);
    await Future.delayed(const Duration(milliseconds: 100));

    if (native) {
      await NativeCrashPlugin().crashNative();
    } else {
      throw const OSError('This was unsupported');
    }
  }

  Future<void> _crashBeforeRumSession(bool native) async {
    await Future.delayed(const Duration(milliseconds: 100));

    if (native) {
      await NativeCrashPlugin().crashNative();
    } else {
      throw const OSError('This was unsupported');
    }
  }
}
