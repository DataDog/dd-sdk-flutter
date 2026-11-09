// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../../datadog_session_replay.dart' show ImageDownscaling;
import '../../datadog_session_replay_platform_interface.dart';
import '../../sr_data_models.dart';
import '../capture_node.dart';
import '../view_tree_snapshot.dart';

// ~800x800 decoded pixels; raw RGBA ~2 MB.
const int defaultMaxImagePixelBudget = 640000;

const int defaultMaxCachedRasters = 1024;

// This size was chosen so that 'Content Image' would fit without
// overlapping other content in the replay.
const int _placeholderLabelMinWidth = 125;

/// Remembers the resource keys of bitmaps a recorder drew itself, keyed by
/// what was drawn, so content that doesn't change is only rasterized and
/// handed to the platform once.
final class RasterResourceCache<K extends Object> {
  final int maxEntries;

  final LinkedHashMap<K, int> _resourceKeys = LinkedHashMap();
  final Map<K, Future<int?>> _inFlight = {};

  RasterResourceCache({this.maxEntries = defaultMaxCachedRasters});

  /// The resource key already rasterized for [key], if any.
  int? lookup(K key) {
    final value = _resourceKeys.remove(key);
    if (value != null) {
      // Re-insert to mark as most recently used.
      _resourceKeys[key] = value;
    }
    return value;
  }

  /// Whether a resource key was already rasterized for [key]. Unlike [lookup],
  /// this doesn't mark the entry as recently used.
  bool hasResourceKey(K key) => _resourceKeys.containsKey(key);

  /// Returns the resource key for [key], calling [rasterize] only if it isn't
  /// cached or already being rasterized.
  Future<int?> rasterizeOnce(K key, Future<int?> Function() rasterize) {
    final cached = lookup(key);
    if (cached != null) return Future.value(cached);

    return _inFlight.putIfAbsent(
      key,
      () => rasterize()
          .then((resourceKey) {
            if (resourceKey != null) {
              _resourceKeys[key] = resourceKey;
              while (_resourceKeys.length > maxEntries) {
                _resourceKeys.remove(_resourceKeys.keys.first);
              }
            }
            return resourceKey;
          })
          .whenComplete(() {
            _inFlight.remove(key);
          }),
    );
  }
}

/// Copies [image]'s pixels and hands them to the platform under the key
/// [resourceKey] returns, which is returned. Returns `null`, without calling
/// [resourceKey], if the image has no pixel data.
///
/// The caller still owns [image] and must dispose it.
Future<int?> saveRasterForProcessing(
  ui.Image image,
  int Function() resourceKey,
) async {
  // Raw pixels skip encoding here; the processor hashes and compresses them.
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) return null;

  final key = resourceKey();
  await DatadogSessionReplayPlatform.instance.saveImageForProcessing(
    key,
    image.width,
    image.height,
    byteData,
  );
  return key;
}

/// The transform scale to rasterize content shown at [scale] for.
///
/// Content drawn at or below its layout size uses its full-size bitmap, and
/// larger content rounds up to a multiple of 0.25, so animated transforms such
/// as page transitions reuse bitmaps instead of producing one per capture.
double rasterScale(double scale) {
  if (scale <= 1.0) return 1.0;
  return (scale * 4).ceil() / 4;
}

/// The whole-pixel size of a bitmap for content of [logicalSize] drawn at
/// [pixelRatio].
({int width, int height}) bitmapSizeAt(Size logicalSize, double pixelRatio) {
  return (
    width: math.max(1, (logicalSize.width * pixelRatio).ceil()),
    height: math.max(1, (logicalSize.height * pixelRatio).ceil()),
  );
}

/// The whole-pixel size of a bitmap for content of [logicalSize] drawn at
/// [pixelRatio], kept within [maxPixels] the way decoded images are.
({int width, int height})? rasterBitmapSize(
  Size logicalSize,
  double pixelRatio, {
  required int maxPixels,
  required ImageDownscaling downscaling,
}) {
  final (:width, :height) = bitmapSizeAt(logicalSize, pixelRatio);
  if (width * height <= maxPixels) return (width: width, height: height);

  return switch (downscaling) {
    ImageDownscaling.disabled => null,
    ImageDownscaling.enabled => fitPixelBudget(width, height, maxPixels),
  };
}

/// Shrinks a [width] × [height] bitmap, keeping its aspect ratio, until it
/// has at most [maxPixels] pixels.
({int width, int height}) fitPixelBudget(int width, int height, int maxPixels) {
  final pixels = width * height;
  if (pixels <= maxPixels) return (width: width, height: height);

  final factor = math.sqrt(maxPixels / pixels);
  return (
    width: math.max(1, (width * factor).floor()),
    height: math.max(1, (height * factor).floor()),
  );
}

/// The device pixel ratio of the view showing [element].
double devicePixelRatioOf(Element element) {
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

/// Records [attributes] as the image resource [resourceKey].
SpecificElement resourceElement(
  CapturedViewAttributes attributes, {
  required int wireframeId,
  required int resourceKey,
  CaptureNodeSubtreeStrategy subtreeStrategy =
      CaptureNodeSubtreeStrategy.ignore,
}) {
  return SpecificElement(
    subtreeStrategy: subtreeStrategy,
    nodes: [
      ResourceImageNode(
        attributes,
        wireframeId: wireframeId,
        resourceKey: resourceKey,
      ),
    ],
  );
}

/// Records [attributes] as a placeholder labeled [caption].
SpecificElement placeholderElement(
  CapturedViewAttributes attributes, {
  required int wireframeId,
  required String caption,
}) {
  return SpecificElement(
    subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
    nodes: [
      PlaceholderNode(
        attributes,
        wireframeId: wireframeId,
        caption: caption,
        minWidth: _placeholderLabelMinWidth,
      ),
    ],
  );
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
