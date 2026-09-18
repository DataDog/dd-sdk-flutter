// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/widgets.dart';

import '../../widgets.dart';
import '../capture_node.dart';
import '../recorder.dart';
import '../view_tree_snapshot.dart';

// The minimum width the label should be to display "Hidden"
const int _minLabelWidth = 100;

/// [PrivacyRecorder] capture and modifies the tree privacy settings
/// by reading the [SessionReplayPrivacy] widget. It also informs
/// the recorder when to ignore a subtree that is hidden.
class PrivacyRecorder implements ElementRecorder {
  final KeyGenerator keyGenerator;

  PrivacyRecorder(this.keyGenerator);

  @override
  bool accepts(Widget widget) => widget is SessionReplayPrivacy;

  @override
  CaptureNodeSemantics? captureSemantics(
    Element element,
    CapturedViewAttributes attributes,
    TreeCapturePrivacy capturePrivacy,
  ) {
    final widget = element.widget;
    if (widget is! SessionReplayPrivacy) {
      return null;
    }

    final key = keyGenerator.keyForElement(element);
    final nodes = <CaptureNode>[];
    var subtreeStrategy = CaptureNodeSubtreeStrategy.record;
    if (widget.hide == true) {
      subtreeStrategy = CaptureNodeSubtreeStrategy.ignore;
      nodes.add(
        PlaceholderNode(
          attributes,
          wireframeId: key,
          caption: 'Hidden',
          minWidth: _minLabelWidth,
        ),
      );
    }

    return SpecificElement(
      subtreeStrategy: subtreeStrategy,
      subtreePrivacy: TreeCapturePrivacy(
        textAndInputPrivacyLevel: widget.textAndInputPrivacyLevel ??
            capturePrivacy.textAndInputPrivacyLevel,
        imagePrivacyLevel:
            widget.imagePrivacyLevel ?? capturePrivacy.imagePrivacyLevel,
      ),
      nodes: nodes,
    );
  }
}
