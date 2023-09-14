// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'dart:math';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
// ignore: implementation_imports
import 'package:datadog_flutter_plugin/src/datadog_sdk_method_channel.dart';
import 'package:flutter/material.dart';

import '../payload_creators.dart';

@immutable
class PerformanceMeasure {
  final double minTimeMs;
  final double maxTimeMs;
  final double avgTimeMs;

  const PerformanceMeasure({
    required this.minTimeMs,
    required this.maxTimeMs,
    required this.avgTimeMs,
  });

  static PerformanceMeasure fromEncoded(Map<Object?, Object?> encoded) {
    return PerformanceMeasure(
      minTimeMs: encoded['minMs'] as double,
      maxTimeMs: encoded['maxMs'] as double,
      avgTimeMs: encoded['avgMs'] as double,
    );
  }

  @override
  String toString() {
    return '''Performance:
  min: ${minTimeMs.toStringAsFixed(2)}
  max: ${maxTimeMs.toStringAsFixed(2)}
  avg: ${avgTimeMs.toStringAsFixed(2)}
    ''';
  }
}

class LargePayloadTest extends StatefulWidget {
  const LargePayloadTest({super.key});

  @override
  State<LargePayloadTest> createState() => _LargePayloadTestState();
}

class _LargePayloadTestState extends State<LargePayloadTest>
    with RouteAware, DatadogRouteAwareMixin {
  final random = Random();

  var payloads = 5;
  var payloadDelay = 5.0;

  var sendingPayloads = false;
  int? currentPayload;
  var status = '';
  var perfStatus = '';

  bool isCanceled = false;

  @override
  void initState() {
    super.initState();

    final viewContext = generateLargeContext();
    for (final entry in viewContext.entries) {
      DatadogSdk.instance.rum?.addAttribute(entry.key, entry.value);
    }
  }

  @override
  void dispose() {
    isCanceled = true;

    super.dispose();
  }

  Future<void> _sendPayloads() async {
    setState(() {
      sendingPayloads = true;
    });

    for (int i = 0; i < payloads; ++i) {
      final eventContext = generateLargeContext();
      var eventType = random.nextInt(2);
      var eventTypeString = '';
      switch (eventType) {
        case 0:
          DatadogSdk.instance.rum
              ?.addUserAction(RumActionType.tap, 'User Action', eventContext);
          eventTypeString = 'Action';
          break;
        case 1:
          DatadogSdk.instance.rum?.addErrorInfo(
              'Fake Error', RumErrorSource.source,
              attributes: eventContext);
          eventTypeString = 'Error';
          break;
      }

      status = 'Sent payload ${i + 1} / $payloads (an $eventTypeString)';

      await Future<void>.delayed(
          Duration(milliseconds: (payloadDelay * 1000).toInt()));
      if (isCanceled) {
        _finish();
      }
      await _updateMapperPerf();
    }

    _finish();
  }

  void _cancel() {
    setState(() {
      isCanceled = true;
    });
  }

  void _finish() {
    if (mounted) {
      setState(() {
        sendingPayloads = false;
        isCanceled = false;
        status = 'Done';
      });
      _updateMapperPerf();
    }
  }

  Future<void> _updateMapperPerf() async {
    final platform = DatadogSdk.instance.platform as DatadogSdkMethodChannel;
    var perfMap = await platform.getInternalVar('mapperPerformance')
        as Map<Object?, Object?>?;
    if (perfMap != null && mounted) {
      final totalPerf = PerformanceMeasure.fromEncoded(
          perfMap['total'] as Map<Object?, Object?>);
      final mainThreadPerf = PerformanceMeasure.fromEncoded(
          perfMap['mainThread'] as Map<Object?, Object?>);
      final timeouts = perfMap['mapperTimeouts'] as int;
      setState(() {
        perfStatus =
            'Total $totalPerf\nMainThread $mainThreadPerf\nTimeouts: $timeouts';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Large Payload Test')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Payloads'),
                const SizedBox.square(
                  dimension: 10,
                ),
                Expanded(
                  child: Slider(
                    value: payloads.toDouble(),
                    min: 1,
                    label: payloads.toString(),
                    divisions: 100,
                    max: 100,
                    onChanged: !sendingPayloads
                        ? (value) {
                            setState(() {
                              payloads = value.toInt();
                            });
                          }
                        : null,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Payload Delay'),
                const SizedBox.square(
                  dimension: 10,
                ),
                Expanded(
                  child: Slider(
                    value: payloadDelay,
                    min: 1,
                    label: payloadDelay.toStringAsFixed(1),
                    divisions: 100,
                    max: 100,
                    onChanged: !sendingPayloads
                        ? (value) {
                            setState(() {
                              payloadDelay = value;
                            });
                          }
                        : null,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: !sendingPayloads ? _sendPayloads : null,
                  child: const Text('Send'),
                ),
                const SizedBox(
                  width: 10,
                ),
                ElevatedButton(
                  onPressed: sendingPayloads ? _cancel : null,
                  child: const Text('Cancel'),
                )
              ],
            ),
            Text(status),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Text(perfStatus),
            )
          ],
        ),
      ),
    );
  }
}
