// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:async';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../main.dart';

const fakeRootUrl = 'https://fake_url';

class RumManualInstrumentationScenario extends StatefulWidget {
  const RumManualInstrumentationScenario({Key? key}) : super(key: key);

  @override
  State<RumManualInstrumentationScenario> createState() =>
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
    await Future<void>.delayed(const Duration(milliseconds: 50));
    DatadogSdk.instance.rum?.addTiming('content-ready');
    DatadogSdk.instance.rum?.addViewLoadingTime();

    DatadogSdk.instance.setUserInfo(
        id: 'fake-id', name: 'Johnny Silverhand', email: 'fake@datadoghq.com');
  }

  void _simulateResourceDownload() async {
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

    setState(() {
      _contentReady = true;
    });
  }

  Future<void> _onNextTapped() async {
    DatadogSdk.instance.rum?.addAction(RumActionType.tap, 'Next Screen');
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
  State<RumManualInstrumentation2> createState() =>
      _RumManualInstrumentation2State();
}

class _RumManualInstrumentation2State extends State<RumManualInstrumentation2>
    implements RouteAware {
  bool _longTaskReady = false;
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

    DatadogSdk.instance.rum?.addFeatureFlagEvaluation('mock_flag_a', false);
    DatadogSdk.instance.rum
        ?.addFeatureFlagEvaluation('mock_flag_b', 'mock_value');
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
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _longTaskReady ? _triggerLongTask : null,
              child: const Text('Trigger Long Task'),
            ),
            ElevatedButton(
              onPressed: _nextReady ? _onNextTapped : null,
              child: const Text('Next Screen'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _simulateActions() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    DatadogSdk.instance.rum?.addErrorInfo(
      'Simulated view error',
      RumErrorSource.source,
      attributes: {
        'custom_attribute': 'my_attribute',
        DatadogAttributes.errorFingerprint: 'custom-fingerprint',
      },
    );
    DatadogSdk.instance.rum
        ?.startAction(RumActionType.scroll, 'User Scrolling');
    await Future<void>.delayed(const Duration(seconds: 2));
    DatadogSdk.instance.rum?.stopAction(
        RumActionType.scroll, 'User Scrolling', {'scroll_distance': 12.2});

    setState(() {
      _longTaskReady = true;
    });
  }

  void _triggerLongTask() {
    final doneTime = DateTime.now().add(const Duration(milliseconds: 500));
    while (DateTime.now().compareTo(doneTime) < 0) {}
    setState(() {
      _nextReady = true;
    });
  }

  void _onNextTapped() {
    DatadogSdk.instance.rum?.addAction(RumActionType.tap, 'Next Screen');
    Navigator.push<void>(
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
  State<RumManualInstrumentation3> createState() =>
      _RumManualInstrumentation3State();
}

class _RumManualInstrumentation3State extends State<RumManualInstrumentation3>
    implements RouteAware {
  final String _viewKey = 'screen3-widget';
  final String _viewName = 'ThirdManualRumView';

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

    DatadogSdk.instance.rum?.addAttribute('nesting_attribute', {
      'testing_attribute': {
        'nested_1': 123,
        'nested_null': null,
      },
    });

    _simulateActions();
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
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (kIsWeb) {
      // Since web doesn't have a 'stopView' method, send a new view instead
      DatadogSdk.instance.rum?.startView('blankView');
    } else {
      DatadogSdk.instance.rum?.stopView(_viewKey);
    }
  }
}
