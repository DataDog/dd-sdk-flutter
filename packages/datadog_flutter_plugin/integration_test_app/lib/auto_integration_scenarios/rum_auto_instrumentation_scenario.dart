// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:flutter/material.dart';

import 'custom_card.dart';
import 'rum_auto_instrumentation_second_screen.dart';

class RumAutoInstrumentationScenario extends StatefulWidget {
  const RumAutoInstrumentationScenario({Key? key}) : super(key: key);

  @override
  State<RumAutoInstrumentationScenario> createState() =>
      _RumAutoInstrumentationScenarioState();
}

class _RumAutoInstrumentationScenarioState
    extends State<RumAutoInstrumentationScenario> {
  final images = [
    'https://placekitten.com/300/300',
    'https://imgix.datadoghq.com/img/about/presskit/kit/press_kit.png'
  ];

  @override
  void initState() {
    super.initState();
  }

  void _onTap(int index) {
    switch (index) {
      case 0:
        Navigator.push<void>(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(
              name: 'rum_second_screen',
            ),
            builder: (_) {
              return const RumAutoInstrumentationSecondScreen();
            },
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto RUM'),
      ),
      body: ListView.builder(
        itemCount: 2,
        itemBuilder: (context, index) {
          final item = images[index];
          return CustomCard(
            image: item,
            text: 'Item $index',
            onTap: () => _onTap(index),
          );
        },
      ),
    );
  }
}
