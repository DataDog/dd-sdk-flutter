// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../extensions.dart';
import '../../../sr_data_models.dart';
import '../../capture_node.dart';
import '../../recorder.dart';
import '../../view_tree_snapshot.dart';
import '../recording_extensions.dart';

const Size _handleThumbSize = Size(4.0, 44.0);
const double _roundedThumbDiameter = 20.0;

enum _SliderThumbStyle { round, handle }

typedef _SliderThumbGeometry = ({
  Rect rect,
  BorderRadius borderRadius,
  _SliderThumbStyle style,
});

typedef _SliderTrackSegmentGeometry = ({
  Rect rect,
  BorderRadius borderRadius,
});

typedef _SliderGeometry = ({
  _SliderThumbGeometry thumb,
  _SliderTrackSegmentGeometry inactiveTrack,
  _SliderTrackSegmentGeometry activeTrack,
  _SliderTrackSegmentGeometry? secondaryActiveTrack,
  Rect? gap,
  Rect? stopIndicator,
  List<Rect> activeTickMarks,
  List<Rect> inactiveTickMarks,
});

/// Detects 'Slider' widgets and places an slider
/// in SessionReplay.
class SliderRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  const SliderRecorder(this.keyGenerator);

  @override
  bool accepts(Widget widget) => widget is Slider;

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is! Slider) return null;

    // Check for cupertino slider style
    {
      bool isCupertinoAdaptive = false;
      element.visitChildElements((child) {
        if (child.widget is CupertinoSlider) isCupertinoAdaptive = true;
      });
      if (isCupertinoAdaptive) return null;
    }

    // Resolves for privacy settings
    final bool isMasked = capturePrivacy.shouldMaskInputs;

    // Resolve slider theme
    final ThemeData theme = Theme.of(element);
    final SliderThemeData sliderTheme = SliderTheme.of(element);

    final bool year2023 = switch (theme.useMaterial3) {
      // ignore: deprecated_member_use
      true => widget.year2023 ?? sliderTheme.year2023 ?? true,
      false => false,
    };

    final isEnabled = widget.onChanged != null;

    final Color activeColor = _getActiveColor(
      widget: widget,
      isEnabled: isEnabled,
      theme: theme,
      sliderTheme: sliderTheme,
      year2023: year2023,
    );
    final Color inactiveColor = _getInactiveColor(
      widget: widget,
      isEnabled: isEnabled,
      theme: theme,
      sliderTheme: sliderTheme,
      year2023: year2023,
    );
    final Color secondaryActiveColor = _getSecondaryActiveColor(
      widget: widget,
      isEnabled: isEnabled,
      theme: theme,
      sliderTheme: sliderTheme,
      year2023: year2023,
    );
    final Color thumbColor = _getThumbColor(
      widget: widget,
      isEnabled: isEnabled,
      theme: theme,
      sliderTheme: sliderTheme,
      year2023: year2023,
    );
    final Color activeTickMarkColor = _getActiveTickMarkColor(
      widget: widget,
      isEnabled: isEnabled,
      theme: theme,
      sliderTheme: sliderTheme,
      year2023: year2023,
    );
    final Color inactiveTickMarkColor = _getInactiveTickMarkColor(
      widget: widget,
      isEnabled: isEnabled,
      theme: theme,
      sliderTheme: sliderTheme,
      year2023: year2023,
    );

    final _SliderGeometry geometry = _getSliderGeometry(
      widget: widget,
      theme: theme,
      sliderTheme: sliderTheme,
      year2023: year2023,
      isMasked: isMasked,
      bounds: attributes.paintBounds,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );

    // We only need the background color to create a fake gap, between the Track and the Thumb,
    // so we only grab it when geometry.gap is set. This will be true for Material 3, or when
    // year2023 is false.
    final Color? gapColor =
        geometry.gap != null ? _findBackgroundColor(element, theme) : null;

    final int tickCount =
        geometry.activeTickMarks.length + geometry.inactiveTickMarks.length;

    final inactiveTrackKey =
        keyGenerator.keyForElement(element, wireframeId: 0);
    final secondaryActiveTrackKey =
        keyGenerator.keyForElement(element, wireframeId: 1);
    final activeTrackKey = keyGenerator.keyForElement(element, wireframeId: 2);
    final List<int> tickMarkKeys = [
      for (int i = 0; i < tickCount; i++)
        keyGenerator.keyForElement(element, wireframeId: 3 + i),
    ];
    final gapKey =
        keyGenerator.keyForElement(element, wireframeId: 3 + tickCount);
    final stopIndicatorKey =
        keyGenerator.keyForElement(element, wireframeId: 4 + tickCount);
    final thumbKey =
        keyGenerator.keyForElement(element, wireframeId: 5 + tickCount);

    final node = SliderNode(
      attributes,
      inactiveTrackWireframeId: inactiveTrackKey,
      secondaryActiveTrackWireframeId: secondaryActiveTrackKey,
      activeTrackWireframeId: activeTrackKey,
      tickMarkWireframeIds: tickMarkKeys,
      gapWireframeId: gapKey,
      stopIndicatorWireframeId: stopIndicatorKey,
      thumbWireframeId: thumbKey,
      inactiveTrackRect: geometry.inactiveTrack.rect,
      secondaryActiveTrackRect: geometry.secondaryActiveTrack?.rect,
      activeTrackRect: geometry.activeTrack.rect,
      activeTickMarkRects: geometry.activeTickMarks,
      inactiveTickMarkRects: geometry.inactiveTickMarks,
      gapRect: geometry.gap,
      stopIndicatorRect: geometry.stopIndicator,
      thumbRect: geometry.thumb.rect,
      inactiveColor: inactiveColor,
      secondaryActiveColor: secondaryActiveColor,
      activeColor: activeColor,
      activeTickMarkColor: activeTickMarkColor,
      inactiveTickMarkColor: inactiveTickMarkColor,
      gapColor: gapColor,
      thumbColor: thumbColor,
    );

    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      nodes: [node],
    );
  }

  // All color values mirror Flutter’s own implementation,
  // as declared in package:flutter/src/material/slider.dart.

  Color _getActiveColor({
    required Slider widget,
    required bool isEnabled,
    required ThemeData theme,
    required SliderThemeData sliderTheme,
    required bool year2023,
  }) {
    if (isEnabled) {
      return widget.activeColor ??
          sliderTheme.activeTrackColor ??
          theme.colorScheme.primary;
    }
    Color? disabledColor = sliderTheme.disabledActiveTrackColor;
    if (disabledColor != null) return disabledColor;
    if (theme.useMaterial3) {
      return theme.colorScheme.onSurface.withValues(alpha: 0.38);
    }
    return theme.colorScheme.onSurface.withValues(alpha: 0.32);
  }

  Color _getInactiveColor({
    required Slider widget,
    required bool isEnabled,
    required ThemeData theme,
    required SliderThemeData sliderTheme,
    required bool year2023,
  }) {
    if (isEnabled) {
      Color? inactiveColor =
          widget.inactiveColor ?? sliderTheme.inactiveTrackColor;
      if (inactiveColor != null) return inactiveColor;
      if (theme.useMaterial3) {
        if (year2023) return theme.colorScheme.surfaceContainerHighest;
        return theme.colorScheme.secondaryContainer;
      }
      return theme.colorScheme.primary.withValues(alpha: 0.24);
    }
    return theme.colorScheme.onSurface.withValues(alpha: 0.12);
  }

  Color _getSecondaryActiveColor({
    required Slider widget,
    required bool isEnabled,
    required ThemeData theme,
    required SliderThemeData sliderTheme,
    required bool year2023,
  }) {
    if (isEnabled) {
      return widget.secondaryActiveColor ??
          sliderTheme.secondaryActiveTrackColor ??
          theme.colorScheme.primary.withValues(alpha: 0.54);
    }
    Color? disabledColor = sliderTheme.disabledSecondaryActiveTrackColor;
    if (disabledColor != null) return disabledColor;
    if (theme.useMaterial3 && !year2023) {
      return theme.colorScheme.onSurface.withValues(alpha: 0.38);
    }
    return theme.colorScheme.onSurface.withValues(alpha: 0.12);
  }

  Color _getThumbColor({
    required Slider widget,
    required bool isEnabled,
    required ThemeData theme,
    required SliderThemeData sliderTheme,
    required bool year2023,
  }) {
    if (isEnabled) {
      return widget.thumbColor ??
          widget.activeColor ??
          sliderTheme.thumbColor ??
          theme.colorScheme.primary;
    }
    Color? disabledColor = sliderTheme.disabledThumbColor;
    if (disabledColor != null) return disabledColor;
    if (theme.useMaterial3 && !year2023) {
      return theme.colorScheme.onSurface.withValues(alpha: 0.38);
    }
    return Color.alphaBlend(
      theme.colorScheme.onSurface.withValues(alpha: 0.38),
      theme.colorScheme.surface,
    );
  }

  _SliderGeometry _getSliderGeometry({
    required Slider widget,
    required ThemeData theme,
    required SliderThemeData sliderTheme,
    required bool year2023,
    required bool isMasked,
    required Rect bounds,
    required double scaleX,
    required double scaleY,
  }) {
    final bool isGapped = theme.useMaterial3 && !year2023;

    // Uniform scale preserves circles/pills and ensures dimensions fit within
    // anisotropic bounds.
    final double scale = math.min(scaleX, scaleY);

    final double trackHeight =
        (sliderTheme.trackHeight ?? (isGapped ? 16.0 : 4.0)) * scale;

    final _SliderThumbStyle thumbStyle;
    final Size thumbSize;
    if (isGapped) {
      thumbStyle = _SliderThumbStyle.handle;
      final Size logicalThumbSize =
          sliderTheme.thumbSize?.resolve(<WidgetState>{}) ?? _handleThumbSize;
      thumbSize = Size(
        logicalThumbSize.width * scale,
        logicalThumbSize.height * scale,
      );
    } else {
      thumbStyle = _SliderThumbStyle.round;
      thumbSize =
          Size(_roundedThumbDiameter * scale, _roundedThumbDiameter * scale);
    }

    final double overlayWidth = 48.0 * scale;
    final double horizontalInset;
    if (sliderTheme.padding != null) {
      horizontalInset = 0.0;
    } else {
      horizontalInset = math.max(thumbSize.width, overlayWidth) / 2;
    }

    final double trackLeft = bounds.left + horizontalInset;
    final double trackRight = bounds.right - horizontalInset;
    final double trackTop = bounds.center.dy - trackHeight / 2;
    final double trackBottom = trackTop + trackHeight;
    final double trackWidth = trackRight - trackLeft;

    final Radius trackEndRadius = Radius.circular(trackHeight / 2);

    final double range = widget.max - widget.min;
    // When inputs are masked, anchor the thumb at the center of the track so
    // the recorded replay doesn't leak the actual value.
    final double valueRatio;
    if (isMasked) {
      valueRatio = 0.5;
    } else {
      valueRatio = range == 0
          ? 0.0
          : ((widget.value - widget.min) / range).clamp(0.0, 1.0).toDouble();
    }
    final double thumbTravel = trackWidth - 2 * trackEndRadius.x;
    final double thumbCenterX =
        trackLeft + trackEndRadius.x + thumbTravel * valueRatio;

    final _SliderTrackSegmentGeometry inactiveTrack = (
      rect: Rect.fromLTRB(trackLeft, trackTop, trackRight, trackBottom),
      borderRadius: BorderRadius.all(trackEndRadius),
    );

    final _SliderTrackSegmentGeometry activeTrack = (
      rect: Rect.fromLTRB(
        trackLeft,
        trackTop,
        math.max(trackLeft, thumbCenterX),
        trackBottom,
      ),
      borderRadius: BorderRadius.all(trackEndRadius),
    );

    _SliderTrackSegmentGeometry? secondaryActiveTrack;
    final double? secValue = widget.secondaryTrackValue;
    if (secValue != null) {
      final clampedSec = secValue.clamp(widget.min, widget.max);
      final secRatio = range == 0 ? 0.0 : (clampedSec - widget.min) / range;
      final secX = trackLeft + trackWidth * secRatio;
      if (secX > trackLeft) {
        secondaryActiveTrack = (
          rect:
              Rect.fromLTRB(trackLeft, trackTop, secX.toDouble(), trackBottom),
          borderRadius: BorderRadius.all(trackEndRadius),
        );
      }
    }

    final Rect thumbRect = Rect.fromCenter(
      center: Offset(thumbCenterX, bounds.center.dy),
      width: thumbSize.width,
      height: thumbSize.height,
    );
    final _SliderThumbGeometry thumb = (
      rect: thumbRect,
      borderRadius:
          BorderRadius.all(Radius.circular(thumbSize.shortestSide / 2)),
      style: thumbStyle,
    );

    // M3-2024 gap: a single bg-colored band centered on the thumb that
    // overpaints the active/inactive tracks to simulate the visual gap.
    Rect? gap;
    Rect? stopIndicator;
    if (isGapped) {
      final double trackGap = (sliderTheme.trackGap ?? 6.0) * scale;
      gap = Rect.fromCenter(
        center: Offset(thumbCenterX, bounds.center.dy),
        width: thumbSize.width + 2 * trackGap,
        height: trackHeight,
      );

      final double stopRadius = 2.0 * scale;
      stopIndicator = Rect.fromCenter(
        center: Offset(trackRight - trackEndRadius.x, bounds.center.dy),
        width: stopRadius * 2,
        height: stopRadius * 2,
      );
    }

    // Tick marks for discrete (`divisions`) sliders
    final List<Rect> activeTickMarks = [];
    final List<Rect> inactiveTickMarks = [];
    final int? divisions = widget.divisions;
    if (divisions != null && divisions > 0) {
      final double tickRadius = (year2023 ? 1.0 : 2.0) * scale;
      for (int i = 0; i <= divisions; i++) {
        final double tickX =
            trackLeft + trackEndRadius.x + thumbTravel * (i / divisions);
        final Rect tickRect = Rect.fromCenter(
          center: Offset(tickX, bounds.center.dy),
          width: tickRadius * 2,
          height: tickRadius * 2,
        );
        if (tickX <= thumbCenterX) {
          activeTickMarks.add(tickRect);
        } else {
          inactiveTickMarks.add(tickRect);
        }
      }
    }

    return (
      thumb: thumb,
      inactiveTrack: inactiveTrack,
      activeTrack: activeTrack,
      secondaryActiveTrack: secondaryActiveTrack,
      gap: gap,
      stopIndicator: stopIndicator,
      activeTickMarks: activeTickMarks,
      inactiveTickMarks: inactiveTickMarks,
    );
  }

  Color _getActiveTickMarkColor({
    required Slider widget,
    required bool isEnabled,
    required ThemeData theme,
    required SliderThemeData sliderTheme,
    required bool year2023,
  }) {
    if (!isEnabled) {
      final Color defaultColor;
      if (!theme.useMaterial3) {
        defaultColor = theme.colorScheme.onPrimary.withValues(alpha: 0.12);
      } else if (year2023) {
        defaultColor = theme.colorScheme.onSurface.withValues(alpha: 0.38);
      } else {
        defaultColor = theme.colorScheme.onInverseSurface;
      }
      return sliderTheme.disabledActiveTickMarkColor ?? defaultColor;
    }
    final Color defaultColor;
    if (!theme.useMaterial3) {
      defaultColor = theme.colorScheme.onPrimary.withValues(alpha: 0.54);
    } else if (year2023) {
      defaultColor = theme.colorScheme.onPrimary.withValues(alpha: 0.38);
    } else {
      defaultColor = theme.colorScheme.onPrimary;
    }
    return widget.inactiveColor ??
        sliderTheme.activeTickMarkColor ??
        defaultColor;
  }

  Color _getInactiveTickMarkColor({
    required Slider widget,
    required bool isEnabled,
    required ThemeData theme,
    required SliderThemeData sliderTheme,
    required bool year2023,
  }) {
    if (!isEnabled) {
      final Color defaultColor;
      if (!theme.useMaterial3) {
        defaultColor = theme.colorScheme.onSurface.withValues(alpha: 0.12);
      } else if (year2023) {
        defaultColor = theme.colorScheme.onSurface.withValues(alpha: 0.38);
      } else {
        defaultColor = theme.colorScheme.onSurface;
      }
      return sliderTheme.disabledInactiveTickMarkColor ?? defaultColor;
    }
    final Color defaultColor;
    if (!theme.useMaterial3) {
      defaultColor = theme.colorScheme.primary.withValues(alpha: 0.54);
    } else if (year2023) {
      defaultColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.38);
    } else {
      defaultColor = theme.colorScheme.onSecondaryContainer;
    }
    return widget.activeColor ??
        sliderTheme.inactiveTickMarkColor ??
        defaultColor;
  }

  // Walks up the ancestor chain to find the nearest opaque background color.
  Color _findBackgroundColor(Element element, ThemeData theme) {
    Color? result;
    element.visitAncestorElements((ancestor) {
      final w = ancestor.widget;
      Color? c;
      if (w is Material && w.type != MaterialType.transparency) {
        c = w.color ??
            (w.type == MaterialType.card ? theme.cardColor : theme.canvasColor);
      } else if (w is ColoredBox) {
        c = w.color;
      } else if (w is Container) {
        final dec = w.decoration;
        c = dec is BoxDecoration ? dec.color : w.color;
      } else if (w is DecoratedBox) {
        final dec = w.decoration;
        c = dec is BoxDecoration ? dec.color : null;
      } else if (w is Card) {
        c = w.color ?? theme.cardColor;
      } else if (w is Scaffold) {
        c = w.backgroundColor ?? theme.scaffoldBackgroundColor;
      }
      if (c != null && c.a == 1.0) {
        result = c;
        return false;
      }
      return true;
    });
    return result ?? theme.colorScheme.surface;
  }
}

/// Holds the resolved visual properties of a [Slider] widget and builds the
/// corresponding [SRShapeWireframe]s: an inactive track (full background),
/// an optional secondary active segment, an active segment, and a thumb on
/// top. Each piece is rendered as a pill (cornerRadius = shortestSide / 2).
@immutable
class SliderNode extends CaptureNode {
  final int inactiveTrackWireframeId;
  final int secondaryActiveTrackWireframeId;
  final int activeTrackWireframeId;
  final List<int> tickMarkWireframeIds;
  final int gapWireframeId;
  final int stopIndicatorWireframeId;
  final int thumbWireframeId;
  final Rect inactiveTrackRect;
  final Rect? secondaryActiveTrackRect;
  final Rect activeTrackRect;
  final List<Rect> activeTickMarkRects;
  final List<Rect> inactiveTickMarkRects;
  final Rect? gapRect;
  final Rect? stopIndicatorRect;
  final Rect thumbRect;
  final Color inactiveColor;
  final Color secondaryActiveColor;
  final Color activeColor;
  final Color activeTickMarkColor;
  final Color inactiveTickMarkColor;
  final Color? gapColor;
  final Color thumbColor;

  const SliderNode(
    super.attributes, {
    required this.inactiveTrackWireframeId,
    required this.secondaryActiveTrackWireframeId,
    required this.activeTrackWireframeId,
    required this.tickMarkWireframeIds,
    required this.gapWireframeId,
    required this.stopIndicatorWireframeId,
    required this.thumbWireframeId,
    required this.inactiveTrackRect,
    required this.secondaryActiveTrackRect,
    required this.activeTrackRect,
    required this.activeTickMarkRects,
    required this.inactiveTickMarkRects,
    required this.gapRect,
    required this.stopIndicatorRect,
    required this.thumbRect,
    required this.inactiveColor,
    required this.secondaryActiveColor,
    required this.activeColor,
    required this.activeTickMarkColor,
    required this.inactiveTickMarkColor,
    required this.gapColor,
    required this.thumbColor,
  });

  @override
  List<SRWireframe> buildWireframes() {
    final wireframes = <SRWireframe>[
      ShapeWireframeBuilder.shape(
        id: inactiveTrackWireframeId,
        rect: inactiveTrackRect,
        color: inactiveColor,
      ),
    ];

    if (secondaryActiveTrackRect != null) {
      wireframes.add(ShapeWireframeBuilder.shape(
        id: secondaryActiveTrackWireframeId,
        rect: secondaryActiveTrackRect!,
        color: secondaryActiveColor,
      ));
    }

    wireframes.add(ShapeWireframeBuilder.shape(
      id: activeTrackWireframeId,
      rect: activeTrackRect,
      color: activeColor,
    ));

    // Tick marks for discrete sliders. Drawn before the gap so the gap
    // overpaints any tick near the thumb. Active ticks (over the active
    // track) use activeTickMarkColor; inactive ticks use the inactive color.
    int tickIdx = 0;
    for (final rect in activeTickMarkRects) {
      wireframes.add(ShapeWireframeBuilder.shape(
        id: tickMarkWireframeIds[tickIdx],
        rect: rect,
        color: activeTickMarkColor,
      ));
      tickIdx++;
    }
    for (final rect in inactiveTickMarkRects) {
      wireframes.add(ShapeWireframeBuilder.shape(
        id: tickMarkWireframeIds[tickIdx],
        rect: rect,
        color: inactiveTickMarkColor,
      ));
      tickIdx++;
    }

    // M3-2024 gap: overpaints the tracks around the thumb in the background
    // color. Sharp corners (cornerRadius: 0) so the cut against the rounded
    // track edges produces a clean band.
    if (gapRect != null && gapColor != null) {
      wireframes.add(ShapeWireframeBuilder.shape(
        id: gapWireframeId,
        rect: gapRect!,
        color: gapColor!,
        cornerRadius: 0,
      ));
    }

    if (stopIndicatorRect != null) {
      wireframes.add(ShapeWireframeBuilder.shape(
        id: stopIndicatorWireframeId,
        rect: stopIndicatorRect!,
        color: activeColor,
      ));
    }

    wireframes.add(ShapeWireframeBuilder.shape(
      id: thumbWireframeId,
      rect: thumbRect,
      color: thumbColor,
    ));

    return wireframes;
  }
}

/// Builds [SRShapeWireframe] instances from a [Rect] + [Color]. Shared across
/// slider recorders (material + cupertino) to avoid duplicated helpers.
class ShapeWireframeBuilder {
  const ShapeWireframeBuilder._();

  static SRShapeWireframe shape({
    required int id,
    required Rect rect,
    required Color color,
    double? cornerRadius,
  }) {
    return SRShapeWireframe(
      id: id,
      x: rect.left.safeRound(),
      y: rect.top.safeRound(),
      width: rect.width.safeRound(),
      height: rect.height.safeRound(),
      shapeStyle: SRShapeStyle(
        backgroundColor: color.toHexString(),
        cornerRadius: cornerRadius ?? rect.shortestSide / 2,
      ),
    );
  }
}
