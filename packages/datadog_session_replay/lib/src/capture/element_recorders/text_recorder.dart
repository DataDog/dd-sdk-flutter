// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:flutter/widgets.dart';

import '../../sr_data_models.dart';
import '../capture_node.dart';
import '../session_replay_capture.dart';

extension HexColor on Color {
  String toHexString() {
    return '#${red.toRadixString(16).padLeft(2, '0')}'
        '${green.toRadixString(16).padLeft(2, '0')}'
        '${blue.toRadixString(16).padLeft(2, '0')}'
        '${alpha.toRadixString(16).padLeft(2, '0')}';
  }
}

class TextElementRecorder implements ElementRecorder {
  @override
  CaptureNode? captureElement(
      Element element, CapturedViewAttributes attributes) {
    final widget = element.widget;
    if (widget is! RichText) {
      return null;
    }

    final textSpan = widget.text;
    // TODO: Support other inline spans / child spans
    if (textSpan is TextSpan) {
      final style = textSpan.style;
      final builder = TextElementWireframeBuilder(
        text: textSpan.text ?? '',
        color: style?.color?.toHexString() ?? '#FF0000FF',
        family: style?.fontFamily ?? '',
        size: style?.fontSize?.toInt() ?? 10,
      );

      return CaptureNode(attributes, builder);
    }
    return null;
  }
}

@immutable
class TextElementWireframeBuilder implements WireframeBuilder {
  final String text;
  final String color;
  final String family;
  final int size;

  const TextElementWireframeBuilder({
    required this.text,
    required this.color,
    required this.family,
    required this.size,
  });

  @override
  List<SRWireframe> buildWireframes(CaptureNode node) {
    return [
      SRTextWireframe(
        id: 111,
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
