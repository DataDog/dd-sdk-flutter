// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:isolate';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';

import '../main.dart';

const fakeRootUrl = 'https://fake_url';

class IsolateTrackingScenario extends StatefulWidget {
  const IsolateTrackingScenario({super.key});

  @override
  State<IsolateTrackingScenario> createState() =>
      _IsolateTrackingScenarioState();
}

class _IsolateTrackingScenarioState extends State<IsolateTrackingScenario>
    implements RouteAware {
  static const String _viewKey = 'IsolateTrackingScenario';

  String _statusText = 'Creating An Isolate';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPop() {
    DatadogSdk.instance.rum?.stopView(_viewKey);
  }

  @override
  void didPopNext() {
    DatadogSdk.instance.rum?.startView(_viewKey);
  }

  @override
  void didPush() {
    DatadogSdk.instance.rum?.startView(_viewKey);
    _spawnIsolate();
  }

  @override
  void didPushNext() {
    DatadogSdk.instance.rum?.stopView(_viewKey);
  }

  Future<void> _spawnIsolate() async {
    final receivePort = ReceivePort();
    receivePort.listen((message) {
      if (message is String) {
        setState(() {
          _statusText = message;
        });
      }
    });
    await Isolate.spawn(_backgroundWork, receivePort.sendPort);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Isolate Tracking'),
      ),
      body: Padding(
        padding: const EdgeInsetsGeometry.all(12),
        child: Column(children: [
          Text(_statusText),
        ]),
      ),
    );
  }
}

void _backgroundWork(SendPort port) async {
  await DatadogSdk.instance.attachToBackgroundIsolate();

  port.send('Sending log messages');

  final logger =
      DatadogSdk.instance.logs?.createLogger(DatadogLoggerConfiguration());
  logger?.info('Message from background isolate!');

  port.send('Fake Downloading resources');
  final rum = DatadogSdk.instance.rum;

  rum?.addTiming('first-interaction');
  rum?.addAction(RumActionType.tap, 'Tapped Download');

  var simulatedResourceKey1 = '/resource/1';
  var simulatedResourceKey2 = '/resource/2';

  rum?.startResource(simulatedResourceKey1, RumHttpMethod.get,
      '$fakeRootUrl$simulatedResourceKey1');
  rum?.startResource(simulatedResourceKey2, RumHttpMethod.get,
      '$fakeRootUrl$simulatedResourceKey2');

  await Future<void>.delayed(const Duration(milliseconds: 100));
  rum?.stopResource(simulatedResourceKey1, 200, RumResourceType.image);
  rum?.stopResourceWithErrorInfo(
      simulatedResourceKey2, 'Status code 400', 'ErrorLoading');

  logger?.warn('Finished with background isolate!');

  port.send('Done!');
}
