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
// Default colours
// ---------------------------------------------------------------------------

const _kDefaultActiveColor = Color(0xFF6200EE); // Material purple
const _kDefaultInactiveColor = Color(0xFFBDBDBD);
const _kDefaultThumbColor = Color(0xFF6200EE);
const _kCupertinoActiveColor = Color(0xFF007AFF); // iOS blue
const _kCupertinoInactiveColor = Color(0xFFE5E5EA);

// Proportional track height relative to the widget height.
const _kTrackHeightRatio = 0.07;
// Thumb diameter relative to widget height.
const _kThumbRatio = 0.40;

// ---------------------------------------------------------------------------
// SliderRecorder
// ---------------------------------------------------------------------------

/// Records [Slider], [RangeSlider], and [CupertinoSlider] widgets.
///
/// Each slider is rendered as:
///   • an inactive (background) track — full width
///   • an active (filled) track     — from the left edge to the current value
///   • one thumb circle per handle
///
/// For [RangeSlider] the active segment spans from [values.start] to
/// [values.end] and there are two thumb circles (one per handle).
class SliderRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  const SliderRecorder(this.keyGenerator);

  @override
  List<Type> get handlesTypes => [Slider, RangeSlider, CupertinoSlider];

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is Slider) return _captureSlider(widget, element, attributes);
    if (widget is RangeSlider) {
      return _captureRangeSlider(widget, element, attributes);
    }
    if (widget is CupertinoSlider) {
      return _captureCupertinoSlider(widget, element, attributes);
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Material Slider
  // -------------------------------------------------------------------------

  CaptureNodeSemantics _captureSlider(
    Slider widget,
    Element element,
    CapturedViewAttributes attributes,
  ) {
    final inactiveKey = keyGenerator.keyForElement(element);
    final activeKey = keyGenerator.subKeyForElement(element, 0);
    final thumbKey = keyGenerator.subKeyForElement(element, 1);

    final activeColor =
        widget.activeColor ?? widget.thumbColor ?? _kDefaultActiveColor;
    final inactiveColor = widget.inactiveColor ?? _kDefaultInactiveColor;
    final thumbColor =
        widget.thumbColor ?? widget.activeColor ?? _kDefaultThumbColor;

    final norm = _normalize(widget.value, widget.min, widget.max);

    return _buildNodes(
      inactiveKey: inactiveKey,
      activeKey: activeKey,
      thumbKey: thumbKey,
      attributes: attributes,
      activeColor: activeColor,
      inactiveColor: inactiveColor,
      thumbColor: thumbColor,
      startFraction: 0.0,
      endFraction: norm,
    );
  }

  // -------------------------------------------------------------------------
  // Material RangeSlider
  // -------------------------------------------------------------------------

  CaptureNodeSemantics _captureRangeSlider(
    RangeSlider widget,
    Element element,
    CapturedViewAttributes attributes,
  ) {
    final inactiveKey = keyGenerator.keyForElement(element);
    final activeKey = keyGenerator.subKeyForElement(element, 0);
    final thumbStartKey = keyGenerator.subKeyForElement(element, 1);
    final thumbEndKey = keyGenerator.subKeyForElement(element, 2);

    final activeColor = widget.activeColor ?? _kDefaultActiveColor;
    final inactiveColor = widget.inactiveColor ?? _kDefaultInactiveColor;

    final startNorm =
        _normalize(widget.values.start, widget.min, widget.max);
    final endNorm = _normalize(widget.values.end, widget.min, widget.max);

    final bounds = attributes.paintBounds;
    final trackH = (bounds.height * _kTrackHeightRatio).clamp(2.0, 6.0);
    final trackTop = bounds.top + (bounds.height - trackH) / 2;
    final thumbDiameter = (bounds.height * _kThumbRatio).clamp(12.0, 28.0);
    final thumbTop = bounds.top + (bounds.height - thumbDiameter) / 2;

    final inactiveTrack = _trackAttributes(
      bounds: bounds,
      left: bounds.left,
      right: bounds.right,
      top: trackTop,
      height: trackH,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );
    final activeTrack = _trackAttributes(
      bounds: bounds,
      left: bounds.left + bounds.width * startNorm,
      right: bounds.left + bounds.width * endNorm,
      top: trackTop,
      height: trackH,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );

    final thumbStartAttrs = _thumbAttributes(
      left: bounds.left + bounds.width * startNorm - thumbDiameter / 2,
      top: thumbTop,
      diameter: thumbDiameter,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );
    final thumbEndAttrs = _thumbAttributes(
      left: bounds.left + bounds.width * endNorm - thumbDiameter / 2,
      top: thumbTop,
      diameter: thumbDiameter,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );

    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      nodes: [
        ContainerNode(
          inactiveTrack,
          wireframeId: inactiveKey,
          style: ContainerStyle(
            backgroundColor: inactiveColor.toHexString(),
            cornerRadius: trackH / 2,
          ),
        ),
        ContainerNode(
          activeTrack,
          wireframeId: activeKey,
          style: ContainerStyle(
            backgroundColor: activeColor.toHexString(),
            cornerRadius: trackH / 2,
          ),
        ),
        ContainerNode(
          thumbStartAttrs,
          wireframeId: thumbStartKey,
          style: ContainerStyle(
            backgroundColor: activeColor.toHexString(),
            cornerRadius: thumbDiameter / 2,
          ),
        ),
        ContainerNode(
          thumbEndAttrs,
          wireframeId: thumbEndKey,
          style: ContainerStyle(
            backgroundColor: activeColor.toHexString(),
            cornerRadius: thumbDiameter / 2,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // CupertinoSlider
  // -------------------------------------------------------------------------

  CaptureNodeSemantics _captureCupertinoSlider(
    CupertinoSlider widget,
    Element element,
    CapturedViewAttributes attributes,
  ) {
    final inactiveKey = keyGenerator.keyForElement(element);
    final activeKey = keyGenerator.subKeyForElement(element, 0);
    final thumbKey = keyGenerator.subKeyForElement(element, 1);

    final activeColor = widget.activeColor ?? _kCupertinoActiveColor;
    final inactiveColor =
        widget.trackColor ?? _kCupertinoInactiveColor;
    final thumbColor = widget.thumbColor ?? Colors.white;

    final norm = _normalize(widget.value, widget.min, widget.max);

    return _buildNodes(
      inactiveKey: inactiveKey,
      activeKey: activeKey,
      thumbKey: thumbKey,
      attributes: attributes,
      activeColor: activeColor,
      inactiveColor: inactiveColor,
      thumbColor: thumbColor,
      startFraction: 0.0,
      endFraction: norm,
    );
  }

  // -------------------------------------------------------------------------
  // Shared rendering: inactive track + active track + single thumb
  // -------------------------------------------------------------------------

  CaptureNodeSemantics _buildNodes({
    required int inactiveKey,
    required int activeKey,
    required int thumbKey,
    required CapturedViewAttributes attributes,
    required Color activeColor,
    required Color inactiveColor,
    required Color thumbColor,
    required double startFraction,
    required double endFraction,
  }) {
    final bounds = attributes.paintBounds;
    final trackH = (bounds.height * _kTrackHeightRatio).clamp(2.0, 6.0);
    final trackTop = bounds.top + (bounds.height - trackH) / 2;
    final thumbDiameter = (bounds.height * _kThumbRatio).clamp(12.0, 28.0);
    final thumbTop = bounds.top + (bounds.height - thumbDiameter) / 2;

    final inactiveTrack = _trackAttributes(
      bounds: bounds,
      left: bounds.left,
      right: bounds.right,
      top: trackTop,
      height: trackH,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );
    final activeTrack = _trackAttributes(
      bounds: bounds,
      left: bounds.left + bounds.width * startFraction,
      right: bounds.left + bounds.width * endFraction,
      top: trackTop,
      height: trackH,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );
    final thumbLeft =
        bounds.left + bounds.width * endFraction - thumbDiameter / 2;
    final thumbAttrs = _thumbAttributes(
      left: thumbLeft,
      top: thumbTop,
      diameter: thumbDiameter,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );

    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      nodes: [
        ContainerNode(
          inactiveTrack,
          wireframeId: inactiveKey,
          style: ContainerStyle(
            backgroundColor: inactiveColor.toHexString(),
            cornerRadius: trackH / 2,
          ),
        ),
        ContainerNode(
          activeTrack,
          wireframeId: activeKey,
          style: ContainerStyle(
            backgroundColor: activeColor.toHexString(),
            cornerRadius: trackH / 2,
          ),
        ),
        ContainerNode(
          thumbAttrs,
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

  double _normalize(double value, double min, double max) {
    if (max <= min) return 0.0;
    return ((value - min) / (max - min)).clamp(0.0, 1.0);
  }

  CapturedViewAttributes _trackAttributes({
    required Rect bounds,
    required double left,
    required double right,
    required double top,
    required double height,
    required double scaleX,
    required double scaleY,
  }) {
    final w = (right - left).clamp(0.0, bounds.width);
    return CapturedViewAttributes(
      paintBounds: Rect.fromLTWH(left, top, w, height),
      scaleX: scaleX,
      scaleY: scaleY,
    );
  }

  CapturedViewAttributes _thumbAttributes({
    required double left,
    required double top,
    required double diameter,
    required double scaleX,
    required double scaleY,
  }) {
    return CapturedViewAttributes(
      paintBounds: Rect.fromLTWH(left, top, diameter, diameter),
      scaleX: scaleX,
      scaleY: scaleY,
    );
  }
}
