// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:flutter/widgets.dart';

import '../datadog_session_replay.dart';
import 'capture_node.dart';

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
