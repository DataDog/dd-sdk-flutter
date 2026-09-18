// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2024-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'datadog_inappwebview_tracking_platform_interface.dart';

const handlerName = 'datadog_inappwebivew_handler';

String _createBridgeSource(
    DatadogSdk datadog, String bridgeName, Set<String> hosts) {
  final sanitizedHosts = hosts
      // ignore: invalid_use_of_internal_member
      .map((e) => sanitizeHost(e, datadog.internalLogger))
      .whereType<String>();
  final allowedWebViewHostsString = sanitizedHosts.map((e) => '"$e"').join(',');

  String bridgeSource = '''
/* DatadogEventBridge */
window.DatadogEventBridge = {
  cache: [],
  send(msg) {
    if (window.$bridgeName) {
      if (this.cache.length > 0) {
        this.cache.forEach((e) => window.$bridgeName.callHandler('$handlerName', msg))
        this.cache = []
      }
      window.$bridgeName.callHandler('$handlerName', msg)
    } else {
      this.cache.push(msg)
    }
  },
  getAllowedWebViewHosts() {
      return '[$allowedWebViewHostsString]'
  },
  getCapabilities() {
      return '[]'
  },
  getPrivacyLevel() {
      return 'mask'
  }
}
''';

  return bridgeSource;
}

/// Used to connect the Datadog Browser SDK with the mobile SDK. Must be installed into the
/// `initialUserScripts` constructor parameter of [InAppBrowser] or [InAppWebView].  Once this
/// script is installed, make sure to call [DatadogInAppWebViewControllerExtension.trackDatadogEvents]
/// to finalize setting up the bridge between the browser and Datadog.
///
/// The Datadog Browser SDK will only forward information for the provided [allowedHosts]. This should the
/// set of host names that you want to track without schemas or wildcards. For example:
///
/// ```dart
/// allowedHosts: { 'shopist.io', 'datadoghq.com' }
/// ```
class DatadogInAppWebViewUserScript extends UserScript {
  DatadogInAppWebViewUserScript({
    required DatadogSdk datadog,
    required Set<String> allowedHosts,
    String bridgeName = 'flutter_inappwebview',
  }) : super(
          source: _createBridgeSource(datadog, bridgeName, allowedHosts),
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        );
}

extension DatadogInAppWebViewControllerExtension on InAppWebViewController {
  /// Sets up message handling between the WebView and Datadog's Mobile SDKs. Must be called
  /// as soon as possible after creation of a `InAppWebViewController`
  void trackDatadogEvents(DatadogSdk datadog, {double logSampleRate = 100.0}) {
    addJavaScriptHandler(
      handlerName: handlerName,
      callback: (data) {
        if (data.isNotEmpty) {
          final message = data[0];
          if (message is String) {
            // ignore: invalid_use_of_internal_member
            wrap('handleWebMessage', datadog.internalLogger, {}, () {
              DatadogInAppWebViewTrackingPlatform.instance
                  .sendWebViewMessage(message, logSampleRate);
            });
          }
        }
      },
    );
  }
}
