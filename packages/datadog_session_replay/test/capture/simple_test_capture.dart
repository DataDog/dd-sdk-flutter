// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:flutter/widgets.dart';

/// A simplified implementation of [SessionReplayCapture] used for testing.
///
/// Note: to properly test recorders, we need to supply a full widget tree, as
/// [Element] is too difficult to mock effectively.
class SimpleTestCapture extends StatefulWidget {
  final SessionReplayRecorder recorder;
  final Widget? child;

  const SimpleTestCapture({super.key, required this.recorder, this.child});

  @override
  StatefulElement createElement() {
    final e = super.createElement();
    if (key != null) {
      recorder.addElement(key!, e);
    }

    return e;
  }

  @override
  State<SimpleTestCapture> createState() => _SimpleTestCaptureState();
}

class _SimpleTestCaptureState extends State<SimpleTestCapture> {
  @override
  Widget build(BuildContext context) {
    return widget.child ?? Placeholder();
  }
}
