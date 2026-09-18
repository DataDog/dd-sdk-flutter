// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:isolate';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../scenario_config.dart';

class BackgroundIsolateScreen extends StatefulWidget {
  const BackgroundIsolateScreen({Key? key}) : super(key: key);

  @override
  State<BackgroundIsolateScreen> createState() =>
      _BackgroundIsolateScreentate();
}

class _BackgroundIsolateScreentate extends State<BackgroundIsolateScreen> {
  bool _performingWork = false;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
  }

  void _sendData() async {
    setState(() {
      _performingWork = true;
    });
    final receivePort = ReceivePort();
    receivePort.listen((message) {
      if (message is String) {
        setState(() {
          _statusText = message;
          if (message == 'Done') {
            _performingWork = false;
            receivePort.close();
          }
        });
      } else if (message is SendPort) {
        message.send(RumAutoInstrumentationScenarioConfig.instance);
      }
    });
    await Isolate.spawn(_backgroundWork, receivePort.sendPort);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto RUM'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _performingWork ? null : _sendData,
              child: const Text('Send Traceable Log'),
            ),
            Text(_statusText),
          ],
        ),
      ),
    );
  }
}

void _backgroundWork(SendPort port) async {
  await DatadogSdk.instance.attachToBackgroundIsolate();

  final receivePort = ReceivePort();
  receivePort.listen((message) async {
    if (message is RumAutoInstrumentationScenarioConfig) {
      await _performBackgroundFetch(message, port);
      receivePort.close();
    }
  });
  port.send(receivePort.sendPort);
}

Future<void> _performBackgroundFetch(
    RumAutoInstrumentationScenarioConfig config, SendPort port) async {
  port.send('Get First Party');
  await http.get(Uri.parse(config.firstPartyGetUrl));

  if (config.firstPartyPostUrl != null) {
    port.send('Post First Party');
    await http.post(Uri.parse(config.firstPartyPostUrl!));
  }

  port.send('Done');
}
