// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_webview_tracking/datadog_webview_tracking.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:webview_flutter/webview_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_android/webview_flutter_android.dart';

class MockDatadogSdk extends Mock implements DatadogSdk {}

class MockInternalLogger extends Mock implements InternalLogger {}

class MockWebviewPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements WebViewPlatform {}

class MockAndroidWebViewController extends Mock
    with MockPlatformInterfaceMixin
    implements AndroidWebViewController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const PlatformWebViewControllerCreationParams());
  });

  test('track webview calls to platform', () {
    final mockDatadog = MockDatadogSdk();
    // ignore: invalid_use_of_internal_member
    when(() => mockDatadog.internalLogger).thenReturn(MockInternalLogger());

    final mockWebiewPlatform = MockWebviewPlatform();
    final mockAndroidController = MockAndroidWebViewController();
    when(() => mockWebiewPlatform.createPlatformWebViewController(any()))
        .thenReturn(mockAndroidController);
    when(() => mockAndroidController.webViewIdentifier).thenReturn(148221);
    WebViewPlatform.instance = mockWebiewPlatform;

    final List<MethodCall> log = [];

    ambiguate(TestDefaultBinaryMessengerBinding.instance)
        ?.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (message) {
      log.add(message);
      return null;
    });

    WebViewController().trackDatadogEvents(mockDatadog, ['host_a', 'host_b']);

    expect(log, [
      isMethodCall('initWebView', arguments: {
        'webViewIdentifier': 148221,
        'allowedHosts': ['host_a', 'host_b']
      })
    ]);
  });
}
