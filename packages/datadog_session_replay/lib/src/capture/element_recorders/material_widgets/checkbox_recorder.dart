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

// Material Icons glyphs that represent each checkbox state. Using the same
// font Flutter ships with means the rendered checkmark/dash/mask matches the
// real Material stroke weight far better than a generic Unicode character in
// a fallback sans-serif font.
const IconData _checkIcon = Icons.check;
const IconData _dashIcon = Icons.remove;
const IconData _maskedIcon = Icons.close;

// Scale for the text size within the box
const double _textScale = 0.9;

// Default checkbox size
const double _edgeSize = Checkbox.width; // 18 px
const double _strokeWidth = 2.0;
const double _opacityDisabled = 0.38;

// Transparent border
const _transparentBorder =
    BorderSide(width: _strokeWidth, color: Colors.transparent);

/// Detects 'Checkbox' widgets and places a check box
/// in SessionReplay.
class CheckboxRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  const CheckboxRecorder(this.keyGenerator);

  @override
  bool accepts(Widget widget) => widget is Checkbox;

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    // Check for cupertino checkbox style
    {
      bool isCupertinoAdaptive = false;
      element.visitChildElements((child) {
        if (child.widget is CupertinoCheckbox) isCupertinoAdaptive = true;
      });
      if (isCupertinoAdaptive) return null;
    }

    final widget = element.widget;
    if (widget is! Checkbox) return null;

    // Resolves for privacy settings
    final bool isMasked = capturePrivacy.shouldMaskInputs;

    // Resolve checkbox theme for colors
    final ThemeData theme = Theme.of(element);

    final bool? value = (!isMasked) ? widget.value : false;

    final states = <WidgetState>{
      if (widget.onChanged == null) WidgetState.disabled,
      if (value != false) WidgetState.selected,
      if (widget.isError) WidgetState.error,
    };

    final Color backgroundColor =
        _getBackgroundColor(widget: widget, states: states, theme: theme);
    final Color symbolColor =
        _getSymbolColor(widget: widget, states: states, theme: theme);
    final BorderSide borderSide =
        _getBorderSide(widget: widget, states: states, theme: theme);
    final double cornerRadius =
        _getCornerRadius(widget: widget, theme: theme) * attributes.scaleX;

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
    required Checkbox widget,
    required Set<WidgetState> states,
    required ThemeData theme,
  }) {
    return widget.fillColor?.resolve(states) ??
        (states.contains(WidgetState.disabled)
            ? null
            : (states.contains(WidgetState.selected)
                ? widget.activeColor
                : null)) ??
        theme.checkboxTheme.fillColor?.resolve(states) ??
        _defaultFillColor(states: states, theme: theme);
  }

  Color _defaultFillColor({
    required Set<WidgetState> states,
    required ThemeData theme,
  }) {
    if (states.contains(WidgetState.disabled)) {
      return states.contains(WidgetState.selected)
          ? (theme.useMaterial3
              ? theme.colorScheme.onSurface.withValues(alpha: _opacityDisabled)
              : theme.disabledColor)
          : Colors.transparent;
    }
    if (states.contains(WidgetState.selected)) {
      if (theme.useMaterial3) {
        return states.contains(WidgetState.error)
            ? theme.colorScheme.error
            : theme.colorScheme.primary;
      }
      return theme.colorScheme.secondary;
    }
    return Colors.transparent;
  }

  Color _getSymbolColor({
    required Checkbox widget,
    required Set<WidgetState> states,
    required ThemeData theme,
  }) {
    return widget.checkColor ??
        theme.checkboxTheme.checkColor?.resolve(states) ??
        _defaultCheckColor(states: states, theme: theme);
  }

  Color _defaultCheckColor({
    required Set<WidgetState> states,
    required ThemeData theme,
  }) {
    if (theme.useMaterial3) {
      if (states.contains(WidgetState.disabled)) {
        if (states.contains(WidgetState.selected)) {
          return theme.colorScheme.surface;
        }
        return Colors
            .transparent; // No icons available when the checkbox is unselected.
      }

      if (states.contains(WidgetState.selected)) {
        if (states.contains(WidgetState.error)) {
          return theme.colorScheme.onError;
        }
        return theme.colorScheme.onPrimary;
      }
      return Colors
          .transparent; // No icons available when the checkbox is unselected.
    }

    return Color(0xFFFFFFFF);
  }

  BorderSide _getBorderSide({
    required Checkbox widget,
    required Set<WidgetState> states,
    required ThemeData theme,
  }) {
    return widget.side.resolveSide(states) ??
        theme.checkboxTheme.side.resolveSide(states) ??
        _defaultSide(theme: theme, states: states);
  }

  BorderSide _defaultSide({
    required ThemeData theme,
    required Set<WidgetState> states,
  }) {
    if (states.contains(WidgetState.disabled)) {
      if (states.contains(WidgetState.selected)) {
        return _transparentBorder;
      }
      return BorderSide(
          width: _strokeWidth,
          color: (theme.useMaterial3
              ? theme.colorScheme.onSurface.withValues(alpha: _opacityDisabled)
              : theme.disabledColor));
    }
    if (states.contains(WidgetState.selected)) {
      return _transparentBorder;
    }
    if (theme.useMaterial3) {
      if (states.contains(WidgetState.error)) {
        return BorderSide(width: _strokeWidth, color: theme.colorScheme.error);
      }
      return BorderSide(
        width: _strokeWidth,
        color: theme.colorScheme.onSurfaceVariant,
      );
    }

    return BorderSide(
      width: _strokeWidth,
      color: theme.unselectedWidgetColor,
    );
  }

  double _getCornerRadius({
    required Checkbox widget,
    required ThemeData theme,
  }) {
    final OutlinedBorder shape = widget.shape ??
        theme.checkboxTheme.shape ??
        RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(theme.useMaterial3 ? 2.0 : 1.0)),
        );

    return shape is RoundedRectangleBorder
        ? shape.borderRadius.resolve(TextDirection.ltr).topLeft.x
        : (theme.useMaterial3 ? 2.0 : 1.0);
  }
}

/// Holds the resolved visual properties of a [Checkbox, CupertinoCheckbox]
/// widget and builds the corresponding [SRTextWireframe], using the text
/// field to render the checkmark symbol and the shape style for the box
/// background and border.
@immutable
class CheckboxNode extends CaptureNode {
  final int wireframeId;
  final bool? value;
  final Color backgroundColor;
  final Color symbolColor;
  final BorderSide side;
  final double cornerRadius;
  final bool isMasked;

  const CheckboxNode(
    super.attributes, {
    required this.value,
    required this.wireframeId,
    required this.symbolColor,
    required this.backgroundColor,
    required this.side,
    required this.cornerRadius,
    required this.isMasked,
  });

  // Renders the checkbox as a single SRTextWireframe: the box shape is drawn
  // via shapeStyle/border, and the checkmark symbol is centered as text.
  @override
  List<SRWireframe> buildWireframes() {
    final IconData? symbolIcon = switch ((isMasked, value)) {
      (true, _) => _maskedIcon,
      (_, true) => _checkIcon,
      (_, false) => null,
      (_, null) => _dashIcon,
    };
    final String symbol =
        symbolIcon != null ? String.fromCharCode(symbolIcon.codePoint) : '';

    return [
      SRTextWireframe(
        id: wireframeId,
        x: attributes.x,
        y: attributes.y,
        width: attributes.width,
        height: attributes.height,
        text: symbol,
        textStyle: SRTextStyle(
          color: symbolColor.toHexString(),
          family: symbolIcon?.fontFamily ?? '',
          size: (attributes.height * _textScale).safeRound(),
        ),
        textPosition: SRTextPosition(
          alignment: SRAlignment(
            horizontal: SRHorizontalAlignment.center,
            vertical: SRVerticalAlignment.center,
          ),
        ),
        border: SRShapeBorder(
            color: side.color.toHexString(), width: side.width.safeRound()),
        shapeStyle: SRShapeStyle(
          backgroundColor: backgroundColor.toHexString(),
          cornerRadius: cornerRadius,
        ),
      )
    ];
  }
}
