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

@immutable
class _IconRasterOutcome {
  const _IconRasterOutcome({
    required this.success,
    required this.outcome,
    this.resourceKey,
    this.msToImage = 0,
    this.msToByteData = 0,
    this.msSave = 0,
  });

  final bool success;

  /// `rasterized`, `toImageFailed`, or `toByteDataNull` from [_performRaster].
  final String outcome;
  final int? resourceKey;
  final int msToImage;
  final int msToByteData;
  final int msSave;

  int get totalMs => msToImage + msToByteData + msSave;
}

class IconRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;
  final InternalLogger? internalLogger;
  final double iconRasterLogicalSize;

  final Map<_IconCacheKey, int> _resourceKeyCache = {};
  final Map<_IconCacheKey, Future<_IconRasterOutcome>> _inFlight = {};

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
    final displayLogicalSize = widget.size ?? theme.size ?? kDefaultFontSize;
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
    final widthPx = math.max(1, (rasterLogicalSize * dpr).ceil());
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
        elementId: elementId,
        attributes: attributes,
        displayLogicalSize: displayLogicalSize,
        widthPx: widthPx,
        heightPx: heightPx,
        iconData: iconData,
        resourceKey: cached,
        msToImage: 0,
        msToByteData: 0,
        msSave: 0,
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
      ).whenComplete(() {
        _inFlight.remove(cacheKey);
      }),
    );

    final outcome = await future;
    final resourceKey = outcome.resourceKey;
    _logIconRaster(
      outcome: outcome.outcome,
      success: outcome.success,
      elementId: elementId,
      attributes: attributes,
      displayLogicalSize: displayLogicalSize,
      widthPx: widthPx,
      heightPx: heightPx,
      iconData: iconData,
      resourceKey: resourceKey,
      msToImage: outcome.msToImage,
      msToByteData: outcome.msToByteData,
      msSave: outcome.msSave,
    );
    if (!outcome.success || resourceKey == null) {
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

  Future<_IconRasterOutcome> _performRaster({
    required _IconCacheKey cacheKey,
    required IconData iconData,
    required Color color,
    required int widthPx,
    required int heightPx,
    required TextDirection textDirection,
  }) async {
    final phaseSw = Stopwatch();

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
          color: color,
          inherit: false,
        ),
      ),
      textDirection: textDirection,
      textScaler: TextScaler.noScaling,
    )..layout();

    textPainter.paint(canvas, Offset.zero);

    final picture = recorder.endRecording();
    late final ui.Image raster;
    var msToImage = 0;
    var msToByteData = 0;
    var msSave = 0;
    try {
      phaseSw.start();
      raster = await picture.toImage(widthPx, heightPx);
      msToImage = phaseSw.elapsedMilliseconds;
    } catch (_) {
      picture.dispose();
      return _IconRasterOutcome(
        success: false,
        outcome: 'toImageFailed',
        msToImage: phaseSw.elapsedMilliseconds,
      );
    }
    picture.dispose();

    try {
      phaseSw.reset();
      phaseSw.start();
      final byteData =
          await raster.toByteData(format: ui.ImageByteFormat.rawRgba);
      msToByteData = phaseSw.elapsedMilliseconds;
      if (byteData == null) {
        return _IconRasterOutcome(
          success: false,
          outcome: 'toByteDataNull',
          msToImage: msToImage,
          msToByteData: msToByteData,
        );
      }

      final resourceKey = keyGenerator.keyForImage(raster);
      phaseSw.reset();
      phaseSw.start();
      await DatadogSessionReplayPlatform.instance.saveImageForProcessing(
        resourceKey,
        raster.width,
        raster.height,
        byteData,
      );
      msSave = phaseSw.elapsedMilliseconds;
      _resourceKeyCache[cacheKey] = resourceKey;

      return _IconRasterOutcome(
        success: true,
        outcome: 'rasterized',
        resourceKey: resourceKey,
        msToImage: msToImage,
        msToByteData: msToByteData,
        msSave: msSave,
      );
    } finally {
      raster.dispose();
    }
  }

  void _logIconRaster({
    required String outcome,
    required bool success,
    required int elementId,
    required CapturedViewAttributes attributes,
    required double displayLogicalSize,
    required int widthPx,
    required int heightPx,
    required IconData iconData,
    required int? resourceKey,
    required int msToImage,
    required int msToByteData,
    required int msSave,
  }) {
    final totalMs = msToImage + msToByteData + msSave;
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
      'toImageMs=$msToImage, '
      'toByteDataMs=$msToByteData, '
      'saveMs=$msSave, '
      'totalMs=$totalMs',
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
