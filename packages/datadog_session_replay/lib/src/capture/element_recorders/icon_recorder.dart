// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../datadog_session_replay.dart';
import '../../datadog_session_replay_platform_interface.dart';
import '../../extensions.dart';
import '../../processor/font_family_transform.dart';
import '../../sr_data_models.dart';
import '../capture_node.dart';
import '../recorder.dart';
import '../view_tree_snapshot.dart';
import 'common_nodes.dart';
import 'image_recorder.dart';

/// Drawn in place of an icon that is masked or couldn't be captured.
///
/// This is `Icons.square_outlined`, which looks like the box a font draws for
/// a missing glyph. A character the font really lacks would draw differently
/// per browser, or be replaced by a fallback font's glyph.
@visibleForTesting
const int unknownIconCodePoint = 0xf0666;

const int _defaultMaxCachedRasters = 1024;

/// Captures [Icon] widgets.
///
/// Glyphs from [materialIconsFontFamily] are sent as text, because the player
/// renders that font itself. Every other icon font is drawn offscreen into a
/// transparent bitmap and sent through the same resource pipeline as images.
class IconRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  /// The number of rasterized icons whose resource keys are remembered.
  final int maxCachedRasters;

  final LinkedHashMap<IconRasterKey, int> _resourceKeys = LinkedHashMap();
  final Map<IconRasterKey, Future<int?>> _inFlight = {};

  IconRecorder(
    this.keyGenerator, {
    this.maxCachedRasters = _defaultMaxCachedRasters,
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

    final iconData = widget.icon;
    if (iconData == null) {
      // Icons without data render as an empty box.
      return IgnoredElement(subtreeStrategy: CaptureNodeSubtreeStrategy.ignore);
    }
    final (:style, :color) = resolveStyle(widget, iconData, element);
    final fontSize = style.fontSize!;
    if (fontSize <= 0) {
      return IgnoredElement(subtreeStrategy: CaptureNodeSubtreeStrategy.ignore);
    }

    final elementId = keyGenerator.keyForElement(element);
    // Icon fonts are bundled with the app, so they count as assets and are
    // only masked by [ImagePrivacyLevel.maskAll].
    if (capturePrivacy.imagePrivacyLevel == ImagePrivacyLevel.maskAll) {
      return _glyphNode(
        elementId,
        attributes,
        unknownIconCodePoint,
        fontSize,
        color,
      );
    }

    final textDirection =
        widget.textDirection ??
        Directionality.maybeOf(element) ??
        TextDirection.ltr;
    final flipped =
        iconData.matchTextDirection && textDirection == TextDirection.rtl;

    if (_canRenderAsText(iconData, style, flipped)) {
      return _glyphNode(
        elementId,
        attributes,
        iconData.codePoint,
        fontSize,
        color,
      );
    }

    // Unknown renderer font or custom icon

    // Icon lays out a square box, but subclasses such as Font Awesome's
    // FaIcon size the box to the glyph, so use the laid-out size.
    final box = element.size ?? Size.square(fontSize);
    final logicalWidth = box.width * attributes.scaleX;
    final logicalHeight = box.height * attributes.scaleY;
    final devicePixelRatio = _devicePixelRatio(element);
    final pixelWidth = rasterPixelSize(logicalWidth, devicePixelRatio);
    final pixelHeight = rasterPixelSize(logicalHeight, devicePixelRatio);

    final rasterKey = IconRasterKey.fromStyle(
      glyph: String.fromCharCode(iconData.codePoint),
      style: style,
      color: color,
      flipped: flipped,
      logicalWidth: logicalWidth,
      logicalHeight: logicalHeight,
      devicePixelRatio: devicePixelRatio,
    );

    final cachedKey = _cachedResourceKey(rasterKey);

    if (cachedKey != null) {
      return _resourceNode(elementId, attributes, cachedKey);
    }

    final span = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: style,
    );

    return AdditionalProcessingElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      process: () async {
        final resourceKey = await _rasterizeOnce(
          rasterKey,
          () => _rasterize(
            span,
            textDirection,
            box,
            flipped,
            pixelWidth,
            pixelHeight,
          ),
        );
        if (resourceKey == null) {
          return _glyphNode(
            elementId,
            attributes,
            unknownIconCodePoint,
            fontSize,
            color,
          );
        }
        return _resourceNode(elementId, attributes, resourceKey);
      },
    );
  }

  /// Resolves the style [Icon.build] draws its glyph with, from the widget's
  /// parameters and the surrounding [IconTheme].
  ///
  /// [color] is returned separately because, like [Icon], the style holds it
  /// in a foreground [Paint] instead of [TextStyle.color] when the icon has a
  /// blend mode.
  @visibleForTesting
  static ({TextStyle style, Color color}) resolveStyle(
    Icon widget,
    IconData iconData,
    BuildContext context,
  ) {
    final iconTheme = IconTheme.of(context);

    final applyTextScaling =
        widget.applyTextScaling ?? iconTheme.applyTextScaling ?? false;
    final tentativeSize = widget.size ?? iconTheme.size ?? kDefaultFontSize;
    final size = applyTextScaling
        ? (MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling).scale(
            tentativeSize,
          )
        : tentativeSize;

    final fill = widget.fill ?? iconTheme.fill;
    final weight = widget.weight ?? iconTheme.weight;
    final grade = widget.grade ?? iconTheme.grade;
    final opticalSize = widget.opticalSize ?? iconTheme.opticalSize;

    final opacity = iconTheme.opacity ?? 1.0;
    var color = widget.color ?? iconTheme.color ?? const Color(0xFF000000);
    if (opacity != 1.0) {
      color = color.withValues(alpha: color.a * opacity);
    }
    // Like Icon, a blend mode moves the color into a foreground Paint.
    final blendMode = widget.blendMode;
    final foreground = blendMode == null
        ? null
        : (Paint()
            ..blendMode = blendMode
            ..color = color);

    final style = TextStyle(
      inherit: false,
      color: foreground == null ? color : null,
      foreground: foreground,
      fontSize: size,
      fontFamily: iconData.fontFamily,
      package: iconData.fontPackage,
      fontFamilyFallback: iconData.fontFamilyFallback,
      fontVariations: [
        if (fill != null) FontVariation('FILL', fill),
        if (weight != null) FontVariation('wght', weight),
        if (grade != null) FontVariation('GRAD', grade),
        if (opticalSize != null) FontVariation('opsz', opticalSize),
      ],
      shadows: widget.shadows ?? iconTheme.shadows,
      height: 1.0,
      leadingDistribution: TextLeadingDistribution.even,
    );
    return (style: style, color: color);
  }

  /// The physical size, in pixels, of one side of the bitmap for an icon side
  /// displayed at [logicalSize].
  @visibleForTesting
  static int rasterPixelSize(double logicalSize, double devicePixelRatio) {
    final pixels = (logicalSize * devicePixelRatio).ceil();
    // A zero-sized bitmap can't be created.
    return pixels < 1 ? 1 : pixels;
  }

  static bool _canRenderAsText(
    IconData iconData,
    TextStyle style,
    bool flipped,
  ) {
    // The player only knows the plain MaterialIcons font. Anything that
    // changes how the glyph is drawn has to be rasterized.
    return iconData.fontFamily == materialIconsFontFamily &&
        iconData.fontPackage == null &&
        style.foreground == null &&
        (style.shadows?.isEmpty ?? true) &&
        !flipped;
  }

  int? _cachedResourceKey(IconRasterKey key) {
    final value = _resourceKeys.remove(key);
    if (value != null) {
      // Re-insert to mark as most recently used.
      _resourceKeys[key] = value;
    }
    return value;
  }

  Future<int?> _rasterizeOnce(
    IconRasterKey key,
    Future<int?> Function() rasterize,
  ) {
    final cached = _cachedResourceKey(key);
    if (cached != null) return Future.value(cached);

    return _inFlight.putIfAbsent(
      key,
      () => rasterize()
          .then((resourceKey) {
            if (resourceKey != null) {
              _resourceKeys[key] = resourceKey;
              while (_resourceKeys.length > maxCachedRasters) {
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

  Future<int?> _rasterize(
    TextSpan span,
    TextDirection textDirection,
    Size box,
    bool flipped,
    int pixelWidth,
    int pixelHeight,
  ) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    // Draw in the icon's own logical coordinates, then scale so the box the
    // icon lays out fills the bitmap.
    canvas.scale(pixelWidth / box.width, pixelHeight / box.height);
    if (flipped) {
      canvas.translate(box.width, 0);
      canvas.scale(-1, 1);
    }

    final painter = TextPainter(
      text: span,
      textDirection: textDirection,
      textScaler: TextScaler.noScaling,
    )..layout();
    // Icon centers the glyph within its box.
    painter.paint(
      canvas,
      Offset(
        (box.width - painter.width) / 2,
        (box.height - painter.height) / 2,
      ),
    );
    painter.dispose();

    final picture = pictureRecorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(pixelWidth, pixelHeight);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return null;

      final resourceKey = keyGenerator.nextResourceKey();
      await DatadogSessionReplayPlatform.instance.saveImageForProcessing(
        resourceKey,
        pixelWidth,
        pixelHeight,
        byteData,
      );
      return resourceKey;
    } catch (_) {
      return null;
    } finally {
      picture.dispose();
      image?.dispose();
    }
  }

  static SpecificElement _resourceNode(
    int elementId,
    CapturedViewAttributes attributes,
    int resourceKey,
  ) {
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

  /// A text node drawing [codePoint] from [materialIconsFontFamily], which the
  /// player bundles, at the icon's size and color.
  static SpecificElement _glyphNode(
    int elementId,
    CapturedViewAttributes attributes,
    int codePoint,
    double fontSize,
    Color color,
  ) {
    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      nodes: [
        TextElementCaptureNode(
          attributes,
          wireframeId: elementId,
          text: String.fromCharCode(codePoint),
          color: color.toHexString(),
          family: materialIconsFontFamily,
          size: (fontSize * attributes.scaleX).safeRound(10),
          alignment: SRHorizontalAlignment.center,
          verticalAlignment: SRVerticalAlignment.center,
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
    if (views.isNotEmpty) {
      return views.first.devicePixelRatio;
    }
    return 1.0;
  }
}

/// Everything that affects the pixels of a rasterized icon. A change to any
/// field, including size or device pixel ratio, produces a new resource.
@immutable
@visibleForTesting
class IconRasterKey {
  final String glyph;

  /// The resolved family, which includes the `packages/<name>/` prefix for
  /// fonts that ship in a package.
  final String? fontFamily;
  final List<String>? fontFamilyFallback;
  final List<ui.FontVariation>? fontVariations;
  final List<Shadow>? shadows;

  /// ARGB, with the icon theme's opacity already applied.
  final int color;
  final BlendMode? blendMode;
  final bool flipped;

  /// The on-screen size, in logical pixels, including any transform scale.
  final double logicalWidth;
  final double logicalHeight;
  final double devicePixelRatio;

  const IconRasterKey({
    required this.glyph,
    required this.fontFamily,
    required this.fontFamilyFallback,
    required this.fontVariations,
    required this.shadows,
    required this.color,
    required this.blendMode,
    required this.flipped,
    required this.logicalWidth,
    required this.logicalHeight,
    required this.devicePixelRatio,
  });

  factory IconRasterKey.fromStyle({
    required String glyph,
    required TextStyle style,
    required Color color,
    required bool flipped,
    required double logicalWidth,
    required double logicalHeight,
    required double devicePixelRatio,
  }) {
    return IconRasterKey(
      glyph: glyph,
      fontFamily: style.fontFamily,
      fontFamilyFallback: style.fontFamilyFallback,
      fontVariations: style.fontVariations,
      shadows: style.shadows,
      color: color.toARGB32(),
      // Paint has no value equality, so key on the blend mode it carries.
      blendMode: style.foreground?.blendMode,
      flipped: flipped,
      logicalWidth: logicalWidth,
      logicalHeight: logicalHeight,
      devicePixelRatio: devicePixelRatio,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IconRasterKey &&
        other.glyph == glyph &&
        other.fontFamily == fontFamily &&
        listEquals(other.fontFamilyFallback, fontFamilyFallback) &&
        listEquals(other.fontVariations, fontVariations) &&
        listEquals(other.shadows, shadows) &&
        other.color == color &&
        other.blendMode == blendMode &&
        other.flipped == flipped &&
        other.logicalWidth == logicalWidth &&
        other.logicalHeight == logicalHeight &&
        other.devicePixelRatio == devicePixelRatio;
  }

  @override
  int get hashCode => Object.hash(
    glyph,
    fontFamily,
    fontFamilyFallback == null ? null : Object.hashAll(fontFamilyFallback!),
    fontVariations == null ? null : Object.hashAll(fontVariations!),
    shadows == null ? null : Object.hashAll(shadows!),
    color,
    blendMode,
    flipped,
    logicalWidth,
    logicalHeight,
    devicePixelRatio,
  );
}
