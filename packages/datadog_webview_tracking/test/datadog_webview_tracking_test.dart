// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

// datadog_flutter_plugin 3.x only exports DatadogSdk from here.
// ignore: unnecessary_import
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
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class MockDatadogSdk extends Mock implements DatadogSdk {}

class MockInternalLogger extends Mock implements InternalLogger {}

class MockWebviewPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements WebViewPlatform {}

class MockAndroidWebViewController extends Mock
    with MockPlatformInterfaceMixin
    implements AndroidWebViewController {}

class MockWebKitWebViewController extends Mock
    with MockPlatformInterfaceMixin
    implements WebKitWebViewController {}

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
    when(
      () => mockWebiewPlatform.createPlatformWebViewController(any()),
    ).thenReturn(mockAndroidController);
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
      isMethodCall(
        'initWebView',
        arguments: {
          'webViewIdentifier': 148221,
          'allowedHosts': ['host_a', 'host_b'],
        },
      ),
    ]);
  });

  group('Session Replay slot', () {
    late MockDatadogSdk mockDatadog;
    late MockWebviewPlatform mockWebviewPlatform;
    late WebViewSlotRegistry registry;

    setUp(() {
      registry = WebViewSlotRegistry();
      WebViewSlotRegistry.instance = registry;
      mockDatadog = MockDatadogSdk();
      // ignore: invalid_use_of_internal_member
      when(() => mockDatadog.internalLogger).thenReturn(MockInternalLogger());
      mockWebviewPlatform = MockWebviewPlatform();
      WebViewPlatform.instance = mockWebviewPlatform;
    });

    void mockNativeResult(String? slotId) {
      ambiguate(TestDefaultBinaryMessengerBinding.instance)
          ?.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (message) async => slotId);
    }

    WebViewController createIosController(int webViewIdentifier) {
      final mockWebKitController = MockWebKitWebViewController();
      when(
        () => mockWebviewPlatform.createPlatformWebViewController(any()),
      ).thenReturn(mockWebKitController);
      when(
        () => mockWebKitController.webViewIdentifier,
      ).thenReturn(webViewIdentifier);
      return WebViewController();
    }

    test('registers the slot ID native returns for the WebView', () async {
      mockNativeResult('4370600960');

      createIosController(3).trackDatadogEvents(mockDatadog, ['host_a']);
      await pumpEventQueue();

      expect(registry.slotId(3), '4370600960');
    });

    test('registers no slot when native finds no WebView', () async {
      mockNativeResult(null);

      createIosController(3).trackDatadogEvents(mockDatadog, ['host_a']);
      await pumpEventQueue();

      expect(registry.slotId(3), isNull);
    });
  });
}
