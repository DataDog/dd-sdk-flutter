// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

// Reproduction tests for RUMS-5633: Images not appearing in Session Replay.
//
// Customer reports that png images from Image.asset() on regular Flutter screens
// are not appearing in Session Replay, even with imagePrivacyLevel set to
// ImagePrivacyLevel.maskNone.
//
// These tests target two plausible failure modes:
//
// 1. The default imagePrivacyLevel is maskAll (not maskNone). If the customer's
//    configuration isn't applied correctly, images are masked by default.
//    Test: verify that DatadogSessionReplayConfiguration defaults produce
//    placeholders for all images.
//
// 2. When resourceIdForKey returns null (native platform not ready or failed to
//    process the image), the SRImageWireframe has resourceId=null, and the
//    Session Replay player cannot render the image — it appears missing.
//    Test: verify that null resourceId surfaces through the wireframe.
//
// 3. The _extractAssetImage method doesn't handle ExactAssetImage (used by
//    Image.asset with explicit scale). With maskNonAssetsOnly, these images
//    are incorrectly treated as non-asset images and masked.

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/image_recorder.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/datadog_session_replay_platform_interface.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../test_utils.dart';
import 'simple_test_capture.dart';

class MockDatadogSessionReplayPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DatadogSessionReplayPlatform {}

/// A test-friendly subclass of [ExactAssetImage] that provides a test image
/// instead of loading from an asset bundle.
///
/// This preserves the real type hierarchy:
///   TestExactAssetImage → ExactAssetImage → AssetBundleImageProvider → ImageProvider
///
/// Critically, `TestExactAssetImage is AssetImage` evaluates to `false`,
/// because [ExactAssetImage] extends [AssetBundleImageProvider], NOT [AssetImage].
/// This is the exact type-check that `_extractAssetImage` performs (line 176 of
/// image_recorder.dart), and the reason ExactAssetImage-backed images are not
/// recognized as asset images under `maskNonAssetsOnly`.
class TestExactAssetImage extends ExactAssetImage {
  final ui.Image _testImage;
  final Completer<ImageInfo> _completer = Completer<ImageInfo>.sync();

  TestExactAssetImage(this._testImage)
      : super('test_asset.png', scale: 2.0);

  @override
  Future<AssetBundleImageKey> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<AssetBundleImageKey>(
      AssetBundleImageKey(
        bundle: _DummyAssetBundle(),
        name: 'test_asset.png',
        scale: 2.0,
      ),
    );
  }

  @override
  // ignore: deprecated_member_use
  ImageStreamCompleter loadBuffer(
    AssetBundleImageKey key,
    // ignore: deprecated_member_use
    DecoderBufferCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_completer.future);
  }

  @override
  ImageStreamCompleter loadImage(
    AssetBundleImageKey key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_completer.future);
  }

  ImageInfo complete() {
    final info = ImageInfo(image: _testImage);
    _completer.complete(info);
    return info;
  }
}

/// Minimal asset bundle that never loads — only used to satisfy
/// [AssetBundleImageKey]'s required `bundle` parameter.
class _DummyAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    throw UnsupportedError('DummyAssetBundle.load should not be called');
  }
}

void main() {
  late MockDatadogSessionReplayPlatform platform;
  late RUMContext context;

  late final ui.Image testImage;

  setUpAll(() async {
    final width = randomInt(min: 10, max: 50);
    final height = randomInt(min: 10, max: 50);
    testImage = await createTestImage(
      width: width.toInt(),
      height: height.toInt(),
    );
  });

  tearDownAll(() {
    testImage.dispose();
  });

  setUp(() {
    platform = MockDatadogSessionReplayPlatform();
    DatadogSessionReplayPlatform.instance = platform;

    registerFallbackValue(
      CapturedViewAttributes(
          paintBounds: Rect.zero, scaleX: 1.0, scaleY: 1.0),
    );
    registerFallbackValue(ByteData(1));

    context = RUMContext(
      applicationId: randomString(),
      sessionId: randomString(),
    );
  });

  // ---------------------------------------------------------------------------
  // RUMS-5633 Test 1: Default config masks all images.
  //
  // DatadogSessionReplayConfiguration defaults imagePrivacyLevel to maskAll.
  // If the customer's maskNone override isn't propagated to the recorder,
  // all images (including Image.asset) appear as placeholders.
  //
  // This test verifies that the default configuration (as initialized by
  // DatadogSessionReplayConfiguration) results in images being masked,
  // which proves that explicit maskNone configuration is required.
  // If the configuration path is broken, customers will see masked images
  // even when they think they set maskNone.
  // ---------------------------------------------------------------------------

  group('RUMS-5633: Default configuration masks images', () {
    testWidgets(
        'default DatadogSessionReplayConfiguration uses maskAll '
        'which masks all images including Image.asset', (tester) async {
      // Given - use default configuration (no explicit imagePrivacyLevel override)
      final config = DatadogSessionReplayConfiguration(
        replaySampleRate: 100.0,
        // Note: NOT setting imagePrivacyLevel — defaults to maskAll
      );

      // Then - verify the default is maskAll
      expect(config.imagePrivacyLevel, equals(ImagePrivacyLevel.maskAll),
          reason:
              'RUMS-5633: Default imagePrivacyLevel is maskAll. '
              'If the customer does not explicitly set maskNone, '
              'all images will appear as placeholders in Session Replay');

      // Create recorder with default privacy level
      final KeyGenerator keyGenerator = KeyGenerator();
      final recorder = SessionReplayRecorder.withCustomRecorders(
        [ImageRecorder(keyGenerator)],
        defaultCapturePrivacy: TreeCapturePrivacy(
          textAndInputPrivacyLevel: config.textAndInputPrivacyLevel,
          imagePrivacyLevel: config.imagePrivacyLevel,
        ),
        touchPrivacyLevel: config.touchPrivacyLevel,
      );
      recorder.updateContext(context);

      final imageProvider = TestImageProvider(testImage);
      final tree = MaterialApp(
        home: SimpleTestCapture(
          key: Key('key'),
          recorder: recorder,
          child: Stack(
            children: [
              Positioned(
                top: 10,
                left: 10,
                width: testImage.width.toDouble(),
                height: testImage.height.toDouble(),
                child: Image(image: imageProvider),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(tree);
      imageProvider.complete();
      await tester.pump();

      // When
      CaptureResult? capture;
      await tester.runAsync(() async {
        capture = await recorder.performCapture();
      });

      // Then - with maskAll default, the image should be a placeholder
      expect(capture, isNotNull);
      final allWireframes = capture!.viewTreeSnapshot.nodes
          .expand((node) => node.buildWireframes())
          .toList();

      final placeholderWireframes =
          allWireframes.whereType<SRPlaceholderWireframe>().toList();
      final imageWireframes =
          allWireframes.whereType<SRImageWireframe>().toList();

      // With default maskAll, ALL images should be placeholders
      expect(placeholderWireframes, isNotEmpty,
          reason: 'Default maskAll should produce placeholder wireframes');
      expect(imageWireframes, isEmpty,
          reason: 'Default maskAll should NOT produce image wireframes');
    });
  });

  // ---------------------------------------------------------------------------
  // RUMS-5633 Test 2: Null resourceId causes images to not appear.
  //
  // When the native platform's resourceIdForKey returns null (due to
  // processing failure, timing issues, or platform bridge bugs), the
  // SRImageWireframe has resourceId=null. The Session Replay player cannot
  // fetch image data without a resourceId, so the image appears missing.
  //
  // This test expects the code to guard against null resourceId by either:
  // - Falling back to a placeholder when resourceId is null, OR
  // - Ensuring resourceIdForKey never returns null after saveImageForProcessing
  //
  // Currently, the code does NOT guard against this, allowing null resourceId
  // to propagate to the wireframe, which the player cannot render.
  // ---------------------------------------------------------------------------

  group('RUMS-5633: Null resourceId causes missing images', () {
    testWidgets(
        'SRImageWireframe should have non-null resourceId after image capture',
        (tester) async {
      // Given - maskNone so images should be captured
      final KeyGenerator keyGenerator = KeyGenerator();
      final recorder = SessionReplayRecorder.withCustomRecorders(
        [ImageRecorder(keyGenerator)],
        defaultCapturePrivacy: TreeCapturePrivacy(
          textAndInputPrivacyLevel:
              TextAndInputPrivacyLevel.maskSensitiveInputs,
          imagePrivacyLevel: ImagePrivacyLevel.maskNone,
        ),
        touchPrivacyLevel: TouchPrivacyLevel.show,
      );
      recorder.updateContext(context);

      when(
        () => platform.saveImageForProcessing(any(), any(), any(), any()),
      ).thenAnswer((_) => Future.value());

      // Simulate platform returning null for resourceIdForKey
      // This can happen when the native bridge hasn't finished processing
      // the image data, or when there's a platform communication failure.
      when(() => platform.resourceIdForKey(any())).thenReturn(null);

      final imageProvider = TestImageProvider(testImage);
      final tree = MaterialApp(
        home: SimpleTestCapture(
          key: Key('key'),
          recorder: recorder,
          child: Stack(
            children: [
              Positioned(
                top: 10,
                left: 10,
                width: testImage.width.toDouble(),
                height: testImage.height.toDouble(),
                child: Image(image: imageProvider),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(tree);
      imageProvider.complete();
      await tester.pump();

      // When
      CaptureResult? capture;
      await tester.runAsync(() async {
        capture = await recorder.performCapture();
      });

      // Then - verify the image was captured
      expect(capture, isNotNull);
      final allWireframes = capture!.viewTreeSnapshot.nodes
          .expand((node) => node.buildWireframes())
          .toList();

      final imageWireframes =
          allWireframes.whereType<SRImageWireframe>().toList();

      expect(imageWireframes, isNotEmpty,
          reason: 'With maskNone, image should be captured');

      // RUMS-5633: This is the critical assertion. When resourceIdForKey
      // returns null from the platform, the wireframe's resourceId is null.
      // The Session Replay player CANNOT display an image without a resourceId.
      // This is a likely root cause of "images not appearing in Session Replay."
      //
      // Expected behavior: the code should either:
      // 1. Guard against null resourceId and fall back to a placeholder, OR
      // 2. Ensure saveImageForProcessing guarantees resourceIdForKey succeeds
      //
      // This test FAILS because the code does NOT guard against null resourceId.
      for (final wireframe in imageWireframes) {
        expect(wireframe.resourceId, isNotNull,
            reason:
                'RUMS-5633: SRImageWireframe.resourceId must not be null. '
                'A null resourceId means the Session Replay player cannot '
                'fetch or display the image, causing images to not appear.');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // RUMS-5633 Test 3: ExactAssetImage is not recognized by _extractAssetImage.
  //
  // When Image.asset() is called with an explicit scale parameter, Flutter
  // internally creates an ExactAssetImage (not AssetImage). The method
  // _extractAssetImage in ImageRecorder only checks for AssetImage and
  // ResizeImage(AssetImage), missing ExactAssetImage.
  //
  // The Flutter type hierarchy is:
  //   AssetImage            → AssetBundleImageProvider → ImageProvider
  //   ExactAssetImage       → AssetBundleImageProvider → ImageProvider
  //
  // Both are sibling classes under AssetBundleImageProvider.
  // `ExactAssetImage is AssetImage` evaluates to FALSE.
  //
  // With maskNonAssetsOnly, this means ExactAssetImage-backed images are
  // incorrectly treated as non-asset images and masked with a placeholder.
  // ---------------------------------------------------------------------------

  group('RUMS-5633: ExactAssetImage not handled by _extractAssetImage', () {
    testWidgets(
        'Image with ExactAssetImage should be recognized as asset '
        'with maskNonAssetsOnly', (tester) async {
      // Given - maskNonAssetsOnly should allow asset images through
      final KeyGenerator keyGenerator = KeyGenerator();
      final recorder = SessionReplayRecorder.withCustomRecorders(
        [ImageRecorder(keyGenerator)],
        defaultCapturePrivacy: TreeCapturePrivacy(
          textAndInputPrivacyLevel:
              TextAndInputPrivacyLevel.maskSensitiveInputs,
          imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
        ),
        touchPrivacyLevel: TouchPrivacyLevel.show,
      );
      recorder.updateContext(context);

      when(
        () => platform.saveImageForProcessing(any(), any(), any(), any()),
      ).thenAnswer((_) => Future.value());
      when(() => platform.resourceIdForKey(any()))
          .thenReturn(randomString());

      // TestExactAssetImage is a real ExactAssetImage subclass that can load
      // in tests. Image.asset('path', scale: 2.0) creates ExactAssetImage
      // internally. The recorder checks `widget.image is AssetImage` on
      // line 176 of image_recorder.dart — this is false for ExactAssetImage.
      final imageProvider = TestExactAssetImage(testImage);

      // Verify the type hierarchy that causes the bug:
      // ExactAssetImage IS an AssetBundleImageProvider (same base as AssetImage)
      // but is NOT an AssetImage — they are sibling classes.
      expect(imageProvider is ExactAssetImage, isTrue);
      expect(imageProvider is AssetBundleImageProvider, isTrue);
      expect(imageProvider is AssetImage, isFalse,
          reason: 'ExactAssetImage extends AssetBundleImageProvider, not '
              'AssetImage. This is why _extractAssetImage fails to detect it.');

      final tree = MaterialApp(
        home: SimpleTestCapture(
          key: Key('key'),
          recorder: recorder,
          child: Stack(
            children: [
              Positioned(
                top: 10,
                left: 10,
                width: testImage.width.toDouble(),
                height: testImage.height.toDouble(),
                child: Image(image: imageProvider),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(tree);
      imageProvider.complete();
      await tester.pump();

      // When
      CaptureResult? capture;
      await tester.runAsync(() async {
        capture = await recorder.performCapture();
      });

      // Then
      expect(capture, isNotNull);
      final allWireframes = capture!.viewTreeSnapshot.nodes
          .expand((node) => node.buildWireframes())
          .toList();

      final imageWireframes =
          allWireframes.whereType<SRImageWireframe>().toList();
      final placeholderWireframes =
          allWireframes.whereType<SRPlaceholderWireframe>().toList();

      // RUMS-5633: With maskNonAssetsOnly, ExactAssetImage should be
      // recognized as an asset and captured (privacy loosened to maskNone).
      // Instead, _extractAssetImage returns null because it only checks
      // `widget.image is AssetImage`, the privacy stays maskNonAssetsOnly,
      // and the RawImage child produces a placeholder.
      //
      // This test FAILS because _extractAssetImage doesn't recognize
      // ExactAssetImage as an asset image.
      expect(placeholderWireframes, isEmpty,
          reason:
              'RUMS-5633: ExactAssetImage IS an asset image (loaded from '
              'asset bundle via AssetBundleImageProvider) and should NOT be '
              'masked with maskNonAssetsOnly. _extractAssetImage fails '
              'because it only checks `is AssetImage`, missing '
              'ExactAssetImage which is a sibling class under '
              'AssetBundleImageProvider.');
      expect(imageWireframes, isNotEmpty,
          reason:
              'RUMS-5633: ExactAssetImage should produce SRImageWireframe, '
              'not SRPlaceholderWireframe, with maskNonAssetsOnly');
    });
  });
}
