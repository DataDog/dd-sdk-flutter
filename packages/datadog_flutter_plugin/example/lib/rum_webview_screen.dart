// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

final testUrl = Uri.parse('https://shopist.io');

class RumWebViewScreen extends StatefulWidget {
  const RumWebViewScreen({Key? key}) : super(key: key);

  @override
  State<RumWebViewScreen> createState() => _RumWebViewScreenState();
}

class _RumWebViewScreenState extends State<RumWebViewScreen> {
  WebViewController? webViewController;

  @override
  void initState() {
    super.initState();

    webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..trackDatadogEvents(
        DatadogSdk.instance,
        ['shopist.io'],
      )
      ..loadRequest(testUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Datadog WebView Test'),
      ),
      body: WebViewWidget(controller: webViewController!),
    );
  }
}
