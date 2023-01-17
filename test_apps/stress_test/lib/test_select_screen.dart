// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'package:flutter/material.dart';

class TestSelectScreen extends StatelessWidget {
  const TestSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datadog Stress Test')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Large Payload Test'),
            onTap: () {},
          ),
          ListTile(
            title: const Text('High Frequency Test'),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Large Payload + High Frequency'),
            onTap: () {},
          )
        ],
      ),
    );
  }
}
