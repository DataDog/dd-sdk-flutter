import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:datadog_sdk/traces/ddtraces.dart';
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

      viewLoadingSpan?.setBaggageItem('class', runtimeType.toString());

      dataDownloadingSpan = await traces.startSpan('data downloading');
      await dataDownloadingSpan?.setTag('data.kind', 'image');
      await dataDownloadingSpan?.setTag(
          'data.url', 'https://example.com/image.png');
      await dataDownloadingSpan?.setTag(DdTags.resource, 'GET /image.png');

      _simulateDataDownload();
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
      final dataPresentationSpan = await traces.startSpan('data presentation');
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
