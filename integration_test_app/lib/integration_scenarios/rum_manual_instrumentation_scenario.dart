// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:datadog_sdk/rum/ddrum.dart';
import 'package:flutter/material.dart';

const fakeRootUrl = 'https://fake_url';

class RumManualInstrumentationScenario extends StatefulWidget {
  const RumManualInstrumentationScenario({Key? key}) : super(key: key);

  @override
  _RumManualInstrumentationScenarioState createState() =>
      _RumManualInstrumentationScenarioState();
}

class _RumManualInstrumentationScenarioState
    extends State<RumManualInstrumentationScenario> {
  bool _contentReady = false;

  @override
  void initState() {
    super.initState();

    DatadogSdk().ddRum?.startView(widget.runtimeType.toString());

    _fakeLoading();
  }

  @override
  void dispose() {
    DatadogSdk().ddRum?.stopView(widget.runtimeType.toString());

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual RUM'),
      ),
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _simulateResourceDownload,
              child: const Text('Download Resource'),
            ),
            ElevatedButton(
              onPressed: _contentReady ? _onNextTapped : null,
              child: const Text('Next Screen'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fakeLoading() async {
    await Future.delayed(const Duration(milliseconds: 50));
    DatadogSdk().ddRum?.addTiming('content-ready');
  }

  void _simulateResourceDownload() async {
    final rum = DatadogSdk().ddRum;

    await rum?.addTiming('first-interaction');

    var simulatedResourceKey1 = '/resource/1';
    var simulatedResourceKey2 = '/resource/2';

    rum?.startResourceLoading(simulatedResourceKey1, RumHttpMethod.get,
        '$fakeRootUrl$simulatedResourceKey1');
    rum?.startResourceLoading(simulatedResourceKey2, RumHttpMethod.get,
        '$fakeRootUrl$simulatedResourceKey2');

    await Future.delayed(const Duration(milliseconds: 100));
    await rum?.stopResourceLoading(
        simulatedResourceKey1, 200, RumResourceType.image);
    await rum?.stopResourceLoadingWithErrorInfo(
        simulatedResourceKey2, 'Status code 400');

    setState(() {
      _contentReady = true;
    });
  }

  void _onNextTapped() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RumManualInstrumentation2(),
      ),
    );
  }
}

class RumManualInstrumentation2 extends StatefulWidget {
  const RumManualInstrumentation2({Key? key}) : super(key: key);

  @override
  _RumManualInstrumentation2State createState() =>
      _RumManualInstrumentation2State();
}

class _RumManualInstrumentation2State extends State<RumManualInstrumentation2> {
  @override
  void initState() {
    super.initState();

    DatadogSdk()
        .ddRum
        ?.startView(widget.runtimeType.toString(), 'SecondManualRumView');
    DatadogSdk()
        .ddRum
        ?.addErrorInfo('Simulated view error', RumErrorSource.source);
  }

  @override
  void dispose() {
    DatadogSdk().ddRum?.stopView(widget.runtimeType.toString());

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual RUM 2'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _onNextTapped,
          child: const Text('Next Screen'),
        ),
      ),
    );
  }

  void _onNextTapped() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RumManualInstrumentation3(),
      ),
    );
  }
}

class RumManualInstrumentation3 extends StatefulWidget {
  const RumManualInstrumentation3({Key? key}) : super(key: key);

  @override
  _RumManualInstrumentation3State createState() =>
      _RumManualInstrumentation3State();
}

class _RumManualInstrumentation3State extends State<RumManualInstrumentation3> {
  @override
  void initState() {
    super.initState();

    DatadogSdk().ddRum?.startView('screen3-widget', 'ThirdManualRumView');
    DatadogSdk().ddRum?.addTiming('content-ready');
  }

  @override
  void dispose() {
    super.dispose();

    DatadogSdk().ddRum?.stopView('screen3-widget');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual RUM 2'),
      ),
      body: const Center(
        child: Text('Everything is Awesome!'),
      ),
    );
  }
}
