// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:async';

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TracesScenario extends StatefulWidget {
  const TracesScenario({Key? key}) : super(key: key);

  @override
  _TracesScenarioState createState() => _TracesScenarioState();
}

class _TracesScenarioState extends State<TracesScenario> {
  DdSpan? viewLoadingSpan;
  DdSpan? dataDownloadingSpan;

  @override
  void initState() {
    super.initState();

    _simulateTraces();
  }

  Future<void> _simulateTraces() async {
    var traces = DatadogSdk.instance.traces;
    if (traces != null) {
      viewLoadingSpan = await traces.startRootSpan('view loading');
      await viewLoadingSpan?.setActive();

      await viewLoadingSpan?.setBaggageItem('class', runtimeType.toString());

      dataDownloadingSpan = await traces.startSpan('data downloading',
          resourceName: 'GET /image.png');
      await dataDownloadingSpan?.setTag('data.kind', 'image');
      await dataDownloadingSpan?.setTag(
          'data.url', 'https://example.com/image.png');
      await dataDownloadingSpan?.setActive();

      unawaited(_simulateDataDownload());
    }
  }

  Future<void> _simulateDataDownload() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await dataDownloadingSpan?.log({
      OTLogFields.message: 'download progress',
      'progress': 0.99,
    });
    await dataDownloadingSpan?.finish();

    var traces = DatadogSdk.instance.traces;
    if (traces != null) {
      final dataPresentationSpan = await traces.startSpan('data presentation');
      await dataPresentationSpan.setActive();
      await Future.delayed(const Duration(milliseconds: 60));
      await dataPresentationSpan.setTag(OTTags.error, true);
      await dataPresentationSpan.setError(PlatformException(
          code: 'DatadogSdkPlugin', message: 'Failed for reasons.'));
      await dataPresentationSpan.finish();
    }

    await viewLoadingSpan?.finish();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traces Scenario'),
      ),
      body: Container(),
    );
  }
}
