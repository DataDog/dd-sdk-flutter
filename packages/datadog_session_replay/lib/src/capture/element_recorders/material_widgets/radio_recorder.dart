// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../extensions.dart';
import '../../../sr_data_models.dart';
import '../../capture_node.dart';
import '../../recorder.dart';
import '../../view_tree_snapshot.dart';
import '../recording_extensions.dart';

const double _outerRadius = 8.0;
const double _innerRadius = 4.5;
const double _defaultBorderThickness = 2.0;

/// Detects 'Radio' widgets and places a Radio icon
/// on SessionReplay.
class RadioRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  const RadioRecorder(this.keyGenerator);

  @override
  bool accepts(Widget widget) => widget is Radio;

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    // Check for cupertino radio style
    {
      bool isCupertinoAdaptive = false;
      element.visitChildElements((child) {
        if (child.widget is CupertinoRadio) isCupertinoAdaptive = true;
      });
      if (isCupertinoAdaptive) return null;
    }

    final widget = element.widget;
    if (widget is! Radio) return null;

    // Resolves for privacy settings
    final bool isMasked = capturePrivacy.shouldMaskInputs;

    // Resolve radio theme for colors
    final ThemeData theme = Theme.of(element);

    // Build the widget state set to drive theme resolution.
    final Set<WidgetState> states =
        getState(element: element, widget: widget, isMasked: isMasked);

    final Color backgroundColor =
        _getBackgroundColor(widget: widget, states: states, theme: theme);
    final Color fillColor =
        _getFillColor(widget: widget, states: states, theme: theme);
    final BorderSide borderSide = _getBorderSide(
        widget: widget, states: states, theme: theme, fillColor: fillColor);
    final double innerRadius =
        _getInnerRadius(widget: widget, states: states, theme: theme)
            .clamp(0.0, _outerRadius);

    final double outerRadioVisualSize =
        _outerRadius + borderSide.width * (borderSide.strokeAlign + 1.0) / 2.0;

    final adjustedBounds = Rect.fromCenter(
      center: attributes.paintBounds.center,
      width: outerRadioVisualSize * 2.0 * attributes.scaleX,
      height: outerRadioVisualSize * 2.0 * attributes.scaleX,
    );

    attributes = CapturedViewAttributes(
      paintBounds: adjustedBounds,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );

    final double dotRadius = getRadius(
        attributes: attributes, radius: innerRadius * attributes.scaleX);

    // WireFrame keys
    final backgroundWireframeKey =
        keyGenerator.keyForElement(element, wireframeId: 0);
    final foregroundWireframeKey =
        keyGenerator.keyForElement(element, wireframeId: 1);

    final node = RadioNode(
      attributes,
      backgroundWireframeId: backgroundWireframeKey,
      foregroundWireframeId: foregroundWireframeKey,
      backgroundColor: backgroundColor,
      fillColor: fillColor,
      side: borderSide,
      innerRadius: dotRadius,
      isSelected: states.contains(WidgetState.selected),
    );

    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy
          .ignore, // Ignore subtree to prevent CustomPaintRecorder from capturing the inner CustomPaint
      nodes: [node],
    );
  }

  static Set<WidgetState> getState<T>({
    required Element element,
    required Widget widget,
    required bool isMasked,
  }) {
    final T? value;
    final bool? enabled;
    final bool hasCallbacks;

    if (widget is Radio<T>) {
      value = widget.value;
      enabled = widget.enabled;
      // ignore: deprecated_member_use
      hasCallbacks = widget.onChanged != null || widget.groupRegistry != null;
    } else if (widget is CupertinoRadio<T>) {
      value = widget.value;
      enabled = widget.enabled;
      // ignore: deprecated_member_use
      hasCallbacks = widget.onChanged != null || widget.groupRegistry != null;
    } else {
      return <WidgetState>{
        WidgetState.disabled,
      };
    }

    bool? resolvedEnabled = enabled ?? (hasCallbacks ? true : null);

    bool isSelected = false;
    bool hasMatchingGroup = false;

    if (!isMasked || resolvedEnabled == null) {
      element.visitAncestorElements((ancestor) {
        final ancestorWidget = ancestor.widget;
        if (ancestorWidget is RadioGroup) {
          hasMatchingGroup = ancestorWidget is RadioGroup<T>;
          isSelected = (!isMasked && hasMatchingGroup)
              ? (ancestorWidget.groupValue == value)
              : false;
          return false;
        }
        return true;
      });
    }

    bool isEnabled = resolvedEnabled ?? hasMatchingGroup;

    return <WidgetState>{
      if (!isEnabled) WidgetState.disabled,
      if (isSelected) WidgetState.selected,
    };
  }

  Color _getFillColor({
    required Radio<dynamic> widget,
    required Set<WidgetState> states,
    required ThemeData theme,
  }) {
    return widget.fillColor?.resolve(states) ??
        (states.contains(WidgetState.selected) ? widget.activeColor : null) ??
        theme.radioTheme.fillColor?.resolve(states) ??
        switch (theme.useMaterial3) {
          false => states.contains(WidgetState.disabled)
              ? theme.disabledColor
              : states.contains(WidgetState.selected)
                  ? theme.colorScheme.secondary
                  : theme.unselectedWidgetColor,
          true => states.contains(WidgetState.disabled)
              ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
              : states.contains(WidgetState.selected)
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
        };
  }

  Color _getBackgroundColor({
    required Radio<dynamic> widget,
    required Set<WidgetState> states,
    required ThemeData theme,
  }) {
    return widget.backgroundColor?.resolve(states) ??
        theme.radioTheme.backgroundColor?.resolve(states) ??
        Colors.transparent;
  }

  BorderSide _getBorderSide({
    required Radio<dynamic> widget,
    required Set<WidgetState> states,
    required ThemeData theme,
    required Color fillColor,
  }) {
    return widget.side.resolveSide(states) ??
        theme.radioTheme.side.resolveSide(states) ??
        BorderSide(
          color: fillColor,
          width: _defaultBorderThickness,
          strokeAlign: BorderSide.strokeAlignCenter,
        );
  }

  double _getInnerRadius({
    required Radio<dynamic> widget,
    required Set<WidgetState> states,
    required ThemeData theme,
  }) {
    return widget.innerRadius?.resolve(states) ??
        theme.radioTheme.innerRadius?.resolve(states) ??
        _innerRadius;
  }

  static double getRadius({
    required CapturedViewAttributes attributes,
    required double radius,
  }) {
    final h = attributes.height;

    // Preserves .5 precision
    int h2 = (h * 2).round();
    int r2 = (radius * 2).safeRound();

    if ((h2 - 2 * r2) % 4 == 0) {
      return r2 / 2.0;
    }

    int r2Down = r2 - 1;
    int r2Up = r2 + 1;

    if ((h2 - 2 * r2Down) % 4 == 0) {
      return r2Down / 2.0;
    }

    if ((h2 - 2 * r2Up) % 4 == 0) {
      return r2Up / 2.0;
    }

    return r2Down / 2.0; // shouldn't happen
  }
}

/// Holds the resolved visual properties of a [Radio, CupertinoRadio]
/// widget and builds the correspondings [SRShapeWireframe], using the
/// shape style field to render the box as a circle with a defined
/// background and border field to set the border style.
@immutable
class RadioNode extends CaptureNode {
  final int backgroundWireframeId;
  final int foregroundWireframeId;
  final Color backgroundColor;
  final Color fillColor;
  final BorderSide side;
  final double innerRadius;
  final bool isSelected;

  const RadioNode(
    super.attributes, {
    required this.backgroundWireframeId,
    required this.foregroundWireframeId,
    required this.backgroundColor,
    required this.fillColor,
    required this.side,
    required this.innerRadius,
    required this.isSelected,
  });

  // Renders the radio button as two shape wireframes: the outer ring and,
  // when selected, the inner filled dot.
  @override
  List<SRWireframe> buildWireframes() {
    final wireframes = [
      SRShapeWireframe(
        id: backgroundWireframeId,
        x: attributes.x,
        y: attributes.y,
        width: attributes.width,
        height: attributes.height,
        border: SRShapeBorder(
            color: side.color.toHexString(), width: side.width.safeRound()),
        shapeStyle: SRShapeStyle(
          cornerRadius: attributes.height / 2.0,
          backgroundColor: backgroundColor.toHexString(),
        ),
      ),
    ];

    if (isSelected) {
      final dotDiameter = (innerRadius * 2.0).safeRound();

      wireframes.add(
        SRShapeWireframe(
          id: foregroundWireframeId,
          x: attributes.x + ((attributes.width - dotDiameter) / 2).safeRound(),
          y: attributes.y + ((attributes.height - dotDiameter) / 2).safeRound(),
          width: dotDiameter,
          height: dotDiameter,
          shapeStyle: SRShapeStyle(
            cornerRadius: dotDiameter / 2.0,
            backgroundColor: fillColor.toHexString(),
          ),
        ),
      );
    }

    return wireframes;
  }
}
