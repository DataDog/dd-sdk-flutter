// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'dart:io';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_tracking_http_client/datadog_tracking_http_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../custom_card.dart';
import 'rum_http_instrumentation_second_screen.dart';

class RumHttpInstrumentationScenario extends StatefulWidget {
  const RumHttpInstrumentationScenario({Key? key}) : super(key: key);

  @override
  State<RumHttpInstrumentationScenario> createState() =>
      _RumHttpInstrumentationScenarioState();
}

class _RumHttpInstrumentationScenarioState
    extends State<RumHttpInstrumentationScenario> {
  DatadogClient client = DatadogClient(datadogSdk: DatadogSdk.instance);

  // Note -- the fetch of these images will not be tracked when this,
  // scenario is run on its own, as they are not made through the http
  // package
  final images = [
    'https://placekitten.com/300/300',
    'https://imgix.datadoghq.com/img/about/presskit/kit/press_kit.png'
  ];

  @override
  void initState() {
    super.initState();
  }

  void _onTap(int index) {
    if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(
            name: 'rum_http_second_screen',
          ),
          builder: (_) {
            return RumHttpInstrumentationSecondScreen(
              client: client,
            );
          },
        ),
      );
    }
  }

  void _sendTraceableLog() async {
    final clientToken = dotenv.get('DD_API_KEY', fallback: '');
    final apiAppKey = dotenv.get('DD_APPLICATION_API_KEY', fallback: '');

    var response = await client.get(
      Uri.parse('https://api.datadoghq.com/api/v2/logs/events'),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
        'DD-API-KEY': clientToken,
        'DD-APPLICATION-KEY': apiAppKey,
      },
    );

    // ignore: avoid_print
    print('Got status response: ${response.statusCode}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto RUM'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            for (int i = 0; i < images.length; ++i)
              CustomCard(
                image: images[i],
                text: 'Item $i',
                onTap: () => _onTap(i),
              ),
            ElevatedButton(
              onPressed: _sendTraceableLog,
              child: const Text('Send Traceable Log'),
            ),
          ],
        ),
      ),
    );
  }
}
