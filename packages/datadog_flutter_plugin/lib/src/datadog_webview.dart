// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'package:webview_flutter/webview_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_android/webview_flutter_android.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../datadog_flutter_plugin.dart';

extension DatadogWebview on WebViewController {
  /// Enables the SDK to correlate Datadog RUM events and Logs from the WebView
  /// with native RUM session.
  ///
  /// If the content loaded in WebView uses Datadog Browser SDK (`v4.2.0+`) and
  /// matches specified [hosts], web events will be correlated with the RUM
  /// session from native SDK.
  ///
  /// [hosts] does not support matching wildcards, but does support matching
  /// subdomains of a given host.
  void trackDatadogEvents(DatadogSdk datadog, List<String> hosts) {
    int? webViewIdentifier;
    final localPlatform = platform;
    if (localPlatform is WebKitWebViewController) {
      webViewIdentifier = localPlatform.webViewIdentifier;
    } else if (localPlatform is AndroidWebViewController) {
      webViewIdentifier = localPlatform.webViewIdentifier;
    }

    if (webViewIdentifier != null) {
      datadog.platform.initWebView(webViewIdentifier, hosts);
    }
  }
}
