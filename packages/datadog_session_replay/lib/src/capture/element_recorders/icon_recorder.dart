// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../datadog_session_replay.dart';
import '../../datadog_session_replay_platform_interface.dart';
import '../capture_node.dart';
import '../recorder.dart';
import '../view_tree_snapshot.dart';
import 'image_recorder.dart';

// Match [image_recorder.dart] placeholder caption threshold.
const int _iconLabelMinWidth = 125;

@immutable
class _IconCacheKey {
  final int codePoint;
  final String fontFamily;
  final String? fontPackage;
  final int colorSignature;

  const _IconCacheKey({
    required this.codePoint,
    required this.fontFamily,
    required this.fontPackage,
    required this.colorSignature,
  });

  @override
  bool operator ==(Object other) {
    return other is _IconCacheKey &&
        other.codePoint == codePoint &&
        other.fontFamily == fontFamily &&
        other.fontPackage == fontPackage &&
        other.colorSignature == colorSignature;
  }

  @override
  int get hashCode => Object.hash(
        codePoint,
        fontFamily,
        fontPackage,
        colorSignature,
      );
}

class IconRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;
  final double iconRasterLogicalSize;

  final Map<_IconCacheKey, int> _resourceKeyCache = {};
  final Map<_IconCacheKey, Future<int?>> _inFlight = {};

  IconRecorder(
    this.keyGenerator, {
    this.iconRasterLogicalSize = 20.0,
  });

  @override
  bool accepts(Widget widget) => widget is Icon;

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is! Icon) return null;

    final elementId = keyGenerator.keyForElement(element);

    if (capturePrivacy.imagePrivacyLevel == ImagePrivacyLevel.maskAll) {
      return _iconPlaceholder(elementId, attributes);
    }

    final iconData = widget.icon;
    if (iconData == null) {
      return _iconPlaceholder(elementId, attributes);
    }
    final theme = IconTheme.of(element);
    final color = widget.color ?? theme.color ?? const Color(0xFF000000);
    final fontFamily = iconData.fontFamily;
    if (fontFamily == null || fontFamily.isEmpty) {
      return _iconPlaceholder(elementId, attributes);
    }

    final dpr = _devicePixelRatio(element);
    final rasterLogicalSize = iconRasterLogicalSize;
    final widthPx = math.max(1, (rasterLogicalSize * dpr).ceil());
    final heightPx = widthPx;

    final cacheKey = _IconCacheKey(
      codePoint: iconData.codePoint,
      fontFamily: fontFamily,
      fontPackage: iconData.fontPackage,
      colorSignature: color.hashCode,
    );

    final cachedKey = _resourceKeyCache[cacheKey];
    if (cachedKey != null) {
      return SpecificElement(
        subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
        nodes: [
          ResourceImageNode(
            attributes,
            wireframeId: elementId,
            resourceKey: cachedKey,
          ),
        ],
      );
    }

    final textDirection = widget.textDirection ??
        Directionality.maybeOf(element) ??
        TextDirection.ltr;

    return AdditionalProcessingElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      process: () => _ensureRasterized(
        elementId: elementId,
        attributes: attributes,
        cacheKey: cacheKey,
        iconData: iconData,
        color: color,
        widthPx: widthPx,
        heightPx: heightPx,
        textDirection: textDirection,
      ),
    );
  }

  Future<CaptureNodeSemantics> _ensureRasterized({
    required int elementId,
    required CapturedViewAttributes attributes,
    required _IconCacheKey cacheKey,
    required IconData iconData,
    required Color color,
    required int widthPx,
    required int heightPx,
    required TextDirection textDirection,
  }) async {
    final cached = _resourceKeyCache[cacheKey];
    if (cached != null) {
      return SpecificElement(
        subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
        nodes: [
          ResourceImageNode(
            attributes,
            wireframeId: elementId,
            resourceKey: cached,
          ),
        ],
      );
    }

    final future = _inFlight.putIfAbsent(
      cacheKey,
      () => _performRaster(
        cacheKey: cacheKey,
        iconData: iconData,
        color: color,
        widthPx: widthPx,
        heightPx: heightPx,
        textDirection: textDirection,
      ).whenComplete(() {
        _inFlight.remove(cacheKey);
      }),
    );

    final resourceKey = await future;
    if (resourceKey == null) {
      return _iconPlaceholder(elementId, attributes);
    }
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

  Future<int?> _performRaster({
    required _IconCacheKey cacheKey,
    required IconData iconData,
    required Color color,
    required int widthPx,
    required int heightPx,
    required TextDirection textDirection,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final fontSize = widthPx.toDouble();

    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
          fontSize: fontSize,
          height: 1.0,
          color: color,
          inherit: false,
        ),
      ),
      textDirection: textDirection,
      textScaler: TextScaler.noScaling,
    )..layout();

    textPainter.paint(canvas, Offset.zero);
    textPainter.dispose();

    final picture = recorder.endRecording();
    final ui.Image raster;
    try {
      raster = await picture.toImage(widthPx, heightPx);
    } catch (_) {
      return null;
    } finally {
      picture.dispose();
    }

    try {
      final byteData =
          await raster.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;

      final resourceKey = keyGenerator.keyForImage(raster);
      await DatadogSessionReplayPlatform.instance.saveImageForProcessing(
        resourceKey,
        raster.width,
        raster.height,
        byteData,
      );
      _resourceKeyCache[cacheKey] = resourceKey;
      return resourceKey;
    } finally {
      raster.dispose();
    }
  }

  static SpecificElement _iconPlaceholder(
    int elementId,
    CapturedViewAttributes attributes,
  ) {
    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      nodes: [
        PlaceholderNode(
          attributes,
          wireframeId: elementId,
          caption: 'Icon',
          minWidth: _iconLabelMinWidth,
        ),
      ],
    );
  }

  static double _devicePixelRatio(Element element) {
    final view = View.maybeOf(element);
    if (view != null) {
      return view.devicePixelRatio;
    }
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 1.0;
    return views.first.devicePixelRatio;
  }
}
