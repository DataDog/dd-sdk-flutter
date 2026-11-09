// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../datadog_session_replay.dart';
import '../../extensions.dart';
import '../capture_node.dart';
import '../recorder.dart';
import '../text_masking.dart';
import '../view_tree_snapshot.dart';
import 'common_nodes.dart';
import 'raster_resources.dart';
import 'recording_extensions.dart';

/// Captures [RichText] widgets, which also covers [Text].
///
/// In [TextCaptureMode.standard] the text is sent as a text wireframe. In
/// [TextCaptureMode.highFidelity] the paragraph's [RenderParagraph] is painted
/// offscreen and sent as an image, unless the text is masked.
class TextElementRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;
  final TextCaptureMode textCaptureMode;

  /// The largest bitmap, in pixels, a paragraph is rasterized into in
  /// [TextCaptureMode.highFidelity]. Larger paragraphs are drawn at a lower
  /// resolution.
  final int maxImagePixelBudget;

  final RasterResourceCache<TextRasterKey> _rasterCache;

  TextElementRecorder(
    this.keyGenerator, {
    this.textCaptureMode = TextCaptureMode.standard,
    this.maxImagePixelBudget = defaultMaxImagePixelBudget,
    int maxCachedRasters = defaultMaxCachedRasters,
  }) : _rasterCache = RasterResourceCache(maxEntries: maxCachedRasters);

  @override
  bool accepts(Widget widget) => widget is RichText;

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is! RichText) {
      return null;
    }

    final textSpan = widget.text;
    if (textSpan is TextSpan) {
      final style = textSpan.style;
      final alignment = widget.textAlign.getSrHorizontalAlignment(
        widget.textDirection,
      );

      // For now, contact all child spans into a single string.
      // TODO(RUM-10230: Research how to support inline spans with different styles
      final stringBuilder = StringBuffer();
      bool hasWidgetChildern = _getText(
        textSpan,
        stringBuilder,
        capturePrivacy.textAndInputPrivacyLevel,
      );

      final rawFontSize = style?.fontSize;
      final scaledSize = ((rawFontSize ?? 10) * attributes.scaleX).safeRound(
        10,
      );

      final node = TextElementCaptureNode(
        attributes,
        wireframeId: keyGenerator.keyForElement(element),
        text: stringBuilder.toString(),
        color: style?.color?.toHexString() ?? Colors.black.toHexString(),
        family: style?.fontFamily ?? '',
        size: scaledSize,
        alignment: alignment,
      );

      // Widgets placed inline with WidgetSpan are recorded as their own nodes.
      final subtreeStrategy = hasWidgetChildern
          ? CaptureNodeSubtreeStrategy.record
          : CaptureNodeSubtreeStrategy.ignore;
      final textSemantics = SpecificElement(
        subtreeStrategy: subtreeStrategy,
        nodes: [node],
      );

      if (textCaptureMode == TextCaptureMode.highFidelity &&
          capturePrivacy.textAndInputPrivacyLevel !=
              TextAndInputPrivacyLevel.maskAll) {
        return _captureRaster(
              element,
              attributes,
              node.wireframeId,
              subtreeStrategy,
              textSemantics,
            ) ??
            textSemantics;
      }
      return textSemantics;
    }
    return null;
  }

  /// Rasterizes the paragraph [element] renders, falling back to
  /// [textSemantics] if it can't be drawn. Returns `null` if there's nothing
  /// to rasterize.
  CaptureNodeSemantics? _captureRaster(
    Element element,
    CapturedViewAttributes attributes,
    int wireframeId,
    CaptureNodeSubtreeStrategy subtreeStrategy,
    SpecificElement textSemantics,
  ) {
    final paragraph = element.renderObject;
    if (paragraph is! RenderParagraph || !paragraph.hasSize) return null;
    final size = paragraph.size;
    if (size.isEmpty) return null;

    final scale = math.max(attributes.scaleX, attributes.scaleY);
    if (scale <= 0) return null;
    final (:width, :height) = bitmapSizeAt(
      size,
      devicePixelRatioOf(element) * rasterScale(scale),
    );
    final (width: pixelWidth, height: pixelHeight) = fitPixelBudget(
      width,
      height,
      maxImagePixelBudget,
    );

    final rasterKey = TextRasterKey.fromParagraph(
      paragraph,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
    );
    SpecificElement resourceSemantics(int resourceKey) => resourceElement(
      attributes,
      wireframeId: wireframeId,
      resourceKey: resourceKey,
      subtreeStrategy: subtreeStrategy,
    );

    final cachedKey = _rasterCache.lookup(rasterKey);
    if (cachedKey != null) return resourceSemantics(cachedKey);

    // Paint now (cheap), while the paragraph shows this frame. Reading the pixels
    // back waits for [AdditionalProcessingElement.process], which the recorder runs
    // one element at a time, so readbacks don't pile up on text-heavy screens.
    final layer = _paint(paragraph, size, pixelWidth, pixelHeight);
    if (layer == null) return textSemantics;

    return AdditionalProcessingElement(
      subtreeStrategy: subtreeStrategy,
      process: () async {
        try {
          final resourceKey = await _rasterCache.rasterizeOnce(
            rasterKey,
            () => _saveLayer(layer, pixelWidth, pixelHeight),
          );
          return resourceKey == null
              ? textSemantics
              : resourceSemantics(resourceKey);
        } finally {
          layer.dispose();
        }
      },
      discard: layer.dispose,
    );
  }

  /// Paints [paragraph] into a new layer tree scaled to fill a
  /// [pixelWidth] × [pixelHeight] bitmap. Returns `null` if painting fails.
  static OffsetLayer? _paint(
    RenderParagraph paragraph,
    Size size,
    int pixelWidth,
    int pixelHeight,
  ) {
    final layer = OffsetLayer();
    try {
      final scaleLayer = TransformLayer(
        transform: Matrix4.diagonal3Values(
          pixelWidth / size.width,
          pixelHeight / size.height,
          1,
        ),
      );
      layer.append(scaleLayer);
      final context = _ParagraphPaintingContext(scaleLayer, Offset.zero & size);
      paragraph.paint(context, Offset.zero);
      context.finish();
      return layer;
    } catch (_) {
      layer.dispose();
      return null;
    }
  }

  /// Reads back the pixels of a layer painted by [_paint] and hands them to
  /// the platform. Returns `null` on failure. The caller still owns [layer].
  Future<int?> _saveLayer(
    OffsetLayer layer,
    int pixelWidth,
    int pixelHeight,
  ) async {
    ui.Image? image;
    try {
      image = await layer.toImage(
        Rect.fromLTWH(0, 0, pixelWidth.toDouble(), pixelHeight.toDouble()),
      );
      return await saveRasterForProcessing(image, keyGenerator.nextResourceKey);
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
    }
  }

  bool _getText(
    TextSpan span,
    StringBuffer buffer,
    TextAndInputPrivacyLevel privacy,
  ) {
    bool hasWidgetChildren = false;
    if (span.text case final text?) {
      if (privacy == TextAndInputPrivacyLevel.maskAll) {
        final masked = maskTextPreservingSpaces(text);
        buffer.write(masked);
      } else {
        buffer.write(text);
      }
    }

    span.children?.forEach((inlineSpan) {
      if (inlineSpan is TextSpan) {
        hasWidgetChildren |= _getText(inlineSpan, buffer, privacy);
      } else if (inlineSpan is WidgetSpan) {
        hasWidgetChildren = true;
      }
    });
    return hasWidgetChildren;
  }
}

/// Paints a [RenderParagraph] into its own layer tree, leaving out widgets
/// placed inline with [WidgetSpan], which are recorded as their own nodes.
class _ParagraphPaintingContext extends PaintingContext {
  _ParagraphPaintingContext(super.containerLayer, super.estimatedBounds);

  @override
  void paintChild(RenderObject child, Offset offset) {}

  void finish() => stopRecordingIfNeeded();
}

/// Everything that affects the pixels of a rasterized paragraph. A change to
/// any field, including size or bitmap size, produces a new resource.
@immutable
@visibleForTesting
final class TextRasterKey {
  final InlineSpan text;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final bool softWrap;
  final TextOverflow overflow;
  final TextScaler textScaler;
  final int? maxLines;
  final Locale? locale;
  final StrutStyle? strutStyle;
  final TextWidthBasis textWidthBasis;
  final ui.TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  /// The current selection, for paragraphs inside a [SelectionArea], whose
  /// highlight is painted with the text.
  final List<TextSelection> selections;
  final Size size;
  final int pixelWidth;
  final int pixelHeight;

  const TextRasterKey({
    required this.text,
    required this.textAlign,
    required this.textDirection,
    required this.softWrap,
    required this.overflow,
    required this.textScaler,
    required this.maxLines,
    required this.locale,
    required this.strutStyle,
    required this.textWidthBasis,
    required this.textHeightBehavior,
    required this.selectionColor,
    required this.selections,
    required this.size,
    required this.pixelWidth,
    required this.pixelHeight,
  });

  factory TextRasterKey.fromParagraph(
    RenderParagraph paragraph, {
    required int pixelWidth,
    required int pixelHeight,
  }) {
    return TextRasterKey(
      text: paragraph.text,
      textAlign: paragraph.textAlign,
      textDirection: paragraph.textDirection,
      softWrap: paragraph.softWrap,
      overflow: paragraph.overflow,
      textScaler: paragraph.textScaler,
      maxLines: paragraph.maxLines,
      locale: paragraph.locale,
      strutStyle: paragraph.strutStyle,
      textWidthBasis: paragraph.textWidthBasis,
      textHeightBehavior: paragraph.textHeightBehavior,
      selectionColor: paragraph.selectionColor,
      // RenderParagraph exposes no other way to read its selection.
      selections: paragraph.registrar == null
          ? const []
          // ignore: invalid_use_of_visible_for_testing_member
          : paragraph.selections,
      size: paragraph.size,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TextRasterKey &&
        other.text == text &&
        other.textAlign == textAlign &&
        other.textDirection == textDirection &&
        other.softWrap == softWrap &&
        other.overflow == overflow &&
        other.textScaler == textScaler &&
        other.maxLines == maxLines &&
        other.locale == locale &&
        other.strutStyle == strutStyle &&
        other.textWidthBasis == textWidthBasis &&
        other.textHeightBehavior == textHeightBehavior &&
        other.selectionColor == selectionColor &&
        listEquals(other.selections, selections) &&
        other.size == size &&
        other.pixelWidth == pixelWidth &&
        other.pixelHeight == pixelHeight;
  }

  @override
  int get hashCode => Object.hash(
    text,
    textAlign,
    textDirection,
    softWrap,
    overflow,
    textScaler,
    maxLines,
    locale,
    strutStyle,
    textWidthBasis,
    textHeightBehavior,
    selectionColor,
    Object.hashAll(selections),
    size,
    pixelWidth,
    pixelHeight,
  );
}
