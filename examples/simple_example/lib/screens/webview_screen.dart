// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_webview_tracking/datadog_webview_tracking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// The page is loaded with this base URL, so it must be one of the hosts
/// passed to `trackDatadogEvents`.
const webViewHost = 'webview.example';

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
    _controller.trackDatadogEvents(DatadogSdk.instance, [webViewHost]);
    _controller.loadHtmlString(
      _browserPage(
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

/// A page running the Datadog Browser SDK with RUM and Session Replay.
///
/// Inside a tracked WebView the Browser SDK runs in bridge mode: it sends its
/// events and replay records to the native SDK instead of uploading them.
///
/// The page also reports what the bridge advertises, which is the quickest way
/// to check the setup: `capabilities` must be `["records"]` for the Browser SDK
/// to record a replay. The Browser SDK doesn't own the session in bridge mode,
/// so the `session` and `replay link` it shows are placeholders.
String _browserPage({
  required String applicationId,
  required String clientToken,
  required String env,
}) =>
    '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <script src="https://www.datadoghq-browser-agent.com/us1/v6/datadog-rum.js"></script>
  <script>
    window.DD_RUM && window.DD_RUM.init({
      applicationId: '$applicationId',
      clientToken: '$clientToken',
      site: 'datadoghq.com',
      service: 'com.datadoghq.example.flutter.web',
      env: '$env',
      sessionSampleRate: 100,
      sessionReplaySampleRate: 100,
      trackUserInteractions: true,
    });
  </script>
  <style>
    body { font-family: -apple-system, sans-serif; margin: 16px; background: #f4f1fb; }
    h1 { font-size: 20px; }
    button, input { font-size: 16px; padding: 10px; margin: 6px 0; width: 100%; box-sizing: border-box; }
    #box { width: 60px; height: 60px; background: #7e57c2; border-radius: 8px; transition: transform .6s; }
    pre { background: #222; color: #9f9; padding: 8px; font-size: 11px; white-space: pre-wrap; word-break: break-all; }
  </style>
</head>
<body>
  <h1>Web content (Browser SDK)</h1>
  <p>Interact here, then find this page in the app's RUM session and Session Replay.</p>
  <input placeholder="Web text field">
  <button id="tap">Web taps: 0</button>
  <div id="box"></div>
  <pre id="diag">collecting…</pre>
  <script>
    var taps = 0, angle = 0;
    document.getElementById('tap').addEventListener('click', function () {
      taps++;
      this.textContent = 'Web taps: ' + taps;
      angle += 90;
      document.getElementById('box').style.transform = 'rotate(' + angle + 'deg)';
    });

    function report() {
      var bridge = window.DatadogEventBridge;
      var rum = window.DD_RUM;
      var ctx = rum && rum.getInternalContext ? rum.getInternalContext() : undefined;
      var lines = [
        'bridge: ' + (bridge ? 'present' : 'MISSING'),
        'capabilities: ' + (bridge && bridge.getCapabilities ? bridge.getCapabilities() : 'n/a'),
        'privacy: ' + (bridge && bridge.getPrivacyLevel ? bridge.getPrivacyLevel() : 'n/a'),
        'browser sdk: ' + (rum ? rum.version : 'NOT LOADED'),
        'session: ' + (ctx ? ctx.session_id : 'n/a'),
        'view: ' + (ctx && ctx.view ? ctx.view.id : 'n/a'),
        'replay link: ' + (rum && rum.getSessionReplayLink ? rum.getSessionReplayLink() : 'n/a'),
      ];
      var text = lines.join('\\n');
      document.getElementById('diag').textContent = text;
      if (window.Diagnostics) { window.Diagnostics.postMessage(text); }
    }
    setInterval(report, 3000);
    report();
  </script>
</body>
</html>
''';
