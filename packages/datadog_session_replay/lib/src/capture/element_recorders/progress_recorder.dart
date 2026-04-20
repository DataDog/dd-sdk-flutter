// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:math' as math;

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

const _kDefaultIndicatorColor = Color(0xFF6200EE); // Material purple
const _kDefaultTrackColor = Color(0xFFE0E0E0);

// ---------------------------------------------------------------------------
// ProgressRecorder
// ---------------------------------------------------------------------------

/// Records [LinearProgressIndicator] and [CircularProgressIndicator].
///
/// **LinearProgressIndicator**
///   • Determinate (`value != null`): background track + filled portion.
///   • Indeterminate (`value == null`): background track only (the animation
///     state cannot be captured; a full-width tinted track conveys "loading").
///
/// **CircularProgressIndicator**
///   • Rendered as a circular ring (using `cornerRadius` equal to half the
///     shortest side).  The fill level is approximated by overlaying a smaller
///     opaque circle whose size corresponds to the progress value.
///   • Indeterminate: shows only the ring.
class ProgressRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  const ProgressRecorder(this.keyGenerator);

  @override
  List<Type> get handlesTypes => [
        LinearProgressIndicator,
        CircularProgressIndicator,
      ];

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is LinearProgressIndicator) {
      return _captureLinear(widget, element, attributes);
    }
    if (widget is CircularProgressIndicator) {
      return _captureCircular(widget, element, attributes);
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // LinearProgressIndicator
  // -------------------------------------------------------------------------

  CaptureNodeSemantics _captureLinear(
    LinearProgressIndicator widget,
    Element element,
    CapturedViewAttributes attributes,
  ) {
    final trackKey = keyGenerator.keyForElement(element);
    final fillKey = keyGenerator.subKeyForElement(element, 0);

    final indicatorColor = _resolveColor(widget.color) ?? _kDefaultIndicatorColor;
    final trackColor =
        _resolveColor(widget.backgroundColor) ?? _kDefaultTrackColor;

    final bounds = attributes.paintBounds;

    // Track: full bounds.
    final trackAttrs = attributes;

    // Determine fill fraction:
    //   value == null → indeterminate; show a partial fill to indicate activity.
    const indeterminateFraction = 0.4;
    final fraction = widget.value?.clamp(0.0, 1.0) ?? indeterminateFraction;
    final fillWidth = bounds.width * fraction;

    final fillAttrs = CapturedViewAttributes(
      paintBounds: Rect.fromLTWH(
        bounds.left,
        bounds.top,
        fillWidth,
        bounds.height,
      ),
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );

    final cornerRadius = bounds.height / 2;

    final nodes = <CaptureNode>[
      ContainerNode(
        trackAttrs,
        wireframeId: trackKey,
        style: ContainerStyle(
          backgroundColor: trackColor.toHexString(),
          cornerRadius: cornerRadius,
        ),
      ),
    ];

    // Only add the fill node if there is visible progress.
    if (fillWidth > 0) {
      nodes.add(
        ContainerNode(
          fillAttrs,
          wireframeId: fillKey,
          style: ContainerStyle(
            backgroundColor: indicatorColor.toHexString(),
            cornerRadius: cornerRadius,
          ),
        ),
      );
    }

    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      nodes: nodes,
    );
  }

  // -------------------------------------------------------------------------
  // CircularProgressIndicator
  // -------------------------------------------------------------------------

  CaptureNodeSemantics _captureCircular(
    CircularProgressIndicator widget,
    Element element,
    CapturedViewAttributes attributes,
  ) {
    final ringKey = keyGenerator.keyForElement(element);
    final fillKey = keyGenerator.subKeyForElement(element, 0);

    final indicatorColor = _resolveColor(widget.color) ?? _kDefaultIndicatorColor;
    final trackColor =
        _resolveColor(widget.backgroundColor) ?? _kDefaultTrackColor;

    final bounds = attributes.paintBounds;
    final side = math.min(bounds.width, bounds.height);
    final radius = side / 2;

    // Centre the circle within the widget bounds.
    final circleBounds = Rect.fromCircle(
      center: bounds.center,
      radius: radius,
    );
    final circleAttrs = CapturedViewAttributes(
      paintBounds: circleBounds,
      scaleX: attributes.scaleX,
      scaleY: attributes.scaleY,
    );

    // The ring stroke width is approximated as ~10 % of the diameter.
    final strokeWidth = (side * 0.10).clamp(2.0, 8.0);

    // Outer ring (track colour).
    final nodes = <CaptureNode>[
      ContainerNode(
        circleAttrs,
        wireframeId: ringKey,
        style: ContainerStyle(
          backgroundColor: trackColor.toHexString(),
          borderColor: indicatorColor.toHexString(),
          borderWidth: strokeWidth,
          cornerRadius: radius,
        ),
      ),
    ];

    // For determinate state, overlay a smaller filled arc approximation.
    // We use a clipped inner circle whose diameter scales with the value.
    final value = widget.value;
    if (value != null && value > 0) {
      final fraction = value.clamp(0.0, 1.0);
      // Inner fill radius proportional to progress (purely visual approximation).
      final fillRadius = (radius - strokeWidth) * fraction;
      if (fillRadius > 0) {
        final fillBounds = Rect.fromCircle(
          center: bounds.center,
          radius: fillRadius,
        );
        nodes.add(
          ContainerNode(
            CapturedViewAttributes(
              paintBounds: fillBounds,
              scaleX: attributes.scaleX,
              scaleY: attributes.scaleY,
            ),
            wireframeId: fillKey,
            style: ContainerStyle(
              backgroundColor: indicatorColor.toHexString(),
              cornerRadius: fillRadius,
            ),
          ),
        );
      }
    }

    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      nodes: nodes,
    );
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Resolves an [Animation<Color?>] or plain [Color] from progress indicator
  /// colour properties (which may be wrapped in [AlwaysStoppedAnimation]).
  Color? _resolveColor(Animation<Color?>? animation) {
    return animation?.value;
  }
}
