// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:flutter/material.dart';

import '../../../datadog_session_replay.dart';
import '../../extensions.dart';
import '../../sr_data_models.dart';
import '../capture_node.dart';
import '../view_tree_snapshot.dart';

class ContainerRecorder implements ElementRecorder {
  @override
  CaptureNodeSemantics? captureSemantics(
      Element element, CapturedViewAttributes attributes) {
    final widget = element.widget;

    Color? backgroundColor;
    double cornerRadius = 0.0;
    if (widget is Material) {
      backgroundColor = widget.color;
      if (widget.surfaceTintColor case final surfaceTintColor?) {
        if (surfaceTintColor.a > 0) {
          backgroundColor = widget.surfaceTintColor;
        }
      }
      final shape = widget.shape;
      switch (shape) {
        case final StadiumBorder _:
        case final CircleBorder _:
          // TODO: For circles, we may need to change the view attributes to have width
          // and height match,
          final shortSide = attributes.paintBounds.shortestSide;
          cornerRadius = shortSide / 2;
          break;
        case final RoundedRectangleBorder shape:
          // TODO: TextDirection
          cornerRadius = shape.borderRadius.resolve(null).topLeft.x;
          break;
      }
    } else if (widget is Container) {
      backgroundColor = widget.color;
    } else {
      return null;
    }

    final key =
        DatadogSessionReplay.instance?.keyGenerator.keyForElement(element) ?? 0;
    final node = CaptureNode(
      attributes,
      ContainerWireframeBuilder(
        wireframeId: key,
        backgroundColor: backgroundColor,
        cornerRadius: cornerRadius,
      ),
    );
    return AmbiguousElement(nodes: [node]);
  }
}

class ContainerWireframeBuilder implements WireframeBuilder {
  final int wireframeId;
  final Color? backgroundColor;
  final double cornerRadius;

  ContainerWireframeBuilder({
    required this.wireframeId,
    this.backgroundColor,
    this.cornerRadius = 0.0,
  });

  @override
  List<SRWireframe> buildWireframes(CaptureNode node) {
    final attrs = node.attributes;
    SRShapeStyle? style;
    if (backgroundColor != null) {
      style = SRShapeStyle(
          backgroundColor: backgroundColor!.toHexString(),
          cornerRadius: cornerRadius);
    }
    return [
      SRShapeWireframe(
        id: wireframeId,
        x: attrs.x,
        y: attrs.y,
        width: attrs.width,
        height: attrs.height,
        shapeStyle: style,
      ),
    ];
  }
}
