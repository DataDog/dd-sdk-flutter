// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../clients/abstract_client.dart';
import '../custom_card.dart';
import 'instrumentation_second_screen.dart';

class InstrumentationScenario extends StatefulWidget {
  final AbstractClient client;

  const InstrumentationScenario({Key? key, required this.client})
    : super(key: key);

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
            settings: const RouteSettings(name: 'rum_io_second_screen'),
            builder: (_) {
              return InstrumentationSecondScreen(client: widget.client);
            },
          ),
        );
        break;
    }
  }

  void _sendTraceableLog() async {
    final clientToken = dotenv.get('DD_API_KEY', fallback: '');
    final apiAppKey = dotenv.get('DD_APPLICATION_API_KEY', fallback: '');

    var response = await widget.client.get(
      Uri.parse('https://api.datadoghq.com/api/v2/logs/events'),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
        'DD-API-KEY': clientToken,
        'DD-APPLICATION-KEY': apiAppKey,
      },
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
