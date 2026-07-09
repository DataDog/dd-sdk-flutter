// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../custom_card.dart';
import 'instrumentation_second_screen.dart';

class InstrumentationScenario extends StatefulWidget {
  final Dio dio;

  const InstrumentationScenario({super.key, required this.dio});

  @override
  State<InstrumentationScenario> createState() =>
      _InstrumentationScenarioState();
}

class _InstrumentationScenarioState extends State<InstrumentationScenario> {
  final images = [
    'https://picsum.photos/200',
    'https://placehold.co/200x200.png',
  ];

  bool _doneWait = false;

  @override
  void initState() {
    super.initState();
    _go();
  }

  void _go() async {
    // This is only for the sake of integration tests. Without it, Flutter
    // switches routes and starts loading images prior to `pumpAndSettle`
    // allowing sending the view change to RUM.
    await Future.delayed(const Duration(milliseconds: 10));
    setState(() {
      _doneWait = true;
    });
  }

  void _onTap(int index) {
    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'second_screen'),
            builder: (_) {
              return InstrumentationSecondScreen(dio: widget.dio);
            },
          ),
        );
        break;
    }
  }

  void _sendTraceableLog() async {
    final clientToken = dotenv.get('DD_API_KEY', fallback: '');
    final apiAppKey = dotenv.get('DD_APPLICATION_API_KEY', fallback: '');

    var response = await widget.dio.getUri(
      Uri.parse('https://api.datadoghq.com/api/v2/logs/events'),
      options: Options(
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          'DD-API-KEY': clientToken,
          'DD-APPLICATION-KEY': apiAppKey,
        },
      ),
    );

    // ignore: avoid_print
    print('Got status response: $response');
  }

  @override
  Widget build(BuildContext context) {
    return _doneWait
        ? Scaffold(
            appBar: AppBar(title: const Text('Auto RUM')),
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
          )
        : const Placeholder();
  }
}
