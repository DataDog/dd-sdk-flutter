// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:flutter/material.dart';

import '../../../datadog_session_replay.dart';
import '../../sr_data_models.dart';
import '../capture_node.dart';
import '../view_tree_snapshot.dart';

class ImageElementRecorder implements ElementRecorder {
  @override
  CaptureNodeSemantics? captureSemantics(
      Element element, CapturedViewAttributes attributes) {
    final widget = element.widget;
    if (widget is! Image) return null;

    final key =
        DatadogSessionReplay.instance?.keyGenerator.keyForElement(element) ?? 0;
    final node = CaptureNode(
      attributes,
      PlaceholderWireframeBuilder(
        wireframeId: key,
      ),
    );
    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.record,
      nodes: [node],
    );
  }
}

class PlaceholderWireframeBuilder implements WireframeBuilder {
  final int wireframeId;
  final Color? backgroundColor;

  PlaceholderWireframeBuilder({
    required this.wireframeId,
    this.backgroundColor,
  });

  @override
  List<SRWireframe> buildWireframes(CaptureNode node) {
    final bounds = node.attributes.paintBounds;

    return [
      SRPlaceholderWireframe(
        id: wireframeId,
        x: bounds.left.toInt(),
        y: bounds.top.toInt(),
        width: bounds.width.toInt(),
        height: bounds.height.toInt(),
        label: 'Content Image',
      ),
    ];
  }
}
