// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late DatadogNavigationObserver datadogObserver;

  @override
  void initState() {
    super.initState();
    datadogObserver =
        DatadogNavigationObserver(datadogSdk: DatadogSdk.instance);
  }

  @override
  Widget build(BuildContext context) {
    return DatadogNavigationObserverProvider(
      navObserver: datadogObserver,
      child: MaterialApp(
        navigatorObservers: [datadogObserver],
        home: const HomeScreen(),
      ),
    );
  }
}
