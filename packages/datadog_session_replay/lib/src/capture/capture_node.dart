// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/widgets.dart';

import '../extensions.dart';
import '../sr_data_models.dart';

@immutable
class CapturedViewAttributes {
  final Rect paintBounds;
  final double scaleX;
  final double scaleY;

  int get x => paintBounds.left.safeRound();
  int get y => paintBounds.top.safeRound();
  int get width => paintBounds.width.safeRound();
  int get height => paintBounds.height.safeRound();

  const CapturedViewAttributes({
    required this.paintBounds,
    required this.scaleX,
    required this.scaleY,
  });
}

@immutable
abstract class CaptureNode {
  final CapturedViewAttributes attributes;

  const CaptureNode(this.attributes);

  List<SRWireframe> buildWireframes();
}

/// Common Attribute Nodes

@immutable
class PlaceholderNode extends CaptureNode {
  final int wireframeId;

  /// The text to display if the width of the element is above [minWidth].
  final String caption;

  /// The minimum width the node needs to be to display the provided [caption].
  final int minWidth;

  const PlaceholderNode(
    super.attributes, {
    required this.wireframeId,
    required this.caption,
    required this.minWidth,
  }) : super();

  @override
  List<SRWireframe> buildWireframes() {
    final label = attributes.width < minWidth ? null : caption;
    return [
      SRPlaceholderWireframe(
        id: wireframeId,
        x: attributes.x,
        y: attributes.y,
        width: attributes.width,
        height: attributes.height,
        label: label,
      ),
    ];
  }
}
