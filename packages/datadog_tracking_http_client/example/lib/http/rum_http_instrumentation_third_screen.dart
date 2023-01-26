// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';

class RumHttpInstrumentationThirdScreen extends StatefulWidget {
  const RumHttpInstrumentationThirdScreen({Key? key}) : super(key: key);

  @override
  State<RumHttpInstrumentationThirdScreen> createState() =>
      _RumHttpInstrumentationThirdScreenState();
}

class _RumHttpInstrumentationThirdScreenState
    extends State<RumHttpInstrumentationThirdScreen> {
  @override
  void initState() {
    super.initState();

    DatadogSdk.instance.rum?.addTiming('content-ready');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Third Screen'),
      ),
      body: const Center(
        child: Text('Third Screen'),
      ),
    );
  }
}
