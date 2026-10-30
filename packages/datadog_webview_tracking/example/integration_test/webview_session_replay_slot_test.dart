// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_webview_tracking_example/main.dart' as app;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Session Replay finds a tracked Android WebView's slot from the
  // PlatformViewLink `webview_flutter_android` builds, through the WebViewWidget
  // above it. Runs against the real widgets, so a `webview_flutter` release
  // that builds them differently fails here.
  testWidgets(
    'matches the Android WebView widget to its Session Replay slot',
    (tester) async {
      await app.main();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data?.startsWith('Open WebView') ?? false),
        ),
      );
      await tester.pumpAndSettle();

      final platformViewLink = tester.element(
        find.descendant(
          of: find.byType(WebViewWidget),
          matching: find.byType(PlatformViewLink),
        ),
      );

      final registry = WebViewSlotRegistry.instance;
      final identifier = registry.identifierResolver?.call(platformViewLink);
      expect(identifier, isNotNull);

      // `trackDatadogEvents` registers the slot under the WebView's identifier
      // once `initWebView` returns, so only the right identifier finds it.
      for (var i = 0; i < 50; i++) {
        if (registry.slotId(identifier!) != null) break;
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(registry.slotId(identifier!), isNotNull);
    },
    skip: kIsWeb || defaultTargetPlatform != TargetPlatform.android,
  );
}
