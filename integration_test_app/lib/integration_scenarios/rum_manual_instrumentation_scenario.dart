// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:async';

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:flutter/material.dart';

import '../main.dart';

const fakeRootUrl = 'https://fake_url';

class RumManualInstrumentationScenario extends StatefulWidget {
  const RumManualInstrumentationScenario({Key? key}) : super(key: key);

  @override
  _RumManualInstrumentationScenarioState createState() =>
      _RumManualInstrumentationScenarioState();
}

class _RumManualInstrumentationScenarioState
    extends State<RumManualInstrumentationScenario> implements RouteAware {
  bool _contentReady = false;

  @override
  void initState() {
    super.initState();

    _viewKey = widget.runtimeType.toString();
    DatadogSdk.instance.rum?.addAttribute('onboarding_stage', 1);

    _fakeLoading();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  late String _viewKey;

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
  }

  @override
  void didPushNext() {
    DatadogSdk.instance.rum?.stopView(_viewKey);
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
    DatadogSdk.instance.rum?.addTiming('content-ready');
  }

  void _simulateResourceDownload() async {
    final rum = DatadogSdk.instance.rum;

    rum?.addTiming('first-interaction');
    rum?.addUserAction(RumUserActionType.tap, 'Tapped Download');

    var simulatedResourceKey1 = '/resource/1';
    var simulatedResourceKey2 = '/resource/2';

    rum?.startResourceLoading(simulatedResourceKey1, RumHttpMethod.get,
        '$fakeRootUrl$simulatedResourceKey1');
    rum?.startResourceLoading(simulatedResourceKey2, RumHttpMethod.get,
        '$fakeRootUrl$simulatedResourceKey2');

    await Future.delayed(const Duration(milliseconds: 100));
    rum?.stopResourceLoading(simulatedResourceKey1, 200, RumResourceType.image);
    rum?.stopResourceLoadingWithErrorInfo(
        simulatedResourceKey2, 'Status code 400');

    setState(() {
      _contentReady = true;
    });
  }

  Future<void> _onNextTapped() async {
    DatadogSdk.instance.rum
        ?.addUserAction(RumUserActionType.tap, 'Next Screen');
    unawaited(Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RumManualInstrumentation2(),
      ),
    ));
  }
}

class RumManualInstrumentation2 extends StatefulWidget {
  const RumManualInstrumentation2({Key? key}) : super(key: key);

  @override
  _RumManualInstrumentation2State createState() =>
      _RumManualInstrumentation2State();
}

class _RumManualInstrumentation2State extends State<RumManualInstrumentation2>
    implements RouteAware {
  bool _nextReady = false;
  late String _viewKey;
  final _viewName = 'SecondManualRumView';

  @override
  void initState() {
    super.initState();

    _viewKey = widget.runtimeType.toString();
    _simulateActions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPop() {
    DatadogSdk.instance.rum?.stopView(_viewKey);
  }

  @override
  void didPopNext() {
    DatadogSdk.instance.rum?.startView(_viewKey, _viewName);
  }

  @override
  void didPush() {
    DatadogSdk.instance.rum?.startView(_viewKey, _viewName);
  }

  @override
  void didPushNext() {
    DatadogSdk.instance.rum?.stopView(_viewKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual RUM 2'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _nextReady ? _onNextTapped : null,
          child: const Text('Next Screen'),
        ),
      ),
    );
  }

  Future<void> _simulateActions() async {
    await Future.delayed(const Duration(seconds: 1));
    DatadogSdk.instance.rum
        ?.addErrorInfo('Simulated view error', RumErrorSource.source);
    DatadogSdk.instance.rum
        ?.startUserAction(RumUserActionType.scroll, 'User Scrolling');
    await Future.delayed(const Duration(seconds: 2));
    DatadogSdk.instance.rum?.stopUserAction(
        RumUserActionType.scroll, 'User Scrolling', {'scroll_distance': 12.2});

    setState(() {
      _nextReady = true;
    });
  }

  void _onNextTapped() {
    DatadogSdk.instance.rum
        ?.addUserAction(RumUserActionType.tap, 'Next Screen');
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

class _RumManualInstrumentation3State extends State<RumManualInstrumentation3>
    implements RouteAware {
  final String _viewKey = 'screen3-widget';
  final String _viewName = 'ThirdManualRumView';

  @override
  void initState() {
    super.initState();

    _simulateActions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPop() {
    DatadogSdk.instance.rum?.stopView(_viewKey);
  }

  @override
  void didPopNext() {
    DatadogSdk.instance.rum?.startView(_viewKey, _viewName);
  }

  @override
  void didPush() {
    DatadogSdk.instance.rum?.removeAttribute('onboarding_stage');
    DatadogSdk.instance.rum?.startView(_viewKey, _viewName);
  }

  @override
  void didPushNext() {
    DatadogSdk.instance.rum?.stopView(_viewKey);
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

  void _simulateActions() async {
    DatadogSdk.instance.rum?.addTiming('content-ready');

    // Stop the view to make sure it doesn't get held over to the next session.
    await Future.delayed(const Duration(milliseconds: 500));
    DatadogSdk.instance.rum?.stopView(_viewKey);
  }
}
