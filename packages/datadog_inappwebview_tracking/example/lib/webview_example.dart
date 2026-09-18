// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2024-Present Datadog, Inc.
import 'dart:collection';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_inappwebview_tracking/datadog_inappwebview_tracking.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebviewExample extends StatefulWidget {
  const WebviewExample({super.key});

  @override
  State<WebviewExample> createState() => _WebviewExampleState();
}

class _WebviewExampleState extends State<WebviewExample> {
  final GlobalKey _webViewKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebView Example'),
      ),
      body: SafeArea(
          child: InAppWebView(
        key: _webViewKey,
        initialUserScripts: UnmodifiableListView([
          DatadogInAppWebViewUserScript(
            datadog: DatadogSdk.instance,
            allowedHosts: {'shopist.io'},
          ),
        ]),
        initialUrlRequest: URLRequest(url: WebUri('https://shopist.io')),
        initialSettings: InAppWebViewSettings(
          isInspectable: kDebugMode,
        ),
        onWebViewCreated: (controller) async {
          controller.trackDatadogEvents(DatadogSdk.instance);
        },
      )),
    );
  }
}
