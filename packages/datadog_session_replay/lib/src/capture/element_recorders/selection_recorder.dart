// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../extensions.dart';
import '../../sr_data_models.dart';
import '../capture_node.dart';
import '../recorder.dart';
import '../view_tree_snapshot.dart';
import 'common_nodes.dart';

// ---------------------------------------------------------------------------
// Default fallback colors (used when the widget doesn't provide its own).
// ---------------------------------------------------------------------------

/// Default Material active/accent colour (purple M2 primary).
const _kDefaultActiveColor = Color(0xFF6200EE);
const _kDefaultInactiveTrackColor = Color(0xFFBDBDBD);
const _kDefaultInactiveThumbColor = Color(0xFFFFFFFF);
const _kDefaultBorderColor = Color(0xFF757575);

/// iOS-green used by CupertinoSwitch when no activeColor is set.
const _kCupertinoActiveColor = Color(0xFF34C759);
const _kCupertinoInactiveTrackColor = Color(0xFFE5E5EA);

// ---------------------------------------------------------------------------
// SelectionControlRecorder
// ---------------------------------------------------------------------------

/// Records [Checkbox], [Switch], [CupertinoSwitch], and [Radio] widgets.
///
/// Each is rendered as one or more [ContainerNode]s so that the Session
/// Replay player can show the current checked / toggled / selected state.
///
/// [Radio] is a generic class (`Radio<T>`) so its runtime type varies with the
/// type argument; this recorder therefore leaves [handlesTypes] empty for Radio
/// and overrides [canHandle] to cover all parameterisations.
class SelectionControlRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  const SelectionControlRecorder(this.keyGenerator);

  // Checkbox / Switch / CupertinoSwitch are non-generic → register by exact type.
  @override
  List<Type> get handlesTypes => [Checkbox, Switch, CupertinoSwitch];

  // Radio<T> is generic → match via canHandle instead of the type map.
  @override
  bool canHandle(Widget widget) => widget is Radio;

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is Checkbox) {
      return _captureCheckbox(widget, element, attributes);
    }
    if (widget is Switch) {
      return _captureSwitch(widget, element, attributes);
    }
    if (widget is CupertinoSwitch) {
      return _captureCupertinoSwitch(widget, element, attributes);
    }
    if (widget is Radio) {
      return _captureRadio(widget, element, attributes);
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Checkbox
  // -------------------------------------------------------------------------

  CaptureNodeSemantics _captureCheckbox(
    Checkbox widget,
    Element element,
    CapturedViewAttributes attributes,
  ) {
    final key = keyGenerator.keyForElement(element);
    final isChecked = widget.value == true;
    final isIndeterminate = widget.tristate && widget.value == null;
    final isActive = isChecked || isIndeterminate;

    // Resolve the fill colour: widget property > fallback.
    final activeColor =
        widget.fillColor?.resolve({WidgetState.selected}) ??
        widget.activeColor ??
        _kDefaultActiveColor;

    final backgroundColor =
        isActive ? activeColor.toHexString() : srTransparentColorString;
    final borderColor =
        isActive ? activeColor.toHexString() : _kDefaultBorderColor.toHexString();
    final borderWidth = isActive ? null : 2.0;

    // The visual checkbox box is inset from the full touch-target bounds.
    final visualAttributes = _insetTouchTarget(attributes);

    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      nodes: [
        ContainerNode(
          visualAttributes,
          wireframeId: key,
          style: ContainerStyle(
            backgroundColor: backgroundColor,
            borderColor: borderColor,
            borderWidth: borderWidth,
            cornerRadius: 2.0,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Radio
  // -------------------------------------------------------------------------

  CaptureNodeSemantics _captureRadio(
    Radio<dynamic> widget,
    Element element,
    CapturedViewAttributes attributes,
  ) {
    final key = keyGenerator.keyForElement(element);
    final isSelected = widget.value == widget.groupValue;

    final activeColor =
        widget.fillColor?.resolve({WidgetState.selected}) ??
        widget.activeColor ??
        _kDefaultActiveColor;

    final backgroundColor =
        isSelected ? activeColor.toHexString() : srTransparentColorString;
    final borderColor =
        isSelected ? activeColor.toHexString() : _kDefaultBorderColor.toHexString();
    final borderWidth = isSelected ? null : 2.0;

    // Radio is always circular — force equal width/height using the shortest side.
    final visualAttributes = _toCircle(_insetTouchTarget(attributes));

    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      nodes: [
        ContainerNode(
          visualAttributes,
          wireframeId: key,
          style: ContainerStyle(
            backgroundColor: backgroundColor,
            borderColor: borderColor,
            borderWidth: borderWidth,
            cornerRadius: visualAttributes.paintBounds.shortestSide / 2,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Switch (Material)
  // -------------------------------------------------------------------------

  CaptureNodeSemantics _captureSwitch(
    Switch widget,
    Element element,
    CapturedViewAttributes attributes,
  ) {
    final trackKey = keyGenerator.keyForElement(element);
    final thumbKey = keyGenerator.subKeyForElement(element, 0);

    final isOn = widget.value;

    final activeTrackColor =
        widget.trackColor?.resolve({WidgetState.selected}) ??
        widget.activeTrackColor ??
        _kDefaultActiveColor;
    final inactiveTrackColor =
        widget.trackColor?.resolve({}) ??
        widget.inactiveTrackColor ??
        _kDefaultInactiveTrackColor;
    final thumbOnColor =
        widget.thumbColor?.resolve({WidgetState.selected}) ??
        widget.activeColor ??
        _kDefaultInactiveThumbColor;
    final thumbOffColor =
        widget.thumbColor?.resolve({}) ??
        widget.inactiveThumbColor ??
        _kDefaultInactiveThumbColor;

    return _buildSwitchNodes(
      trackKey: trackKey,
      thumbKey: thumbKey,
      isOn: isOn,
      activeTrackColor: activeTrackColor,
      inactiveTrackColor: inactiveTrackColor,
      thumbOnColor: thumbOnColor,
      thumbOffColor: thumbOffColor,
      attributes: attributes,
    );
  }

  // -------------------------------------------------------------------------
  // CupertinoSwitch
  // -------------------------------------------------------------------------

  CaptureNodeSemantics _captureCupertinoSwitch(
    CupertinoSwitch widget,
    Element element,
    CapturedViewAttributes attributes,
  ) {
    final trackKey = keyGenerator.keyForElement(element);
    final thumbKey = keyGenerator.subKeyForElement(element, 0);

    final isOn = widget.value;
    final activeTrackColor =
        widget.activeColor ?? widget.trackColor ?? _kCupertinoActiveColor;

    return _buildSwitchNodes(
      trackKey: trackKey,
      thumbKey: thumbKey,
      isOn: isOn,
      activeTrackColor: activeTrackColor,
      inactiveTrackColor: _kCupertinoInactiveTrackColor,
      thumbOnColor: widget.thumbColor ?? Colors.white,
      thumbOffColor: widget.thumbColor ?? Colors.white,
      attributes: attributes,
    );
  }

  // -------------------------------------------------------------------------
  // Shared switch rendering: track + thumb
  // -------------------------------------------------------------------------

  CaptureNodeSemantics _buildSwitchNodes({
    required int trackKey,
    required int thumbKey,
    required bool isOn,
    required Color activeTrackColor,
    required Color inactiveTrackColor,
    required Color thumbOnColor,
    required Color thumbOffColor,
    required CapturedViewAttributes attributes,
  }) {
    final bounds = attributes.paintBounds;
    final trackColor = isOn ? activeTrackColor : inactiveTrackColor;
    final thumbColor = isOn ? thumbOnColor : thumbOffColor;

    // Track: full width, shorter than the widget height (≈ 60 % of height).
    const trackHeightRatio = 0.6;
    final trackH = bounds.height * trackHeightRatio;
    final trackTop = bounds.top + (bounds.height - trackH) / 2;
    final trackBounds =
        Rect.fromLTWH(bounds.left, trackTop, bounds.width, trackH);

    final trackAttributes = CapturedViewAttributes(
      paintBounds: trackBounds,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );

    // Thumb: circle, 75 % of the widget height, left or right edge.
    final thumbDiameter = bounds.height * 0.75;
    final thumbTop = bounds.top + (bounds.height - thumbDiameter) / 2;
    const thumbEdgeInset = 2.0;
    final thumbLeft = isOn
        ? bounds.right - thumbDiameter - thumbEdgeInset
        : bounds.left + thumbEdgeInset;
    final thumbBounds =
        Rect.fromLTWH(thumbLeft, thumbTop, thumbDiameter, thumbDiameter);

    final thumbAttributes = CapturedViewAttributes(
      paintBounds: thumbBounds,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );

    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      nodes: [
        ContainerNode(
          trackAttributes,
          wireframeId: trackKey,
          style: ContainerStyle(
            backgroundColor: trackColor.toHexString(),
            cornerRadius: trackH / 2,
          ),
        ),
        ContainerNode(
          thumbAttributes,
          wireframeId: thumbKey,
          style: ContainerStyle(
            backgroundColor: thumbColor.toHexString(),
            cornerRadius: thumbDiameter / 2,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Geometry helpers
  // -------------------------------------------------------------------------

  /// Insets [attributes] to remove the standard touch-target padding
  /// (kMinInteractiveDimension = 48 dp) so the visual element is centred.
  CapturedViewAttributes _insetTouchTarget(CapturedViewAttributes attributes) {
    final bounds = attributes.paintBounds;
    // Use at most 15 logical pixels of inset on each side (proportional).
    final insetX = (bounds.width - bounds.width.clamp(0, 24)) / 2;
    final insetY = (bounds.height - bounds.height.clamp(0, 24)) / 2;
    if (insetX <= 0 && insetY <= 0) return attributes;

    final insetBounds = Rect.fromLTRB(
      bounds.left + insetX,
      bounds.top + insetY,
      bounds.right - insetX,
      bounds.bottom - insetY,
    );
    return CapturedViewAttributes(
      paintBounds: insetBounds,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );
  }

  /// Converts [attributes] to a square bounding box (shortest side) centred on
  /// the original rect — used so that radio buttons render as circles.
  CapturedViewAttributes _toCircle(CapturedViewAttributes attributes) {
    final bounds = attributes.paintBounds;
    final side = bounds.shortestSide;
    final circleBounds = Rect.fromCircle(
      center: bounds.center,
      radius: side / 2,
    );
    return CapturedViewAttributes(
      paintBounds: circleBounds,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );
  }
}
