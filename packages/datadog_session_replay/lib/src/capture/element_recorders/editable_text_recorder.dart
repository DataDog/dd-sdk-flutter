// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/material.dart';

import '../../../datadog_session_replay.dart';
import '../../extensions.dart';
import '../capture_node.dart';
import '../recorder.dart';
import '../text_masking.dart';
import '../view_tree_snapshot.dart';
import 'common_nodes.dart';
import 'recording_extensions.dart';

const _sensitiveInputTypes = [
  TextInputType.name,
  TextInputType.phone,
  TextInputType.emailAddress,
  TextInputType.streetAddress,
  TextInputType.visiblePassword,
];

/// [EditableTextRecorder] captures the actual editable portion of the
/// text, and handles obscuring the text that's captured.
class EditableTextRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  EditableTextRecorder(this.keyGenerator);

  @override
  bool accepts(Widget widget) => widget is EditableText;

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is! EditableText) {
      return null;
    }

    EditableTextState? state;
    if (element is StatefulElement && element.state is EditableTextState) {
      state = element.state as EditableTextState;
    }
    if (state == null) return null;

    var textValue = state.textEditingValue.text;
    var textStyle = widget.style;
    final key = keyGenerator.keyForElement(element);
    String? font;
    if (textStyle.fontFamily case final fontFamily?) {
      font = fontFamily;
      if (textStyle.fontFamilyFallback case final familyFallback?) {
        font = [font, ...familyFallback].join(',');
      }
    }

    if (_shouldObscureText(capturePrivacy, widget)) {
      textValue = maskTextFixedLength(textValue);
    }

    final node = TextElementCaptureNode(
      attributes,
      wireframeId: key,
      text: textValue,
      color: textStyle.color?.toHexString() ?? Colors.black.toHexString(),
      family: font ?? '',
      size: textStyle.fontSize?.safeRound() ?? 10,
      alignment: widget.textAlign.getSrHorizontalAlignment(
        widget.textDirection,
      ),
    );
    return SpecificElement(
      subtreeStrategy: CaptureNodeSubtreeStrategy.ignore,
      nodes: [node],
    );
  }

  bool _shouldObscureText(
    TreeCapturePrivacy capturePrivacy,
    EditableText widget,
  ) {
    switch (capturePrivacy.textAndInputPrivacyLevel) {
      case TextAndInputPrivacyLevel.maskSensitiveInputs:
        if (widget.obscureText ||
            _sensitiveInputTypes.contains(widget.keyboardType)) {
          return true;
        }
      case TextAndInputPrivacyLevel.maskAllInputs:
      case TextAndInputPrivacyLevel.maskAll:
        return true;
    }

    return false;
  }
}

/// [InputDecoratorRecorder] handles capturing the border around [TextField]
/// and [CupertinoTextField] widgets.
class InputDecoratorRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  InputDecoratorRecorder(this.keyGenerator);

  @override
  bool accepts(Widget widget) => widget is InputDecorator;

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is! InputDecorator) {
      return null;
    }

    final containerStyle = ContainerStyle.fromInputDecoration(
      widget.decoration,
      widget.isFocused,
      attributes,
    );

    return containerStyle != null
        ? SpecificElement(
            subtreeStrategy: CaptureNodeSubtreeStrategy.record,
            nodes: [
              ContainerNode(
                attributes,
                wireframeId: keyGenerator.keyForElement(element),
                style: containerStyle,
              ),
            ],
          )
        : null;
  }
}
