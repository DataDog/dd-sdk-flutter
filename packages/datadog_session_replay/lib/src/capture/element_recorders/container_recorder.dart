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
    if (widget is Material) {
      backgroundColor = widget.color;
      if (widget.surfaceTintColor case final surfaceTintColor?) {
        if (surfaceTintColor.a > 0) {
          backgroundColor = widget.surfaceTintColor;
        }
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
    final attrs = node.attributes;
    SRShapeStyle? style;
    if (backgroundColor != null) {
      style = SRShapeStyle(
        backgroundColor: backgroundColor!.toHexString(),
      );
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
