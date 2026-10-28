// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:flutter/material.dart';

import 'webview_screen.dart';

/// `--dart-define=AUTO_OPEN_WEBVIEW=true` opens the WebView screen 5 seconds
/// after launch, for unattended runs.
const autoOpenWebView = bool.fromEnvironment('AUTO_OPEN_WEBVIEW');

/// `--dart-define=AUTO_POP_WEBVIEW=true` also goes back to this screen 20
/// seconds later, so the replay shows the WebView being hidden.
const autoPopWebView = bool.fromEnvironment('AUTO_POP_WEBVIEW');

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _taps = 0;

  @override
  void initState() {
    super.initState();
    if (autoOpenWebView) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _openWebView();
      });
      if (autoPopWebView) {
        Future.delayed(const Duration(seconds: 25), () {
          if (mounted) Navigator.of(context).maybePop();
        });
      }
    }
  }

  void _openWebView() {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'WebViewScreen'),
        builder: (_) => const WebViewScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter screen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'This screen is recorded by Flutter Session Replay. Open the '
            'WebView screen: its web content joins the same replay.',
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(labelText: 'Flutter text field'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => setState(() => _taps++),
            child: Text('Flutter taps: $_taps'),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: _openWebView,
            child: const Text('Open WebView screen'),
          ),
        ],
      ),
    );
  }
}
