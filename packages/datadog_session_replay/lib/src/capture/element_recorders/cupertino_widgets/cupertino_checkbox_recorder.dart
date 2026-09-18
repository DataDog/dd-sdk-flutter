// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/cupertino.dart';

import '../../capture_node.dart';
import '../../recorder.dart';
import '../../view_tree_snapshot.dart';
import '../material_widgets/checkbox_recorder.dart';
import '../recording_extensions.dart';
import 'cupertino_recording_extensions.dart';

// Default checkbox size
const double _edgeSize = CupertinoCheckbox.width; // 14 px

// Transparent border
const _transparentBorder =
    BorderSide(width: 0.0, color: CupertinoColors.transparent);

// Cupertino Colors

// Copied from cupertino/checkbox.dart — same reasoning as Material defaults
const Color _disabledCheckColor = CupertinoDynamicColor.withBrightness(
  color: Color.fromARGB(64, 0, 0, 0),
  darkColor: Color.fromARGB(64, 255, 255, 255),
);
const Color _disabledBorderColor = CupertinoDynamicColor.withBrightness(
  color: Color.fromARGB(13, 0, 0, 0),
  darkColor: Color.fromARGB(13, 0, 0, 0),
);
const CupertinoDynamicColor _defaultBorderColor =
    CupertinoDynamicColor.withBrightness(
  color: Color.fromARGB(255, 209, 209, 214),
  darkColor: Color.fromARGB(50, 128, 128, 128),
);
const CupertinoDynamicColor _defaultFillColorCupertino =
    CupertinoDynamicColor.withBrightness(
  color: CupertinoColors.activeBlue,
  darkColor: Color.fromARGB(255, 50, 100, 215),
);
const Color _defaultCheckColor = CupertinoDynamicColor.withBrightness(
  color: CupertinoColors.white,
  darkColor: Color.fromARGB(255, 222, 232, 248),
);

/// Detects 'CupertinoCheckbox' widgets and places a check box
/// in SessionReplay.
class CupertinoCheckboxRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  const CupertinoCheckboxRecorder(this.keyGenerator);

  @override
  bool accepts(Widget widget) => widget is CupertinoCheckbox;

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is! CupertinoCheckbox) return null;

    // Resolves for privacy settings
    final bool isMasked = capturePrivacy.shouldMaskInputs;

    final bool? value = (!isMasked) ? widget.value : false;

    final states = <WidgetState>{
      if (widget.onChanged == null) WidgetState.disabled,
      if (value != false) WidgetState.selected,
    };

    final Color backgroundColor =
        _getBackgroundColor(element: element, widget: widget, states: states);
    final Color symbolColor =
        _getSymbolColor(element: element, widget: widget, states: states);
    final BorderSide borderSide =
        _getBorderSide(element: element, widget: widget, states: states);
    final double cornerRadius =
        _getCornerRadius(widget: widget) * attributes.scaleX;

    final double checkboxVisualSize =
        _edgeSize + borderSide.width * (borderSide.strokeAlign + 1.0);

    final adjustedBounds = Rect.fromCenter(
      center: attributes.paintBounds.center,
      width: checkboxVisualSize * attributes.scaleX,
      height: checkboxVisualSize * attributes.scaleX,
    );

    attributes = CapturedViewAttributes(
      paintBounds: adjustedBounds,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );

    final wireframeKey = keyGenerator.keyForElement(element);

    final node = CheckboxNode(
      attributes,
      wireframeId: wireframeKey,
      value: value,
      backgroundColor: backgroundColor,
      symbolColor: symbolColor,
      side: borderSide,
      cornerRadius: cornerRadius,
      isMasked: isMasked,
    );

    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy
          .ignore, // Ignore subtree to prevent CustomPaintRecorder from capturing the inner CustomPaint
      nodes: [node],
    );
  }

  Color _getBackgroundColor({
    required Element element,
    required CupertinoCheckbox widget,
    required Set<WidgetState> states,
  }) {
    return widget.fillColor?.resolve(states) ??
        _defaultFillColor(element: element, widget: widget, states: states);
  }

  Color _defaultFillColor({
    required Element element,
    required CupertinoCheckbox widget,
    required Set<WidgetState> states,
  }) {
    if (states.contains(WidgetState.disabled)) {
      return CupertinoColors.white.withValues(alpha: 0.5);
    }
    if (states.contains(WidgetState.selected)) {
      return widget.activeColor ??
          _defaultFillColorCupertino.resolveColor(element);
    }
    return CupertinoColors.white;
  }

  Color _getSymbolColor({
    required Element element,
    required CupertinoCheckbox widget,
    required Set<WidgetState> states,
  }) {
    if (states.contains(WidgetState.disabled) &&
        states.contains(WidgetState.selected)) {
      return widget.checkColor ?? _disabledCheckColor.resolveColor(element);
    }
    if (states.contains(WidgetState.selected)) {
      return widget.checkColor ?? _defaultCheckColor.resolveColor(element);
    }
    return CupertinoColors.white;
  }

  BorderSide _getBorderSide({
    required Element element,
    required CupertinoCheckbox widget,
    required Set<WidgetState> states,
  }) {
    return widget.side.resolveSide(states) ??
        _defaultSide(element: element, states: states);
  }

  BorderSide _defaultSide({
    required Element element,
    required Set<WidgetState> states,
  }) {
    if (states.contains(WidgetState.selected) &&
        !states.contains(WidgetState.disabled)) {
      return _transparentBorder;
    }
    if (states.contains(WidgetState.disabled)) {
      return BorderSide(color: _disabledBorderColor.resolveColor(element));
    }
    return BorderSide(color: _defaultBorderColor.resolveColor(element));
  }

  double _getCornerRadius({
    required CupertinoCheckbox widget,
  }) {
    final OutlinedBorder shape = widget.shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0));

    return shape is RoundedRectangleBorder
        ? shape.borderRadius.resolve(TextDirection.ltr).topLeft.x
        : 4.0;
  }
}
