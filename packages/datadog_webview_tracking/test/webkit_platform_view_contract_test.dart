// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

// Session Replay finds a tracked WebView in the widget tree by relying on how
// `webview_flutter_wkwebview` builds it on iOS: a `UiKitView` of type
// [webViewPlatformViewType] whose `creationParams` is the same identifier
// `trackDatadogEvents` registers the WebView's slot under. A new version of
// that package changing either would silently drop WebViews from replays.
void main() {
  testWidgets(
    'the iOS WebView is a UiKitView identified by its webViewIdentifier',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      // There is no native side in tests: acknowledge every message sent to it.
      tester.binding.defaultBinaryMessenger.allMessagesHandler =
          (channel, handler, message) async =>
              const StandardMessageCodec().encodeMessage(<Object?>[null]);

      final controller = WebKitWebViewController(
        WebKitWebViewControllerCreationParams(),
      );
      final webViewWidget = WebKitWebViewWidget(
        WebKitWebViewWidgetCreationParams(controller: controller),
      );

      late Widget platformView;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            platformView = webViewWidget.build(context);
            return const SizedBox();
          },
        ),
      );

      expect(platformView, isA<UiKitView>());
      final uiKitView = platformView as UiKitView;
      expect(uiKitView.viewType, webViewPlatformViewType);
      expect(uiKitView.creationParams, controller.webViewIdentifier);

      tester.binding.defaultBinaryMessenger.allMessagesHandler = null;
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
