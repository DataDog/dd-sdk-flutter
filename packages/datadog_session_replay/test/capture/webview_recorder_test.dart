// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.
import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/webview_recorder.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simple_test_capture.dart';

void main() {
  const webViewIdentifier = 3;
  const slotId = '4370600960';

  late WebViewSlotRegistry registry;
  late SessionReplayRecorder recorder;
  late Object webViewOwner;

  setUp(() {
    registry = WebViewSlotRegistry();
    final keyGenerator = KeyGenerator();
    final slotTracker = WebViewSlotTracker(keyGenerator, registry: registry);
    recorder = SessionReplayRecorder.withCustomRecorders(
      [WebViewRecorder(keyGenerator, slotTracker)],
      defaultCapturePrivacy: TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
      ),
      touchPrivacyLevel: TouchPrivacyLevel.show,
      webViewSlotTracker: slotTracker,
    );
    recorder.updateContext(
      RUMContext(applicationId: randomString(), sessionId: randomString()),
    );
    webViewOwner = Object();
  });

  // The platform view is never actually created in tests; acknowledge its
  // creation.
  void mockPlatformViews(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (_) async => null,
    );
  }

  Widget buildTree({required bool showWebView}) {
    return SimpleTestCapture(
      key: const Key('key'),
      recorder: recorder,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            const SizedBox(width: 300, height: 600),
            if (showWebView)
              const Positioned(
                top: 100,
                left: 0,
                width: 300,
                height: 400,
                child: UiKitView(
                  viewType: webViewPlatformViewType,
                  creationParams: webViewIdentifier,
                  creationParamsCodec: StandardMessageCodec(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<List<SRWebviewWireframe>> captureWebViewWireframes() async {
    final capture = await recorder.performCapture();
    return [
      for (final node in capture?.viewTreeSnapshot.nodes ?? [])
        ...node.buildWireframes().whereType<SRWebviewWireframe>(),
    ];
  }

  testWidgets('records a tracked WebView as a visible webview wireframe', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    mockPlatformViews(tester);
    registry.register(webViewIdentifier, slotId, owner: webViewOwner);

    await tester.pumpWidget(buildTree(showWebView: true));
    final wireframes = await captureWebViewWireframes();

    expect(wireframes, hasLength(1));
    expect(wireframes[0].slotId, slotId);
    expect(wireframes[0].isVisible, isTrue);
    expect(wireframes[0].y, 100);
    expect(wireframes[0].width, 300);
    expect(wireframes[0].height, 400);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('does not record an untracked WebView as a webview wireframe', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    mockPlatformViews(tester);

    await tester.pumpWidget(buildTree(showWebView: true));

    expect(await captureWebViewWireframes(), isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'records a WebView that left the tree as hidden, with the same wireframe id',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      mockPlatformViews(tester);
      registry.register(webViewIdentifier, slotId, owner: webViewOwner);
      await tester.pumpWidget(buildTree(showWebView: true));
      final visible = (await captureWebViewWireframes()).single;

      await tester.pumpWidget(buildTree(showWebView: false));
      final capture = await recorder.performCapture();

      final firstWireframe = capture!.viewTreeSnapshot.nodes.first
          .buildWireframes()
          .single;
      expect(
        firstWireframe,
        isA<SRWebviewWireframe>(),
        reason: 'hidden slots go first',
      );
      final hidden = firstWireframe as SRWebviewWireframe;
      expect(hidden.id, visible.id);
      expect(hidden.slotId, slotId);
      expect(hidden.isVisible, isFalse);
      expect(hidden.width, 0);
      expect(hidden.height, 0);

      final update = hidden.mutationsFrom(visible).toJson();
      expect(update['isVisible'], isFalse);
      expect(update['slotId'], slotId);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('stops recording a slot once its WebView is collected', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    mockPlatformViews(tester);
    registry.register(webViewIdentifier, slotId, owner: webViewOwner);
    await tester.pumpWidget(buildTree(showWebView: true));
    await captureWebViewWireframes();

    await tester.pumpWidget(buildTree(showWebView: false));
    registry.removeIfCurrent(
      webViewIdentifier,
      registry.debugRegistrationId(webViewIdentifier)!,
    );

    expect(await captureWebViewWireframes(), isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });
}
