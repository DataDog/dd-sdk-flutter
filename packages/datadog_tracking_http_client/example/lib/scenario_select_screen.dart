// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'package:flutter/material.dart';

import 'http/rum_http_instrumentation_scenario.dart';
import 'io_http_client/rum_http_client_instrumentation_scenario.dart';

class ScenarioSelectScreen extends StatelessWidget {
  const ScenarioSelectScreen({Key? key}) : super(key: key);

  void _onSelectHttpClient(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: 'rum_io_instrumentation'),
      builder: (context) => const RumHttpClientInstrumentationScenario(),
    ));
  }

  void _onSelectHttp(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: 'rum_http_instrumentation'),
      builder: (context) => const RumHttpInstrumentationScenario(),
    ));
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
          ],
        ),
      ),
    );
  }
}
