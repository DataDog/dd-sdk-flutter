// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';

import 'rum_webview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with RouteAware, DatadogRouteAwareMixin {
  void _openWebView() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (context) => const RumWebViewScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WebView Example Home')),
      body: Center(
        child: ElevatedButton(
          onPressed: _openWebView,
          child: const Text('Open WebView'),
        ),
      ),
    );
  }
}
