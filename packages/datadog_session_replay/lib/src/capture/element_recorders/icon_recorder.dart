// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
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

int _colorSignature(Color color) {
  return Object.hash(color.a, color.r, color.g, color.b);
}

class IconRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;
  final InternalLogger? internalLogger;
  final double iconRasterLogicalSize;

  final Map<_IconCacheKey, int> _resourceKeyCache = {};
  final Map<_IconCacheKey, Future<int?>> _inFlight = {};

  IconRecorder(
    this.keyGenerator, {
    this.internalLogger,
    this.iconRasterLogicalSize = 20.0,
  });

  @override
  List<Type> get handlesTypes => [Icon];

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

    final context = element;
    final iconData = widget.icon;
    if (iconData == null) {
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
    final theme = IconTheme.of(context);
    final displayLogicalSize =
        widget.size ?? theme.size ?? kDefaultFontSize;
    final color = widget.color ?? theme.color ?? const Color(0xFF000000);
    final fontFamily = iconData.fontFamily;
    if (fontFamily == null || fontFamily.isEmpty) {
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

    final dpr = _devicePixelRatio(element);
    final rasterLogicalSize = iconRasterLogicalSize;
    final widthPx =
        math.max(1, (rasterLogicalSize * dpr).ceil());
    final heightPx = widthPx;

    final cacheKey = _IconCacheKey(
      codePoint: iconData.codePoint,
      fontFamily: fontFamily,
      fontPackage: iconData.fontPackage,
      colorSignature: _colorSignature(color),
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
        Directionality.maybeOf(context) ??
        TextDirection.ltr;

    return AdditionalProcessingElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      process: () => _ensureRasterized(
        elementId: elementId,
        attributes: attributes,
        cacheKey: cacheKey,
        iconData: iconData,
        color: color,
        displayLogicalSize: displayLogicalSize,
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
    required double displayLogicalSize,
    required int widthPx,
    required int heightPx,
    required TextDirection textDirection,
  }) async {
    final cached = _resourceKeyCache[cacheKey];
    if (cached != null) {
      _logIconRaster(
        outcome: 'cacheHitAfterAwait',
        success: true,
        elapsedMs: 0,
        elementId: elementId,
        attributes: attributes,
        displayLogicalSize: displayLogicalSize,
        widthPx: widthPx,
        heightPx: heightPx,
        iconData: iconData,
        resourceKey: cached,
      );
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
        displayLogicalSize: displayLogicalSize,
        attributes: attributes,
        elementId: elementId,
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
    required double displayLogicalSize,
    required CapturedViewAttributes attributes,
    required int elementId,
  }) async {
    final stopwatch = Stopwatch()..start();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final rasterLogicalSize = iconRasterLogicalSize;
    final dprForRaster = widthPx / math.max(1e-6, rasterLogicalSize);
    final fontSize = rasterLogicalSize * dprForRaster;

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

    final dx = (widthPx - textPainter.width) / 2.0;
    final dy = (heightPx - textPainter.height) / 2.0;
    textPainter.paint(canvas, Offset(dx, dy));

    final picture = recorder.endRecording();
    late final ui.Image raster;
    try {
      raster = await picture.toImage(widthPx, heightPx);
    } catch (_) {
      picture.dispose();
      stopwatch.stop();
      _logIconRaster(
        outcome: 'toImageFailed',
        success: false,
        elapsedMs: stopwatch.elapsedMilliseconds,
        elementId: elementId,
        attributes: attributes,
        displayLogicalSize: displayLogicalSize,
        widthPx: widthPx,
        heightPx: heightPx,
        iconData: iconData,
        resourceKey: null,
      );
      return null;
    }
    picture.dispose();

    try {
      final byteData =
          await raster.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        stopwatch.stop();
        _logIconRaster(
          outcome: 'toByteDataNull',
          success: false,
          elapsedMs: stopwatch.elapsedMilliseconds,
          elementId: elementId,
          attributes: attributes,
          displayLogicalSize: displayLogicalSize,
          widthPx: widthPx,
          heightPx: heightPx,
          iconData: iconData,
          resourceKey: null,
        );
        return null;
      }

      final resourceKey = keyGenerator.keyForImage(raster);
      await DatadogSessionReplayPlatform.instance.saveImageForProcessing(
        resourceKey,
        raster.width,
        raster.height,
        byteData,
      );
      _resourceKeyCache[cacheKey] = resourceKey;

      stopwatch.stop();
      _logIconRaster(
        outcome: 'rasterized',
        success: true,
        elapsedMs: stopwatch.elapsedMilliseconds,
        elementId: elementId,
        attributes: attributes,
        displayLogicalSize: displayLogicalSize,
        widthPx: widthPx,
        heightPx: heightPx,
        iconData: iconData,
        resourceKey: resourceKey,
      );

      return resourceKey;
    } finally {
      raster.dispose();
    }
  }

  void _logIconRaster({
    required String outcome,
    required bool success,
    required int elapsedMs,
    required int elementId,
    required CapturedViewAttributes attributes,
    required double displayLogicalSize,
    required int widthPx,
    required int heightPx,
    required IconData iconData,
    required int? resourceKey,
  }) {
    internalLogger?.log(
      CoreLoggerLevel.debug,
      'Session Replay icon raster: '
      'outcome=$outcome, '
      'success=$success, '
      'codePoint=U+${iconData.codePoint.toRadixString(16).toUpperCase()}, '
      'fontFamily=${iconData.fontFamily}, '
      'fontPackage=${iconData.fontPackage}, '
      'displayLogicalSize=${displayLogicalSize.toStringAsFixed(1)}, '
      'bitmap=${widthPx}x$heightPx, '
      'viewBounds=${attributes.width.toStringAsFixed(1)}x'
      '${attributes.height.toStringAsFixed(1)}, '
      'wireframeId=$elementId, '
      'resourceKey=$resourceKey, '
      'took ${elapsedMs}ms',
    );
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
    return WidgetsBinding
        .instance.platformDispatcher.views.first.devicePixelRatio;
  }
}
