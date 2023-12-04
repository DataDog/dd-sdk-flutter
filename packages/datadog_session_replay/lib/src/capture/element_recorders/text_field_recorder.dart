// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:flutter/material.dart';

import '../../../datadog_session_replay.dart';
import '../../extensions.dart';
import '../../sr_data_models.dart';
import '../capture_node.dart';
import '../view_tree_snapshot.dart';

class TextFieldRecorder implements ElementRecorder {
  @override
  CaptureNodeSemantics? captureSemantics(
      Element element, CapturedViewAttributes attributes) {
    final widget = element.widget;
    if (widget is! EditableText) return null;

    EditableTextState? state;
    if (element is StatefulElement && element.state is EditableTextState) {
      state = element.state as EditableTextState;
    }
    if (state == null) return null;

    var textValue = state.textEditingValue.text;
    var textStyle = widget.style;
    final key =
        DatadogSessionReplay.instance?.keyGenerator.keyForElement(element) ?? 0;
    final builder = TextFieldWireframeBuilder(
      wireframeId: key,
      text: textValue,
      color: textStyle.color?.toHexString() ?? '#FF0000FF',
      family: textStyle.fontFamily ?? '',
      size: textStyle.fontSize?.toInt() ?? 10,
    );
    final node = CaptureNode(attributes, builder);
    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      nodes: [node],
    );
  }
}

@immutable
class TextFieldWireframeBuilder implements WireframeBuilder {
  final int wireframeId;
  final String text;
  final String color;
  final String family;
  final int size;

  const TextFieldWireframeBuilder({
    required this.wireframeId,
    required this.text,
    required this.color,
    required this.family,
    required this.size,
  });

  @override
  List<SRWireframe> buildWireframes(CaptureNode node) {
    return [
      SRTextWireframe(
        id: wireframeId,
        x: node.attributes.paintBounds.left.toInt(),
        y: node.attributes.paintBounds.top.toInt(),
        width: node.attributes.paintBounds.width.toInt(),
        height: node.attributes.paintBounds.height.toInt(),
        text: text,
        textStyle: SRTextStyle(
          color: color,
          family: family,
          size: size,
        ),
      ),
    ];
  }
}
