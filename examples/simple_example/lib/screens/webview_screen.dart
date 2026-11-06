// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_webview_tracking/datadog_webview_tracking.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// The page is loaded with this base URL, so it must be one of the hosts
/// passed to `trackDatadogEvents`.
const webViewHost = 'webview.example';

/// A page running the Datadog Browser SDK with RUM and Session Replay.
///
/// Inside a tracked WebView the Browser SDK runs in bridge mode: it sends its
/// events and replay records to the native SDK instead of uploading them.
///
/// The page also reports what the bridge advertises, which is the quickest way
/// to check the setup: `capabilities` must be `["records"]` for the Browser SDK
/// to record a replay. The Browser SDK doesn't own the session in bridge mode,
/// so the `session` and `replay link` it shows are placeholders.
const _browserPage = 'assets/webview_page.html';

/// A WebView running the Datadog Browser SDK. Its RUM events join the app's
/// RUM session and, on iOS, its replay records join the app's Session Replay.
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
          debugPrint('[WEBVIEW] ${message.message}');
          if (mounted) setState(() => _diagnostics = message.message);
        },
      );

    // Must run before the page loads: it installs the script that defines
    // `window.DatadogEventBridge`, which takes effect on the next navigation.
    // Whether the Browser SDK sends replay records is also decided here, so
    // Session Replay is enabled at startup, before any WebView is tracked.
    // WebView tracking is only available on iOS and Android.
    if (_supportsWebViewTracking) {
      _controller.trackDatadogEvents(DatadogSdk.instance, [webViewHost]);
    }
    _loadPage();
  }

  static final _supportsWebViewTracking =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  /// Loads [_browserPage] with the app's Datadog configuration filled in.
  Future<void> _loadPage() async {
    final page = (await rootBundle.loadString(_browserPage))
        .replaceAll(
          '{{APPLICATION_ID}}',
          dotenv.get('DD_APPLICATION_ID', fallback: ''),
        )
        .replaceAll(
          '{{CLIENT_TOKEN}}',
          dotenv.get('DD_CLIENT_TOKEN', fallback: ''),
        )
        .replaceAll('{{ENV}}', dotenv.get('DD_ENV', fallback: ''));
    await _controller.loadHtmlString(page, baseUrl: 'https://$webViewHost/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WebView')),
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
