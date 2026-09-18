// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';

import 'unnamed_screen.dart';

class NamedScreen extends StatefulWidget {
  const NamedScreen({super.key});

  @override
  State<NamedScreen> createState() => _NamedScreenState();
}

class _NamedScreenState extends State<NamedScreen>
    with RouteAware, DatadogRouteAwareMixin {
  void _onNextScreen() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const UnnamedScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Named Screen')),
      body: Center(
          child: ElevatedButton(
        onPressed: _onNextScreen,
        child: const Text('Next Screen'),
      )),
    );
  }
}
