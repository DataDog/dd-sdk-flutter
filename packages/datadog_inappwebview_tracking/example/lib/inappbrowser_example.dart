// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2024-Present Datadog, Inc.

import 'dart:collection';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_inappwebview_tracking/datadog_inappwebview_tracking.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class MyInAppBrowser extends InAppBrowser {
  MyInAppBrowser({super.windowId, super.initialUserScripts});

  @override
  void onBrowserCreated() {
    webViewController?.trackDatadogEvents(DatadogSdk.instance);
    super.onBrowserCreated();
  }
}

class InAppBrowserExample extends StatefulWidget {
  const InAppBrowserExample({super.key});

  @override
  State<InAppBrowserExample> createState() => _InAppBrowserExampleState();
}

class _InAppBrowserExampleState extends State<InAppBrowserExample> {
  late final InAppBrowser _browser;

  @override
  void initState() {
    super.initState();

    _browser = MyInAppBrowser(
      initialUserScripts: UnmodifiableListView(
        [
          DatadogInAppWebViewUserScript(
            datadog: DatadogSdk.instance,
            allowedHosts: {'shopist.io'},
          ),
        ],
      ),
    );
  }

  Future<void> _openInAppBrowser() async {
    await _browser.openUrlRequest(
      urlRequest: URLRequest(url: WebUri("https://shopist.io")),
      settings: InAppBrowserClassSettings(
        browserSettings: InAppBrowserSettings(
          toolbarTopBackgroundColor: Colors.blue,
          presentationStyle: ModalPresentationStyle.POPOVER,
        ),
        webViewSettings: InAppWebViewSettings(
          isInspectable: kDebugMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("InAppBrowser Example")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
                onPressed: () => _openInAppBrowser(),
                child: const Text("Open InAppBrowser")),
          ],
        ),
      ),
    );
  }
}
