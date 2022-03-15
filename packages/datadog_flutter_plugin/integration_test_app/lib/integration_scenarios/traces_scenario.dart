// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:async';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
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

  void _simulateTraces() {
    var traces = DatadogSdk.instance.traces;
    if (traces != null) {
      viewLoadingSpan = traces.startRootSpan('view loading');
      viewLoadingSpan?.setActive();

      viewLoadingSpan?.setBaggageItem('class', runtimeType.toString());

      dataDownloadingSpan =
          traces.startSpan('data downloading', resourceName: 'GET /image.png');
      dataDownloadingSpan?.setTag('data.kind', 'image');
      dataDownloadingSpan?.setTag('data.url', 'https://example.com/image.png');
      dataDownloadingSpan?.setActive();

      unawaited(_simulateDataDownload());
    }
  }

  Future<void> _simulateDataDownload() async {
    await Future.delayed(const Duration(milliseconds: 300));
    dataDownloadingSpan?.log({
      OTLogFields.message: 'download progress',
      'progress': 0.99,
    });
    dataDownloadingSpan?.finish();

    var traces = DatadogSdk.instance.traces;
    if (traces != null) {
      final dataPresentationSpan = traces.startSpan('data presentation');
      dataPresentationSpan.setActive();
      await Future.delayed(const Duration(milliseconds: 60));
      dataPresentationSpan.setTag(OTTags.error, true);
      final stackTrace = StackTrace.current;
      dataPresentationSpan.setError(
        PlatformException(
          code: 'DatadogSdkPlugin',
          message: 'Failed for reasons.',
        ),
        stackTrace,
      );
      dataPresentationSpan.finish();
    }

    viewLoadingSpan?.finish();
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
