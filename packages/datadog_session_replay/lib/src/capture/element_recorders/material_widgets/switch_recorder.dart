// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../extensions.dart';
import '../../../sr_data_models.dart';
import '../../capture_node.dart';
import '../../recorder.dart';
import '../../view_tree_snapshot.dart';
import '../cupertino_widgets/cupertino_recording_extensions.dart';
import '../recording_extensions.dart';
import 'radio_recorder.dart';

/// Detects 'Switch' widgets and places a Switch icon
/// on SessionReplay.
class SwitchRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  const SwitchRecorder(this.keyGenerator);

  @override
  bool accepts(Widget widget) => widget is Switch;

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is! Switch) return null;

    // Resolves for privacy settings
    final bool isMasked = capturePrivacy.shouldMaskInputs;

    // Resolve Switch theme for colors
    final ThemeData theme = Theme.of(element);

    final bool applyCupertinoTheme = switch (theme.platform) {
      TargetPlatform.iOS ||
      TargetPlatform.macOS =>
        widget.applyCupertinoTheme ??
            theme.cupertinoOverrideTheme?.applyThemeToAll ??
            false,
      _ => false,
    };

    final bool isCupertinoStyle = _readIsCupertinoFromPainter(element);

    // Build the widget state set to drive theme resolution.
    final states = <WidgetState>{
      if (widget.onChanged == null) WidgetState.disabled,
      if (widget.value && !isMasked) WidgetState.selected,
    };

    final double trackWidth =
        isCupertinoStyle ? 51.0 : (theme.useMaterial3 ? 52.0 : 33.0);
    final double trackHeight =
        isCupertinoStyle ? 31.0 : (theme.useMaterial3 ? 32.0 : 14.0);
    final bool hasThumbIcon = widget.thumbIcon != null;
    final double thumbRadius = isCupertinoStyle
        ? 14.0
        : theme.useMaterial3
            ? (hasThumbIcon || states.contains(WidgetState.selected)
                ? 12.0
                : 8.0)
            : 10.0;
    final Icon? thumbIcon = hasThumbIcon
        ? (widget.thumbIcon?.resolve(states) ??
            theme.switchTheme.thumbIcon?.resolve(states))
        : null;

    final double disabledOpacity =
        (isCupertinoStyle && states.contains(WidgetState.disabled)) ? 0.5 : 1.0;

    Color thumbColor = _getThumbColor(
        widget: widget,
        states: states,
        isCupertinoStyle: isCupertinoStyle,
        theme: theme);
    Color thumbIconColor =
        _getThumbIconColor(thumbIcon: thumbIcon, states: states, theme: theme);
    Color trackColor = _getTrackColor(
        element: element,
        widget: widget,
        states: states,
        applyCupertinoTheme: applyCupertinoTheme,
        isCupertinoStyle: isCupertinoStyle,
        theme: theme);
    BorderSide borderSide = _getBorderSide(
        widget: widget,
        states: states,
        isCupertinoStyle: isCupertinoStyle,
        theme: theme);

    if (disabledOpacity < 1.0) {
      thumbColor = thumbColor.withValues(alpha: thumbColor.a * disabledOpacity);
      trackColor = trackColor.withValues(alpha: trackColor.a * disabledOpacity);
      borderSide = borderSide.copyWith(
        color: borderSide.color
            .withValues(alpha: borderSide.color.a * disabledOpacity),
      );
      thumbIconColor =
          thumbIconColor.withValues(alpha: thumbIconColor.a * disabledOpacity);
    }

    final adjustedBounds = Rect.fromCenter(
      center: attributes.paintBounds.center,
      width: (trackWidth + borderSide.width * (borderSide.strokeAlign + 1.0)) *
          attributes.scaleX,
      height:
          (trackHeight + borderSide.width * (borderSide.strokeAlign + 1.0)) *
              attributes.scaleX,
    );

    attributes = CapturedViewAttributes(
      paintBounds: adjustedBounds,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );

    final double dotRadius = RadioRecorder.getRadius(
        attributes: attributes, radius: thumbRadius * attributes.scaleX);

    // WireFrame keys
    final trackWireframeKey =
        keyGenerator.keyForElement(element, wireframeId: 0);
    final thumbWireframeKey =
        keyGenerator.keyForElement(element, wireframeId: 1);

    final node = SwitchNode(
      attributes,
      trackWireframeId: trackWireframeKey,
      thumbWireframeId: thumbWireframeKey,
      trackColor: trackColor,
      thumbColor: thumbColor,
      side: borderSide,
      innerRadius: dotRadius,
      isSelected: states.contains(WidgetState.selected),
      thumbIcon: thumbIcon?.icon,
      thumbIconColor: thumbIconColor,
    );

    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy
          .ignore, // Ignore subtree to prevent CustomPaintRecorder from capturing the inner CustomPaint
      nodes: [node],
    );
  }

  bool _readIsCupertinoFromPainter(Element element) {
    bool result = false;
    void visit(Element child) {
      if (result) return;
      final ro = child.renderObject;
      if (ro is RenderCustomPaint) {
        try {
          result = (ro.painter as dynamic).isCupertino as bool? ?? false;
        } on NoSuchMethodError {
          // painter does not have isCupertino — not a Cupertino-style switch
        }
        return;
      }
      child.visitChildElements(visit);
    }

    element.visitChildElements(visit);
    return result;
  }

  Color? _widgetThumbColor(Switch widget, Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) return widget.inactiveThumbColor;
    if (states.contains(WidgetState.selected)) return widget.activeThumbColor;
    return widget.inactiveThumbColor;
  }

  Color? _widgetTrackColor(Switch widget, Set<WidgetState> states) {
    if (states.contains(WidgetState.selected)) return widget.activeTrackColor;
    return widget.inactiveTrackColor;
  }

  Color _getThumbColor({
    required Switch widget,
    required Set<WidgetState> states,
    required bool isCupertinoStyle,
    required ThemeData theme,
  }) {
    return widget.thumbColor?.resolve(states) ??
        _widgetThumbColor(widget, states) ??
        theme.switchTheme.thumbColor?.resolve(states) ??
        _defaultThumbColor(
            states: states, isCupertinoStyle: isCupertinoStyle, theme: theme);
  }

  Color _getTrackColor({
    required Element element,
    required Switch widget,
    required Set<WidgetState> states,
    required bool applyCupertinoTheme,
    required bool isCupertinoStyle,
    required ThemeData theme,
  }) {
    final Color cupertinoPrimaryColor =
        theme.cupertinoOverrideTheme?.primaryColor ?? theme.colorScheme.primary;

    final Color? widgetColor =
        widget.trackColor?.resolve(states) ?? _widgetTrackColor(widget, states);
    if (widgetColor != null) return widgetColor;

    Color? themeColor;
    if (states.contains(WidgetState.selected)) {
      final Color? selectedColor = applyCupertinoTheme
          ? cupertinoPrimaryColor
          : theme.switchTheme.trackColor?.resolve(states);
      themeColor = selectedColor ??
          _widgetThumbColor(widget, states)?.withValues(alpha: 0x80 / 255.0);
    } else {
      themeColor = theme.switchTheme.trackColor?.resolve(states);
    }

    return themeColor ??
        _defaultTrackColor(
            element: element,
            states: states,
            isCupertinoStyle: isCupertinoStyle,
            theme: theme);
  }

  Color _defaultThumbColor({
    required Set<WidgetState> states,
    required bool isCupertinoStyle,
    required ThemeData theme,
  }) {
    if (isCupertinoStyle) {
      return Colors.white;
    }
    if (theme.useMaterial3) {
      if (states.contains(WidgetState.disabled)) {
        return states.contains(WidgetState.selected)
            ? theme.colorScheme.surface
            : theme.colorScheme.onSurface.withValues(alpha: 0.38);
      }
      return states.contains(WidgetState.selected)
          ? theme.colorScheme.onPrimary
          : theme.colorScheme.outline;
    } else {
      final bool isDark = theme.brightness == Brightness.dark;

      if (states.contains(WidgetState.disabled)) {
        return isDark ? Colors.grey.shade800 : Colors.grey.shade400;
      }
      return states.contains(WidgetState.selected)
          ? theme.colorScheme.secondary
          : isDark
              ? Colors.grey.shade400
              : Colors.grey.shade50;
    }
  }

  Color _defaultTrackColor({
    required Element element,
    required Set<WidgetState> states,
    required bool isCupertinoStyle,
    required ThemeData theme,
  }) {
    if (isCupertinoStyle) {
      if (states.contains(WidgetState.selected)) {
        return CupertinoColors.systemGreen.resolveColor(element);
      }
      return CupertinoColors.secondarySystemFill.resolveColor(element);
    }
    if (theme.useMaterial3) {
      if (states.contains(WidgetState.disabled)) {
        return states.contains(WidgetState.selected)
            ? theme.colorScheme.onSurface.withValues(alpha: 0.12)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.12);
      }
      return states.contains(WidgetState.selected)
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest;
    } else {
      final bool isDark = theme.brightness == Brightness.dark;

      if (states.contains(WidgetState.disabled)) {
        return isDark ? Colors.white10 : Colors.black12;
      }
      return states.contains(WidgetState.selected)
          ? theme.colorScheme.secondary.withValues(alpha: 0x80 / 255.0)
          : isDark
              ? Colors.white30
              : const Color(0x52000000); // Black with 32% opacity
    }
  }

  Color _getThumbIconColor({
    required Icon? thumbIcon,
    required Set<WidgetState> states,
    required ThemeData theme,
  }) {
    if (thumbIcon?.color case final color?) return color;
    if (!theme.useMaterial3) return Colors.transparent;
    if (states.contains(WidgetState.disabled)) {
      return states.contains(WidgetState.selected)
          ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.38);
    }
    return states.contains(WidgetState.selected)
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.surfaceContainerHighest;
  }

  BorderSide _getBorderSide({
    required Switch widget,
    required Set<WidgetState> states,
    required bool isCupertinoStyle,
    required ThemeData theme,
  }) {
    final double trackOutlineWidth =
        widget.trackOutlineWidth?.resolve(states) ??
            theme.switchTheme.trackOutlineWidth?.resolve(states) ??
            (isCupertinoStyle ? 0.0 : (theme.useMaterial3 ? 2.0 : 0.0));

    Color? trackOutlineColor = widget.trackOutlineColor?.resolve(states) ??
        theme.switchTheme.trackOutlineColor?.resolve(states);
    if (trackOutlineColor == null) {
      if (isCupertinoStyle ||
          !theme.useMaterial3 ||
          states.contains(WidgetState.selected)) {
        trackOutlineColor = Colors.transparent;
      } else if (states.contains(WidgetState.disabled)) {
        trackOutlineColor = theme.colorScheme.onSurface.withValues(alpha: 0.12);
      } else {
        trackOutlineColor = theme.colorScheme.outline;
      }
    }

    return BorderSide(
      color: trackOutlineColor,
      width: trackOutlineWidth,
      strokeAlign: BorderSide.strokeAlignCenter,
    );
  }
}

/// Holds the resolved visual properties of a [Switch, CupertinoSwitch]
/// widget and builds the correspondings [SRShapeWireframe], using the
/// shape style field to render the box.
@immutable
class SwitchNode extends CaptureNode {
  final int trackWireframeId;
  final int thumbWireframeId;
  final Color trackColor;
  final Color thumbColor;
  final BorderSide side;
  final double innerRadius;
  final bool isSelected;
  final IconData? thumbIcon;
  final Color thumbIconColor;

  const SwitchNode(
    super.attributes, {
    required this.trackWireframeId,
    required this.thumbWireframeId,
    required this.trackColor,
    required this.thumbColor,
    required this.side,
    required this.innerRadius,
    required this.isSelected,
    required this.thumbIcon,
    required this.thumbIconColor,
  });

  // Renders the radio button as two shape wireframes: the outer ring and,
  // when selected, the inner filled dot.
  @override
  List<SRWireframe> buildWireframes() {
    final dotDiameter = (innerRadius * 2.0).safeRound();
    final thumbAttributeX = isSelected
        ? attributes.x +
            attributes.width -
            ((attributes.height + dotDiameter) / 2).round()
        : attributes.x + ((attributes.height - dotDiameter) / 2).round();
    final thumbAttributeY =
        attributes.y + ((attributes.height - dotDiameter) / 2).round();

    return [
      SRShapeWireframe(
        id: trackWireframeId,
        x: attributes.x,
        y: attributes.y,
        width: attributes.width,
        height: attributes.height,
        border: SRShapeBorder(
            color: side.color.toHexString(), width: side.width.safeRound()),
        shapeStyle: SRShapeStyle(
          cornerRadius: attributes.height / 2.0,
          backgroundColor: trackColor.toHexString(),
        ),
      ),
      SRTextWireframe(
        id: thumbWireframeId,
        x: thumbAttributeX,
        y: thumbAttributeY,
        width: dotDiameter,
        height: dotDiameter,
        text:
            thumbIcon != null ? String.fromCharCode(thumbIcon!.codePoint) : '',
        textStyle: SRTextStyle(
          color: thumbIconColor.toHexString(),
          family: thumbIcon?.fontFamily ?? '',
          size: dotDiameter,
        ),
        textPosition: SRTextPosition(
          alignment: SRAlignment(
            horizontal: SRHorizontalAlignment.center,
            vertical: SRVerticalAlignment.center,
          ),
        ),
        shapeStyle: SRShapeStyle(
          cornerRadius: dotDiameter / 2.0,
          backgroundColor: thumbColor.toHexString(),
        ),
      ),
    ];
  }
}
