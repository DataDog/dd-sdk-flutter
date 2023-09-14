// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';

import '../main.dart';

class KioskIntegrationScenario extends StatefulWidget {
  const KioskIntegrationScenario({Key? key}) : super(key: key);

  @override
  State<KioskIntegrationScenario> createState() =>
      _KioskIntegrationScenarioState();
}

class _KioskIntegrationScenarioState extends State<KioskIntegrationScenario>
    implements RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void didPushNext() {}

  @override
  void didPopNext() {
    DatadogSdk.instance.rum?.stopSession();
  }

  void _startSession() {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (context) {
      return const KioskTrackedStreen();
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kiosk Splash Screen')),
      body: Center(
        child: ElevatedButton(
          onPressed: _startSession,
          child: const Text('Start Session'),
        ),
      ),
    );
  }
}

class KioskTrackedStreen extends StatefulWidget {
  const KioskTrackedStreen({Key? key}) : super(key: key);

  @override
  State<KioskTrackedStreen> createState() => _KioskTrackedStreenState();
}

class _KioskTrackedStreenState extends State<KioskTrackedStreen>
    implements RouteAware {
  final String viewKey = 'KioskTrackedStreen';

  bool _resourceDownloadInProgress = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPush() {
    DatadogSdk.instance.rum?.startView(viewKey);
  }

  @override
  void didPop() {
    DatadogSdk.instance.rum?.stopView(viewKey);
  }

  @override
  void didPushNext() {
    DatadogSdk.instance.rum?.stopView(viewKey);
  }

  @override
  void didPopNext() {
    DatadogSdk.instance.rum?.startView(viewKey);
  }

  Future<void> _downloadResource() async {
    setState(() {
      _resourceDownloadInProgress = true;
    });

    const resourceKey = '/resource/1';
    DatadogSdk.instance.rum?.startResourceLoading(
        resourceKey, RumHttpMethod.get, 'https://foo.com/resources/1');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    DatadogSdk.instance.rum
        ?.stopResource(resourceKey, 200, RumResourceType.image);

    setState(() {
      _resourceDownloadInProgress = false;
    });
  }

  void _userAction() {
    DatadogSdk.instance.rum?.addAction(RumActionType.tap, 'Kiosk User Action');
  }

  void _finishTest() {
    Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const TestFinishedWaitScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiosk Tracked Screen'),
      ),
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _resourceDownloadInProgress ? null : _downloadResource,
              child: _resourceDownloadInProgress
                  ? const CircularProgressIndicator()
                  : const Text('Download Resource'),
            ),
            ElevatedButton(
              onPressed: _userAction,
              child: const Text('User Action'),
            ),
            ElevatedButton(
              onPressed: _finishTest,
              child: const Text('Finish Test'),
            ),
          ],
        ),
      ),
    );
  }
}

class TestFinishedWaitScreen extends StatefulWidget {
  const TestFinishedWaitScreen({Key? key}) : super(key: key);

  @override
  State<TestFinishedWaitScreen> createState() => _TestFinishedWaitScreenState();
}

class _TestFinishedWaitScreenState extends State<TestFinishedWaitScreen>
    implements RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPush() {
    DatadogSdk.instance.rum?.startView('TestFinished');
    // Immediately stop thew view so Android will send the results.
    DatadogSdk.instance.rum?.stopView('TestFinished');
  }

  @override
  void didPop() {}

  @override
  void didPushNext() {}

  @override
  void didPopNext() {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Complete'),
      ),
      body: const Center(
        child: Text('Test is complete.'),
      ),
    );
  }
}
