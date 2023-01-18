// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';

import 'large_payload_test.dart';

class TestSelectScreen extends StatefulWidget {
  const TestSelectScreen({super.key});

  @override
  State<TestSelectScreen> createState() => _TestSelectScreenState();
}

class _TestSelectScreenState extends State<TestSelectScreen>
    with RouteAware, DatadogRouteAwareMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datadog Stress Test')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Large Payload Test'),
            trailing: const Icon(Icons.arrow_right_sharp),
            onTap: () {
              Navigator.push<void>(context,
                  MaterialPageRoute(builder: (_) => const LargePayloadTest()));
            },
          ),
          ListTile(
            title: const Text('High Frequency Test'),
            trailing: const Icon(Icons.arrow_right_sharp),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Large Payload + High Frequency'),
            trailing: const Icon(Icons.arrow_right_sharp),
            onTap: () {},
          )
        ],
      ),
    );
  }
}
