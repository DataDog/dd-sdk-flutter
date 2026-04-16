// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

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

// Largest size of image we can process - larger than this and we
// start to hit concerns around memory usage and processing time.
// This is essentially an 800x800 image, with a raw size of 2meg
const int maxImageSize = 640000;

/// Computes a fast non-cryptographic hash of [byteData] by sampling every
/// [stride]-th byte (capped at ~1 KB of input). Size is folded in to reduce
/// collisions between images that share the same pixel pattern but differ in
/// dimensions.
int hashImageBytes(ByteData byteData) {
  final bytes = byteData.buffer.asUint8List();
  final stride = max(1, bytes.length ~/ 1024);
  var hash = 0;
  for (var i = 0; i < bytes.length; i += stride) {
    hash = (hash * 31 + bytes[i]) & 0x1FFFFFFFFFFFFFFF;
  }
  return hash ^ bytes.length;
}

class ImageRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  const ImageRecorder(this.keyGenerator);

  @override
  List<Type> get handlesTypes => [RawImage, Image];

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
    if (totalPixelSize > maxImageSize) {
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
            keyGenerator: keyGenerator,
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
    final List<CaptureNode> nodes = [];
    if (widget.image case final image?) {
      // Prevent conversion of the image data to speed things up, we're going to
      // be hashing / compressing in the processor anyway
      ByteData? byteData = await image.toByteData(
        format: ImageByteFormat.rawRgba,
      );
      if (byteData != null) {
        final contentHash = hashImageBytes(byteData);
        // Re-use an existing resourceKey if we've seen this content before,
        // even if it arrived as a different ui.Image instance.
        final existingKey = keyGenerator.resourceKeyForHash(contentHash);
        final resourceKey = existingKey ?? keyGenerator.keyForImage(image);

        if (existingKey == null) {
          // First time seeing this content — send bytes to native and cache.
          await DatadogSessionReplayPlatform.instance.saveImageForProcessing(
            resourceKey,
            image.width,
            image.height,
            byteData,
          );
          keyGenerator.cacheContentHash(contentHash, resourceKey);
        }

        nodes.add(
          ResourceImageNode(
            attributes,
            wireframeId: elementId,
            resourceKey: resourceKey,
            keyGenerator: keyGenerator,
          ),
        );
      }
    }

    if (nodes.isEmpty) {
      nodes.add(
        PlaceholderNode(
          attributes,
          wireframeId: elementId,
          caption: 'Empty Image',
          minWidth: _labelMinWidth,
        ),
      );
    }

    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      nodes: nodes,
    );
  }

  AssetImage? _extractAssetImage(Image widget) {
    AssetImage? assetImage;
    if (widget.image is AssetImage) {
      assetImage = widget.image as AssetImage;
    } else if (widget.image is ResizeImage) {
      final resizeImage = widget.image as ResizeImage;
      if (resizeImage.imageProvider is AssetImage) {
        assetImage = resizeImage.imageProvider as AssetImage;
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
  final KeyGenerator keyGenerator;

  const ResourceImageNode(
    super.attributes, {
    required this.wireframeId,
    required this.resourceKey,
    required this.keyGenerator,
  });

  @override
  List<SRWireframe> buildWireframes() {
    // Check Dart-side cache first to avoid a native call every capture cycle.
    var resourceId = keyGenerator.cachedResourceId(resourceKey);
    if (resourceId == null) {
      resourceId = DatadogSessionReplayPlatform.instance.resourceIdForKey(
        resourceKey,
      );
      if (resourceId != null) {
        keyGenerator.cacheResourceId(resourceKey, resourceId);
      }
    }

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
