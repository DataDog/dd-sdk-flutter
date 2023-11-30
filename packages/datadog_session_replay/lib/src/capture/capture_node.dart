// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:flutter/rendering.dart';

import '../sr_data_models.dart';

abstract class WireframeBuilder {
  List<SRWireframe> buildWireframes(CaptureNode node);
}

class CapturedViewAttributes {
  final Rect paintBounds;

  CapturedViewAttributes({required this.paintBounds});
}

class CaptureNode {
  final CapturedViewAttributes attributes;
  final WireframeBuilder wireframeBuilder;

  CaptureNode(this.attributes, this.wireframeBuilder);
}
