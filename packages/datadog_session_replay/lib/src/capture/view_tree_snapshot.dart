// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:flutter/widgets.dart';

import '../datadog_session_replay.dart';
import 'capture_node.dart';

abstract interface class ElementRecorder {
  CaptureNodeSemantics? captureSemantics(
      Element element, CapturedViewAttributes attributes);
}

@immutable
class ViewTreeSnapshot {
  final DateTime date;
  final RUMContext context;
  final Size viewportSize;
  final List<CaptureNode> nodes;

  const ViewTreeSnapshot({
    required this.date,
    required this.context,
    required this.viewportSize,
    required this.nodes,
  });
}

enum CaptureNodeSubtreeStrategy { record, ignore }

@immutable
abstract class CaptureNodeSemantics {
  static const maxImporance = 1000000;
  static const minImportance = -1000000;

  final int importance;
  final CaptureNodeSubtreeStrategy subtreeStrategy;
  final List<CaptureNode> nodes;

  const CaptureNodeSemantics({
    required this.importance,
    required this.subtreeStrategy,
    required this.nodes,
  });
}

@immutable
class UnknownElement extends CaptureNodeSemantics {
  const UnknownElement()
      : super(
          importance: CaptureNodeSemantics.minImportance,
          subtreeStrategy: CaptureNodeSubtreeStrategy.record,
          nodes: const [],
        );
}

@immutable
class InvisibleElement extends CaptureNodeSemantics {
  const InvisibleElement({
    required super.subtreeStrategy,
  }) : super(
          importance: 0,
          nodes: const [],
        );
}

@immutable
class IgnoredElement extends CaptureNodeSemantics {
  const IgnoredElement({
    required super.subtreeStrategy,
    super.nodes = const [],
  }) : super(
          importance: CaptureNodeSemantics.maxImporance,
        );
}

@immutable
class AmbiguousElement extends CaptureNodeSemantics {
  const AmbiguousElement({
    super.subtreeStrategy = CaptureNodeSubtreeStrategy.record,
    required super.nodes,
  }) : super(
          importance: 0,
        );
}

@immutable
class SpecificElement extends CaptureNodeSemantics {
  const SpecificElement({
    required super.subtreeStrategy,
    required super.nodes,
  }) : super(
          importance: CaptureNodeSemantics.maxImporance,
        );
}
