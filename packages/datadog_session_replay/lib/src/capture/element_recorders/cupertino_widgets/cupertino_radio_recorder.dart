// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/cupertino.dart';

import '../../capture_node.dart';
import '../../recorder.dart';
import '../../view_tree_snapshot.dart';
import '../material_widgets/radio_recorder.dart';
import '../recording_extensions.dart';
import 'cupertino_recording_extensions.dart';

const double _outerRadius = 7.0;
const double _innerRadius = 2.975;
const double _borderOutlineStrokeWidth = 1; // Should be 0.3

final Color _disabledOuterColor = CupertinoColors.white.withValues(alpha: 0.50);
const Color _disabledInnerColor = CupertinoDynamicColor.withBrightness(
  color: Color.fromARGB(64, 0, 0, 0),
  darkColor: Color.fromARGB(64, 255, 255, 255),
);
const Color _disabledBorderColor = CupertinoDynamicColor.withBrightness(
  color: Color.fromARGB(64, 0, 0, 0),
  darkColor: Color.fromARGB(64, 0, 0, 0),
);
const CupertinoDynamicColor _defaultBorderColor =
    CupertinoDynamicColor.withBrightness(
  color: Color.fromARGB(255, 209, 209, 214),
  darkColor: Color.fromARGB(64, 0, 0, 0),
);
const CupertinoDynamicColor _defaultInnerColor =
    CupertinoDynamicColor.withBrightness(
  color: CupertinoColors.white,
  darkColor: Color.fromARGB(255, 222, 232, 248),
);
const CupertinoDynamicColor _defaultOuterColor =
    CupertinoDynamicColor.withBrightness(
  color: CupertinoColors.activeBlue,
  darkColor: Color.fromARGB(255, 50, 100, 215),
);

/// Detects 'CupertinoRadio' widgets and places a Radio icon
/// on SessionReplay.
class CupertinoRadioRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  const CupertinoRadioRecorder(this.keyGenerator);

  @override
  bool accepts(Widget widget) => widget is CupertinoRadio;

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is! CupertinoRadio) return null;

    // Resolves for privacy settings
    final bool isMasked = capturePrivacy.shouldMaskInputs;

    final Set<WidgetState> states = RadioRecorder.getState(
        element: element, widget: widget, isMasked: isMasked);

    final Color backgroundColor =
        _getBackgroundColor(element: element, widget: widget, states: states);
    final Color fillColor =
        _getFillColor(element: element, widget: widget, states: states);
    final BorderSide borderSide =
        _getBorderSide(element: element, states: states);
    // cupertino inner radius is not customize

    final adjustedBounds = Rect.fromCenter(
      center: attributes.paintBounds.center,
      width: _outerRadius * 2.0 * attributes.scaleX,
      height: _outerRadius * 2.0 * attributes.scaleX,
    );

    attributes = CapturedViewAttributes(
      paintBounds: adjustedBounds,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );

    final double dotRadius = RadioRecorder.getRadius(
        attributes: attributes, radius: _innerRadius * attributes.scaleX);

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

  Color _getBackgroundColor({
    required Element element,
    required CupertinoRadio<dynamic> widget,
    required Set<WidgetState> states,
  }) {
    if (states.contains(WidgetState.disabled)) {
      return _disabledOuterColor.resolveColor(element);
    }
    if (states.contains(WidgetState.selected)) {
      return widget.activeColor ?? _defaultOuterColor.resolveColor(element);
    }
    return widget.inactiveColor ?? CupertinoColors.white;
  }

  Color _getFillColor({
    required Element element,
    required CupertinoRadio<dynamic> widget,
    required Set<WidgetState> states,
  }) {
    if (states.contains(WidgetState.disabled) &&
        states.contains(WidgetState.selected)) {
      widget.fillColor ?? _disabledInnerColor.resolveColor(element);
    }
    if (states.contains(WidgetState.selected)) {
      return widget.fillColor ?? _defaultInnerColor.resolveColor(element);
    }
    return CupertinoColors.white;
  }

  BorderSide _getBorderSide({
    required Element element,
    required Set<WidgetState> states,
  }) {
    if (states.contains(WidgetState.selected) &&
        !states.contains(WidgetState.disabled)) {
      return BorderSide(
        color: CupertinoColors.transparent,
        width: _borderOutlineStrokeWidth,
      );
    }
    if (states.contains(WidgetState.disabled)) {
      return BorderSide(
        color: _disabledBorderColor.resolveColor(element),
        width: _borderOutlineStrokeWidth,
      );
    }
    return BorderSide(
      color: _defaultBorderColor.resolveColor(element),
      width: _borderOutlineStrokeWidth,
    );
  }
}
