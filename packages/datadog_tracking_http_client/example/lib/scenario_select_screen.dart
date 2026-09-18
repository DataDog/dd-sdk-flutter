// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_tracking_http_client/datadog_tracking_http_client.dart';
import 'package:flutter/material.dart';

import 'clients/dio_client.dart';
import 'clients/http_package_client.dart';
import 'clients/io_client.dart';
import 'screens/background_isolate_screen.dart';
import 'screens/instrumentation_scenario.dart';

class ScenarioSelectScreen extends StatelessWidget {
  const ScenarioSelectScreen({Key? key}) : super(key: key);

  void _onSelectHttpClient(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: 'rum_io_instrumentation'),
      builder: (context) => InstrumentationScenario(client: IoClient()),
    ));
  }

  void _onSelectHttp(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: 'rum_http_instrumentation'),
      builder: (context) {
        DatadogClient client = DatadogClient(datadogSdk: DatadogSdk.instance);
        return InstrumentationScenario(client: HttpPackageClient(client));
      },
    ));
  }

  void _onSelectDio(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: 'rum_dio_instrumentation'),
      builder: (context) => InstrumentationScenario(client: DioClient()),
    ));
  }

  void _onSelectBackgroundIsolate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
          settings: const RouteSettings(name: 'rum_io_background_isolate'),
          builder: (context) => const BackgroundIsolateScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scenario Select'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ListTile(
              title: const Text('HttpClient (dart:io) Override'),
              onTap: () => _onSelectHttpClient(context),
            ),
            ListTile(
              title: const Text('http.Client Override'),
              onTap: () => _onSelectHttp(context),
            ),
            ListTile(
              title: const Text('Dio Usage'),
              onTap: () => _onSelectDio(context),
            ),
            ListTile(
              title: const Text('Background Isolate Fetch'),
              onTap: () => _onSelectBackgroundIsolate(context),
            )
          ],
        ),
      ),
    );
  }
}
