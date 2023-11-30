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

    final Color? backgroundColor;
    if (widget is Material) {
      backgroundColor = widget.color;
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
      ),
    );
    return AmbiguousElement(nodes: [node]);
  }
}

class ContainerWireframeBuilder implements WireframeBuilder {
  final int wireframeId;
  final Color? backgroundColor;

  ContainerWireframeBuilder({
    required this.wireframeId,
    this.backgroundColor,
  });

  @override
  List<SRWireframe> buildWireframes(CaptureNode node) {
    final bounds = node.attributes.paintBounds;
    SRShapeStyle? style;
    if (backgroundColor != null) {
      style = SRShapeStyle(
        backgroundColor: backgroundColor!.toHexString(),
      );
    }
    return [
      SRShapeWireframe(
        id: wireframeId,
        x: bounds.left.toInt(),
        y: bounds.top.toInt(),
        width: bounds.width.toInt(),
        height: bounds.height.toInt(),
        shapeStyle: style,
      ),
    ];
  }
}
