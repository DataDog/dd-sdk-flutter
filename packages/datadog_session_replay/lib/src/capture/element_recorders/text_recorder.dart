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

/// Font families of Flutter's default typography on each platform. For Latin
/// text, their glyphs stay within the line boxes Flutter lays out, so
/// paragraphs drawn only with them don't need a margin for glyph ink.
const Set<String> _platformDefaultFontFamilies = {
  'Roboto',
  'CupertinoSystemText',
  'CupertinoSystemDisplay',
  '.AppleSystemUIFont',
  'Segoe UI',
  '.SF UI Text',
  '.SF UI Display',
};

/// The last code point of Latin Extended-B. Other scripts can have marks that
/// reach past the line, or be drawn with a fallback font.
const int _lastLatinCodePoint = 0x024F;

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

    // Capture runs on a timer, so a paragraph can be waiting for layout, for
    // example after a system font change. Its text metrics aren't valid then.
    // debugNeedsLayout only works in debug builds, where text metrics assert.
    if (kDebugMode && paragraph.debugNeedsLayout) return null;

    final size = paragraph.size;
    if (size.isEmpty) return null;

    final scale = math.max(attributes.scaleX, attributes.scaleY);
    if (scale <= 0) return null;

    final bounds = paintedBounds(paragraph);
    final rasterAttributes = bounds == Offset.zero & size
        ? attributes
        : _attributesFor(bounds, size, attributes);
    final (:width, :height) = bitmapSizeAt(
      bounds.size,
      devicePixelRatioOf(element) * rasterScale(scale),
    );
    final (width: pixelWidth, height: pixelHeight) = fitPixelBudget(
      width,
      height,
      maxImagePixelBudget,
    );

    final rasterKey = TextRasterKey.fromParagraph(
      paragraph,
      bounds: bounds,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
    );
    SpecificElement resourceSemantics(int resourceKey) => resourceElement(
      rasterAttributes,
      wireframeId: wireframeId,
      resourceKey: resourceKey,
      subtreeStrategy: subtreeStrategy,
    );

    final cachedKey = _rasterCache.lookup(rasterKey);
    if (cachedKey != null) return resourceSemantics(cachedKey);

    // Paint now (cheap), while the paragraph shows this frame. Reading the pixels
    // back waits for [AdditionalProcessingElement.process], which the recorder runs
    // one element at a time, so readbacks don't pile up on text-heavy screens.
    final layer = _paint(paragraph, bounds, pixelWidth, pixelHeight);
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

  /// The area [paragraph] paints, in its own coordinates.
  @visibleForTesting
  static Rect paintedBounds(RenderParagraph paragraph) {
    final box = Offset.zero & paragraph.size;
    final textSize = paragraph.textSize;

    final overflows =
        box.width < textSize.width ||
        box.height < textSize.height ||
        paragraph.didExceedMaxLines;
    if (overflows && paragraph.overflow != TextOverflow.visible) return box;

    final text = overflows ? box.expandToInclude(Offset.zero & textSize) : box;

    var maxFontSize = 0.0;
    var needsInkMargin = false;
    final shadows = <Shadow>[];

    void visit(InlineSpan span, TextStyle inherited) {
      if (span is! TextSpan) return;
      final style = inherited.merge(span.style);
      if (span.text case final text? when text.isNotEmpty) {
        maxFontSize = math.max(
          maxFontSize,
          paragraph.textScaler.scale(style.fontSize ?? kDefaultFontSize),
        );
        // Once one span needs the margin, the rest don't need checking.
        needsInkMargin = needsInkMargin || !_staysInLineBoxes(style, text);
        shadows.addAll(style.shadows ?? const []);
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        visit(child, style);
      }
    }

    visit(paragraph.text, const TextStyle());

    final ink = needsInkMargin ? text.inflate(maxFontSize / 2) : text;
    var bounds = ink;
    for (final shadow in shadows) {
      // A Gaussian blur fades out within about three sigmas.
      bounds = bounds.expandToInclude(
        ink.shift(shadow.offset).inflate(3 * shadow.blurSigma),
      );
    }
    return bounds;
  }

  /// Whether [text] drawn with [style] stays within its line boxes: upright
  /// Latin text in a platform default font, with normal line height and
  /// letter spacing.
  static bool _staysInLineBoxes(TextStyle style, String text) {
    final fontFamily = style.fontFamily;
    return (fontFamily == null ||
            _platformDefaultFontFamilies.contains(fontFamily)) &&
        (style.fontStyle ?? FontStyle.normal) == FontStyle.normal &&
        (style.fontVariations?.isEmpty ?? true) &&
        (style.height ?? 1) >= 1 &&
        (style.letterSpacing ?? 0) >= 0 &&
        text.runes.every((codePoint) => codePoint <= _lastLatinCodePoint);
  }

  /// [attributes], which cover the paragraph's layout box of [size], moved and
  /// resized to cover [bounds] in the paragraph's coordinates instead.
  static CapturedViewAttributes _attributesFor(
    Rect bounds,
    Size size,
    CapturedViewAttributes attributes,
  ) {
    final box = attributes.paintBounds;
    final scaleX = box.width / size.width;
    final scaleY = box.height / size.height;
    return CapturedViewAttributes(
      paintBounds: Rect.fromLTWH(
        box.left + bounds.left * scaleX,
        box.top + bounds.top * scaleY,
        bounds.width * scaleX,
        bounds.height * scaleY,
      ),
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );
  }

  /// Paints the [bounds] area of [paragraph] into a new layer tree scaled to
  /// fill a [pixelWidth] × [pixelHeight] bitmap. Returns `null` if painting
  /// fails.
  static OffsetLayer? _paint(
    RenderParagraph paragraph,
    Rect bounds,
    int pixelWidth,
    int pixelHeight,
  ) {
    final layer = OffsetLayer();
    try {
      final scaleLayer = TransformLayer(
        transform: Matrix4.diagonal3Values(
          pixelWidth / bounds.width,
          pixelHeight / bounds.height,
          1,
        )..translateByDouble(-bounds.left, -bounds.top, 0, 1),
      );
      layer.append(scaleLayer);
      final context = _ParagraphPaintingContext(scaleLayer, bounds);
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

  /// The area the paragraph paints, in its own coordinates. See
  /// [TextElementRecorder.paintedBounds].
  final Rect bounds;
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
    required this.bounds,
    required this.pixelWidth,
    required this.pixelHeight,
  });

  factory TextRasterKey.fromParagraph(
    RenderParagraph paragraph, {
    required Rect bounds,
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
      bounds: bounds,
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
        other.bounds == bounds &&
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
    bounds,
    pixelWidth,
    pixelHeight,
  );
}
