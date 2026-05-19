// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../sr_data_models.dart';
import '../../capture_node.dart';
import '../../recorder.dart';
import '../../view_tree_snapshot.dart';
import '../material_widgets/slider_recorder.dart';
import '../recording_extensions.dart';
import 'cupertino_recording_extensions.dart';

const double _padding = 8.0;
const double _thumbRadius = 14.0;
const double _trackHalfHeight = 1.0;

typedef _SliderGeometry = ({
  Rect inactiveTrack,
  Rect activeTrack,
  Rect thumb,
});

/// Detects [CupertinoSlider] widgets and renders them in Session Replay.
class CupertinoSliderRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  const CupertinoSliderRecorder(this.keyGenerator);

  @override
  bool accepts(Widget widget) => widget is CupertinoSlider;

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is! CupertinoSlider) return null;

    // Resolves for privacy settings
    final bool isMasked = capturePrivacy.shouldMaskInputs;

    final Color activeColor = _getActiveColor(element: element, widget: widget);
    final Color trackColor = _getTrackColor(element: element);
    final Color thumbColor = _getThumbColor(element: element, widget: widget);

    final _SliderGeometry geometry = _getSliderGeometry(
      widget: widget,
      isMasked: isMasked,
      bounds: attributes.paintBounds,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );

    final inactiveTrackKey =
        keyGenerator.keyForElement(element, wireframeId: 0);
    final activeTrackKey = keyGenerator.keyForElement(element, wireframeId: 1);
    final thumbKey = keyGenerator.keyForElement(element, wireframeId: 2);

    final node = CupertinoSliderNode(
      attributes,
      inactiveTrackWireframeId: inactiveTrackKey,
      activeTrackWireframeId: activeTrackKey,
      thumbWireframeId: thumbKey,
      inactiveTrackRect: geometry.inactiveTrack,
      activeTrackRect: geometry.activeTrack,
      thumbRect: geometry.thumb,
      trackColor: trackColor,
      activeColor: activeColor,
      thumbColor: thumbColor,
    );

    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      nodes: [node],
    );
  }

  Color _getActiveColor({
    required Element element,
    required CupertinoSlider widget,
  }) {
    final base = widget.activeColor ?? CupertinoTheme.of(element).primaryColor;
    return base.resolveColor(element);
  }

  Color _getTrackColor({required Element element}) {
    return CupertinoColors.systemFill.resolveColor(element);
  }

  Color _getThumbColor({
    required Element element,
    required CupertinoSlider widget,
  }) {
    return widget.thumbColor.resolveColor(element);
  }

  _SliderGeometry _getSliderGeometry({
    required CupertinoSlider widget,
    required bool isMasked,
    required Rect bounds,
    required double scaleX,
    required double scaleY,
  }) {
    // Uniform scale preserves circles/pills and ensures dimensions fit within
    // anisotropic bounds.
    final double scale = math.min(scaleX, scaleY);

    final double padding = _padding * scale;
    final double thumbRadius = _thumbRadius * scale;
    final double trackHalfHeight = _trackHalfHeight * scale;

    final double trackLeft = bounds.left + padding;
    final double trackRight = bounds.right - padding;
    final double trackCenterY = bounds.center.dy;
    final double trackTop = trackCenterY - trackHalfHeight;
    final double trackBottom = trackCenterY + trackHalfHeight;

    final double range = widget.max - widget.min;
    final double valueRatio;
    if (isMasked) {
      valueRatio = 0.5;
    } else {
      valueRatio = range == 0
          ? 0.0
          : ((widget.value - widget.min) / range).clamp(0.0, 1.0).toDouble();
    }
    final double thumbTravel = (trackRight - trackLeft) - 2 * thumbRadius;
    final double thumbCenterX =
        trackLeft + thumbRadius + thumbTravel * valueRatio;

    final Rect inactiveTrack = Rect.fromLTRB(
      trackLeft,
      trackTop,
      trackRight,
      trackBottom,
    );
    final Rect activeTrack = Rect.fromLTRB(
      trackLeft,
      trackTop,
      math.max(trackLeft, thumbCenterX),
      trackBottom,
    );
    final Rect thumb = Rect.fromCircle(
      center: Offset(thumbCenterX, trackCenterY),
      radius: thumbRadius,
    );

    return (
      inactiveTrack: inactiveTrack,
      activeTrack: activeTrack,
      thumb: thumb,
    );
  }
}

/// Holds the resolved visual properties of a [CupertinoSlider] and builds the
/// corresponding [SRShapeWireframe]s: inactive track segment, active track
/// segment, then the circular thumb on top.
@immutable
class CupertinoSliderNode extends CaptureNode {
  final int inactiveTrackWireframeId;
  final int activeTrackWireframeId;
  final int thumbWireframeId;
  final Rect inactiveTrackRect;
  final Rect activeTrackRect;
  final Rect thumbRect;
  final Color trackColor;
  final Color activeColor;
  final Color thumbColor;

  const CupertinoSliderNode(
    super.attributes, {
    required this.inactiveTrackWireframeId,
    required this.activeTrackWireframeId,
    required this.thumbWireframeId,
    required this.inactiveTrackRect,
    required this.activeTrackRect,
    required this.thumbRect,
    required this.trackColor,
    required this.activeColor,
    required this.thumbColor,
  });

  @override
  List<SRWireframe> buildWireframes() {
    return [
      ShapeWireframeBuilder.shape(
        id: inactiveTrackWireframeId,
        rect: inactiveTrackRect,
        color: trackColor,
      ),
      ShapeWireframeBuilder.shape(
        id: activeTrackWireframeId,
        rect: activeTrackRect,
        color: activeColor,
      ),
      ShapeWireframeBuilder.shape(
        id: thumbWireframeId,
        rect: thumbRect,
        color: thumbColor,
      ),
    ];
  }
}
