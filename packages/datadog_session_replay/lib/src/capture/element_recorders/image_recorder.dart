// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:async' show TimeoutException;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../../datadog_session_replay.dart';
import '../../datadog_session_replay_platform_interface.dart';
import '../../sr_data_models.dart';
import '../capture_node.dart';
import '../recorder.dart';
import '../view_tree_snapshot.dart';

// This size was chosen so that 'Content Image' would fit without
// overlapping other content in the replay.
const int _labelMinWidth = 125;

// ~800x800 decoded pixels; raw RGBA ~2 MB.
const int defaultMaxImagePixelBudget = 640000;

@visibleForTesting
enum DownscalingNeed {
  none,
  fitToBounds,
  downscaling,
}

const Duration _defaultDownscaleTimeout = Duration(milliseconds: 500);

typedef DownscaleFunction = Future<ui.Image> Function(
  ui.Image source,
  int destWidth,
  int destHeight,
);

/// Trips after consecutive downscale failures; no automatic recovery.
@visibleForTesting
class DownscaleCircuitBreaker {
  static const int maxConsecutiveFailures = 3;

  int _consecutiveFailures = 0;
  bool _tripped = false;

  bool get isTripped => _tripped;

  void recordSuccess() {
    _consecutiveFailures = 0;
  }

  void recordFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= maxConsecutiveFailures) {
      _tripped = true;
    }
  }
}

class ImageRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;
  final ImageDownscaling imageDownscaling;
  final int maxImagePixelBudget;
  final DownscaleCircuitBreaker _downscalingCircuitBreaker;
  final DownscaleFunction _downscale;
  final Duration _downscaleTimeout;

  ImageRecorder(
    this.keyGenerator, {
    this.imageDownscaling = ImageDownscaling.disabled,
    this.maxImagePixelBudget = defaultMaxImagePixelBudget,
    @visibleForTesting DownscaleCircuitBreaker? circuitBreaker,
    @visibleForTesting DownscaleFunction? downscaleOverride,
    @visibleForTesting Duration downscaleTimeout = _defaultDownscaleTimeout,
  })  : _downscalingCircuitBreaker =
            circuitBreaker ?? DownscaleCircuitBreaker(),
        _downscale = downscaleOverride ?? _downscaleImageDefault,
        _downscaleTimeout = downscaleTimeout;

  @override
  bool accepts(Widget widget) => widget is RawImage || widget is Image;

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is Image &&
        capturePrivacy.imagePrivacyLevel ==
            ImagePrivacyLevel.maskNonAssetsOnly) {
      // Try to pull out an AssetImage from the image internals...
      final assetImage = _extractAssetImage(widget);

      if (assetImage != null) {
        // Loosen capturing for the tree under this asset
        return IgnoredElement(
          subtreeStrategy: CaptureNodeSubtreeStrategy.record,
          subtreePrivacy: TreeCapturePrivacy(
            textAndInputPrivacyLevel: capturePrivacy.textAndInputPrivacyLevel,
            imagePrivacyLevel: ImagePrivacyLevel.maskNone,
          ),
        );
      }
    }

    if (widget is! RawImage) return null;

    final uiImage = widget.image;
    if (uiImage == null) {
      // This image is likely still loading. We could put a placeholder here,
      // but we would then have to replace it later. Instead, we'll wait for
      // it to load before creating the capture node. We can, however,
      // ignore all children for the time being.
      return IgnoredElement(subtreeStrategy: CaptureNodeSubtreeStrategy.ignore);
    }

    final elementId = keyGenerator.keyForElement(element);
    // AssetImages loosen their masking to [ImagePrivacyLevel.maskNone] when
    // they need to, so if [ImagePrivacyLevel.maskNonAssetsOnly] is still set, then
    // we shouldn't capture this image.
    bool shouldCaptureImage =
        capturePrivacy.imagePrivacyLevel == ImagePrivacyLevel.maskNone;
    if (!shouldCaptureImage) {
      return SpecificElement(
        subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
        nodes: [
          PlaceholderNode(
            attributes,
            wireframeId: elementId,
            caption: 'Image',
            minWidth: _labelMinWidth,
          ),
        ],
      );
    }

    final totalPixelSize = uiImage.width * uiImage.height;
    if (totalPixelSize > maxImagePixelBudget &&
        imageDownscaling == ImageDownscaling.disabled) {
      return SpecificElement(
        subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
        nodes: [
          PlaceholderNode(
            attributes,
            wireframeId: elementId,
            caption: 'Large Image',
            minWidth: _labelMinWidth,
          ),
        ],
      );
    }

    final hasResourceKey = keyGenerator.hasImageKey(uiImage);
    if (hasResourceKey) {
      final resourceKey = keyGenerator.keyForImage(uiImage);
      return SpecificElement(
        subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
        nodes: [
          ResourceImageNode(
            attributes,
            wireframeId: elementId,
            resourceKey: resourceKey,
          ),
        ],
      );
    }

    return AdditionalProcessingElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      process: () => _captureImage(elementId, element, attributes, widget),
    );
  }

  Future<CaptureNodeSemantics> _captureImage(
    int elementId,
    Element element,
    CapturedViewAttributes attributes,
    RawImage widget,
  ) async {
    final image = widget.image;
    if (image == null) {
      return _placeholder(elementId, attributes, 'Empty Image');
    }

    final (need, scaledWidth, scaledHeight) = downscaleSizeTarget(
      image.width,
      image.height,
      attributes,
      _devicePixelRatio(element),
      maxImagePixelBudget,
    );

    if (need == DownscalingNeed.none) {
      return _persistImageAsResourceNode(
        elementId,
        attributes,
        sourceImageForKeyGen: image,
        encodingImageForByteData: image,
      );
    }

    if (imageDownscaling == ImageDownscaling.disabled) {
      return _persistImageAsResourceNode(
        elementId,
        attributes,
        sourceImageForKeyGen: image,
        encodingImageForByteData: image,
      );
    }

    if (_downscalingCircuitBreaker.isTripped) {
      return _placeholder(elementId, attributes, 'Slow Device');
    }

    ui.Image? scaled;
    try {
      scaled = await _downscale(image, scaledWidth, scaledHeight)
          .timeout(_downscaleTimeout);
      _downscalingCircuitBreaker.recordSuccess();
      return _persistImageAsResourceNode(
        elementId,
        attributes,
        sourceImageForKeyGen: image,
        encodingImageForByteData: scaled,
      );
    } on TimeoutException {
      _downscalingCircuitBreaker.recordFailure();
      return _placeholder(elementId, attributes, 'Slow Device');
    } catch (_) {
      _downscalingCircuitBreaker.recordFailure();
      return _placeholder(elementId, attributes, 'Failed Downscale');
    } finally {
      scaled?.dispose();
    }
  }

  Future<CaptureNodeSemantics> _persistImageAsResourceNode(
    int elementId,
    CapturedViewAttributes attributes, {
    required ui.Image sourceImageForKeyGen,
    required ui.Image encodingImageForByteData,
  }) async {
    try {
      // Prevent conversion of the image data to speed things up, we're going to
      // be hashing / compressing in the processor anyway
      final byteData = await encodingImageForByteData.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData != null) {
        final resourceKey = keyGenerator.keyForImage(sourceImageForKeyGen);
        await DatadogSessionReplayPlatform.instance.saveImageForProcessing(
          resourceKey,
          encodingImageForByteData.width,
          encodingImageForByteData.height,
          byteData,
        );
        return SpecificElement(
          subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
          nodes: [
            ResourceImageNode(
              attributes,
              wireframeId: elementId,
              resourceKey: resourceKey,
            ),
          ],
        );
      } else {
        return _placeholder(elementId, attributes, 'Empty Image');
      }
    } catch (_) {
      return _placeholder(elementId, attributes, 'Error Image');
    }
  }

  static SpecificElement _placeholder(
    int elementId,
    CapturedViewAttributes attributes,
    String caption,
  ) {
    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      nodes: [
        PlaceholderNode(
          attributes,
          wireframeId: elementId,
          caption: caption,
          minWidth: _labelMinWidth,
        ),
      ],
    );
  }

  static (DownscalingNeed, int, int) downscaleSizeTarget(
    int sourceWidth,
    int sourceHeight,
    CapturedViewAttributes attributes,
    double devicePixelRatio,
    int pixelBudget,
  ) {
    final renderedPhysicalWidth =
        math.max(1, (attributes.width * devicePixelRatio).ceil());
    final renderedPhysicalHeight =
        math.max(1, (attributes.height * devicePixelRatio).ceil());

    if (renderedPhysicalWidth >= sourceWidth &&
        renderedPhysicalHeight >= sourceHeight &&
        sourceWidth * sourceHeight <= pixelBudget) {
      // below budget, no downscaling needed
      return (DownscalingNeed.none, sourceWidth, sourceHeight);
    }

    // Shrink to rendered physical size; cap at 1.0 (no upscale beyond native).
    final fitToBoundsScale = math.min(
      math.min(renderedPhysicalWidth / sourceWidth,
          renderedPhysicalHeight / sourceHeight),
      1.0,
    );
    final fitToBoundsWidth =
        math.max(1, (sourceWidth * fitToBoundsScale).round());
    final fitToBoundsHeight =
        math.max(1, (sourceHeight * fitToBoundsScale).round());
    final fitToBoundsPixels = fitToBoundsWidth * fitToBoundsHeight;
    if (fitToBoundsPixels <= pixelBudget) {
      return (DownscalingNeed.fitToBounds, fitToBoundsWidth, fitToBoundsHeight);
    }

    final downscaling = math.sqrt(pixelBudget / fitToBoundsPixels);
    final downscaledWidth =
        math.max(1, (fitToBoundsWidth * downscaling).floor());
    final downscaledHeight =
        math.max(1, (fitToBoundsHeight * downscaling).floor());
    return (DownscalingNeed.downscaling, downscaledWidth, downscaledHeight);
  }

  static double _devicePixelRatio(Element element) {
    final view = View.maybeOf(element);
    if (view != null) {
      return view.devicePixelRatio;
    }
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isNotEmpty) {
      return views.first.devicePixelRatio;
    }
    return 1.0;
  }

  static Future<ui.Image> _downscaleImageDefault(
    ui.Image source,
    int destWidth,
    int destHeight,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
    canvas.drawImageRect(
      source,
      ui.Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, destWidth.toDouble(), destHeight.toDouble()),
      paint,
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(destWidth, destHeight);
    } finally {
      picture.dispose();
    }
  }

  AssetBundleImageProvider? _extractAssetImage(Image widget) {
    AssetBundleImageProvider? assetImage;
    if (widget.image is AssetBundleImageProvider) {
      assetImage = widget.image as AssetBundleImageProvider;
    } else if (widget.image is ResizeImage) {
      final resizeImage = widget.image as ResizeImage;
      if (resizeImage.imageProvider is AssetBundleImageProvider) {
        assetImage = resizeImage.imageProvider as AssetBundleImageProvider;
      }
    }
    return assetImage;
  }
}

@immutable
@visibleForTesting
class ResourceImageNode extends CaptureNode {
  final int wireframeId;
  final int resourceKey;

  const ResourceImageNode(
    super.attributes, {
    required this.wireframeId,
    required this.resourceKey,
  });

  @override
  List<SRWireframe> buildWireframes() {
    final resourceId = DatadogSessionReplayPlatform.instance.resourceIdForKey(
      resourceKey,
    );

    return [
      SRImageWireframe(
        id: wireframeId,
        x: attributes.x,
        y: attributes.y,
        width: attributes.width,
        height: attributes.height,
        resourceId: resourceId,
      ),
    ];
  }
}
