// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.
import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:flutter/material.dart';

class RumAutoInstrumentationThirdScreen extends StatefulWidget {
  const RumAutoInstrumentationThirdScreen({Key? key}) : super(key: key);

  @override
  _RumAutoInstrumentationThirdScreenState createState() =>
      _RumAutoInstrumentationThirdScreenState();
}

class _RumAutoInstrumentationThirdScreenState
    extends State<RumAutoInstrumentationThirdScreen>
    with RouteAware, DatadogRouteAwareMixin {
  @override
  void didPush() {
    super.didPush();

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
