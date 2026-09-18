// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/cupertino.dart';

import '../../capture_node.dart';
import '../../recorder.dart';
import '../../view_tree_snapshot.dart';
import '../material_widgets/radio_recorder.dart';
import '../material_widgets/switch_recorder.dart';
import '../recording_extensions.dart';
import 'cupertino_recording_extensions.dart';

const double _trackWidth = 51.0;
const double _trackHeight = 31.0;
const double _thumbRadius = 14.0;

/// Detects 'CupertinoSwitch' widgets and places a Switch icon
/// on SessionReplay.
class CupertinoSwitchRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  const CupertinoSwitchRecorder(this.keyGenerator);

  @override
  bool accepts(Widget widget) => widget is CupertinoSwitch;

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is! CupertinoSwitch) return null;

    // Resolves for privacy settings
    final bool isMasked = capturePrivacy.shouldMaskInputs;

    // Build the widget state set to drive theme resolution.
    final states = <WidgetState>{
      if (widget.onChanged == null) WidgetState.disabled,
      if (widget.value && !isMasked) WidgetState.selected,
    };

    final double disabledOpacity =
        states.contains(WidgetState.disabled) ? 0.5 : 1.0;

    Color thumbColor = _getThumbColor(widget: widget, states: states);
    Color trackColor =
        _getTrackColor(element: element, widget: widget, states: states);
    BorderSide borderSide =
        _getBorderSide(element: element, widget: widget, states: states);

    if (disabledOpacity < 1.0) {
      thumbColor = thumbColor.withValues(alpha: thumbColor.a * disabledOpacity);
      trackColor = trackColor.withValues(alpha: trackColor.a * disabledOpacity);
      borderSide = borderSide.copyWith(
        color: borderSide.color
            .withValues(alpha: borderSide.color.a * disabledOpacity),
      );
    }

    final adjustedBounds = Rect.fromCenter(
      center: attributes.paintBounds.center,
      width: (_trackWidth + borderSide.width * (borderSide.strokeAlign + 1.0)) *
          attributes.scaleX,
      height:
          (_trackHeight + borderSide.width * (borderSide.strokeAlign + 1.0)) *
              attributes.scaleX,
    );

    attributes = CapturedViewAttributes(
      paintBounds: adjustedBounds,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );

    final double dotRadius = RadioRecorder.getRadius(
        attributes: attributes, radius: _thumbRadius * attributes.scaleX);

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
      thumbIcon: null,
      thumbIconColor: const Color(0x00000000),
    );

    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy
          .ignore, // Ignore subtree to prevent CustomPaintRecorder from capturing the inner CustomPaint
      nodes: [node],
    );
  }

  Color? _resolvePropertyColor(Color? color, Set<WidgetState> states) {
    if (color is WidgetStateColor) {
      return WidgetStateProperty.resolveAs<Color?>(color, states);
    }
    return color;
  }

  Color _resolveActiveColor(CupertinoSwitch widget, Element element) {
    final CupertinoThemeData theme = CupertinoTheme.of(element);
    final Color colorToResolve;

    if (widget.activeTrackColor != null) {
      colorToResolve = widget.activeTrackColor!;
    } else if (widget.applyTheme ?? theme.applyThemeToAll) {
      colorToResolve = theme.primaryColor;
    } else {
      colorToResolve = CupertinoColors.systemGreen;
    }

    return colorToResolve.resolveColor(element);
  }

  Color? _widgetTrackColor(CupertinoSwitch widget, Set<WidgetState> states) {
    if (states.contains(WidgetState.selected)) return widget.activeTrackColor;
    return widget.inactiveTrackColor;
  }

  Color _getThumbColor({
    required CupertinoSwitch widget,
    required Set<WidgetState> states,
  }) {
    if (states.contains(WidgetState.selected)) {
      return _resolvePropertyColor(widget.thumbColor, states) ??
          CupertinoColors.white;
    }
    return _resolvePropertyColor(widget.inactiveThumbColor, states) ??
        _resolvePropertyColor(widget.thumbColor, states) ??
        CupertinoColors.white;
  }

  Color _getTrackColor({
    required Element element,
    required CupertinoSwitch widget,
    required Set<WidgetState> states,
  }) {
    return _resolvePropertyColor(_widgetTrackColor(widget, states), states) ??
        (states.contains(WidgetState.selected)
            ? _resolveActiveColor(widget, element)
            : CupertinoColors.secondarySystemFill.resolveColor(element));
  }

  BorderSide _getBorderSide({
    required Element element,
    required CupertinoSwitch widget,
    required Set<WidgetState> states,
  }) {
    final Color? outlineColor =
        widget.trackOutlineColor?.resolve(states)?.resolveColor(element);
    if (outlineColor == null) {
      return BorderSide(color: CupertinoColors.transparent, width: 0.0);
    }
    final double outlineWidth =
        widget.trackOutlineWidth?.resolve(states) ?? 2.0;

    return BorderSide(
      color: outlineColor,
      width: outlineWidth,
      strokeAlign: BorderSide.strokeAlignCenter,
    );
  }
}
