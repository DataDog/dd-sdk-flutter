// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/widgets.dart';

import '../rum_context.dart';
import 'capture_node.dart';
import 'recorder.dart';

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
  final CaptureNodeSubtreeStrategy subtreeStrategy;
  final TreeCapturePrivacy? subtreePrivacy;
  final List<CaptureNode> nodes;

  const CaptureNodeSemantics({
    required this.subtreeStrategy,
    this.subtreePrivacy,
    required this.nodes,
  });
}

@immutable
class UnknownElement extends CaptureNodeSemantics {
  const UnknownElement({super.subtreePrivacy})
      : super(
          subtreeStrategy: CaptureNodeSubtreeStrategy.record,
          nodes: const [],
        );
}

@immutable
class InvisibleElement extends CaptureNodeSemantics {
  const InvisibleElement({required super.subtreeStrategy, super.subtreePrivacy})
      : super(nodes: const []);
}

@immutable
class IgnoredElement extends CaptureNodeSemantics {
  const IgnoredElement({
    required super.subtreeStrategy,
    super.subtreePrivacy,
    super.nodes = const [],
  }) : super();
}

@immutable
class AmbiguousElement extends CaptureNodeSemantics {
  const AmbiguousElement({
    super.subtreeStrategy = CaptureNodeSubtreeStrategy.record,
    super.subtreePrivacy,
    required super.nodes,
  }) : super();
}

@immutable
class SpecificElement extends CaptureNodeSemantics {
  const SpecificElement({
    required super.subtreeStrategy,
    super.subtreePrivacy,
    required super.nodes,
  }) : super();
}

/// This node needs additional async processing in order to provide
/// a CaptureNode.
@immutable
class AdditionalProcessingElement extends CaptureNodeSemantics {
  final Future<CaptureNodeSemantics> Function() process;

  const AdditionalProcessingElement({
    required super.subtreeStrategy,
    super.subtreePrivacy,
    required this.process,
  }) : super(nodes: const []);
}
