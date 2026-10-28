// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_webview_tracking/datadog_webview_tracking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../browser_page.dart';

/// The page is loaded with this base URL, so it must be one of the hosts
/// passed to `trackDatadogEvents`.
const webViewHost = 'webview-session-replay.example';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  String _diagnostics = 'Waiting for the page…';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'Diagnostics',
        onMessageReceived: (message) {
          debugPrint('[WEBVIEW-SR] ${message.message}');
          if (mounted) setState(() => _diagnostics = message.message);
        },
      );

    // Must run before the page loads: it installs the script that defines
    // `window.DatadogEventBridge`, which takes effect on the next navigation.
    _controller.trackDatadogEvents(DatadogSdk.instance, [webViewHost]);
    _controller.loadHtmlString(
      browserPage(
        applicationId: dotenv.get('DD_APPLICATION_ID', fallback: ''),
        clientToken: dotenv.get('DD_CLIENT_TOKEN', fallback: ''),
        env: dotenv.get('DD_ENV', fallback: ''),
      ),
      baseUrl: 'https://$webViewHost/',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WebView screen')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.black87,
            padding: const EdgeInsets.all(8),
            child: Text(
              _diagnostics,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontFamily: 'Courier',
                fontSize: 11,
              ),
            ),
          ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
