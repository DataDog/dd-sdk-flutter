// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../custom_card.dart';
import 'rum_http_client_instrumentation_second_screen.dart';

class RumHttpClientInstrumentationScenario extends StatefulWidget {
  const RumHttpClientInstrumentationScenario({Key? key}) : super(key: key);

  @override
  State<RumHttpClientInstrumentationScenario> createState() =>
      _RumHttpClientInstrumentationScenarioState();
}

class _RumHttpClientInstrumentationScenarioState
    extends State<RumHttpClientInstrumentationScenario> {
  final images = [
    'https://picsum.photos/200',
    'https://imgix.datadoghq.com/img/about/presskit/kit/press_kit.png'
  ];

  @override
  void initState() {
    super.initState();
  }

  void _onTap(int index) {
    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(
              name: 'rum_io_second_screen',
            ),
            builder: (_) {
              return const RumHttpClientInstrumentationSecondScreen();
            },
          ),
        );
        break;
    }
  }

  void _sendTraceableLog() async {
    final clientToken = dotenv.get('DD_API_KEY', fallback: '');
    final apiAppKey = dotenv.get('DD_APPLICATION_API_KEY', fallback: '');

    var response = await http.get(
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
