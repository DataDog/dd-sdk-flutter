// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:flutter/widgets.dart';

import '../datadog_session_replay.dart';
import 'capture_node.dart';

abstract interface class ElementRecorder {
  CaptureNode? captureElement(
      Element element, CapturedViewAttributes attributes);
}

class SessionReplayCapture extends StatefulWidget {
  final Widget child;

  const SessionReplayCapture({super.key, required this.child});

  @override
  StatefulElement createElement() {
    final e = super.createElement();
    if (key != null) {
      DatadogSessionReplay.instance?.addElement(key!, e);
    }

    return e;
  }

  @override
  State<SessionReplayCapture> createState() => SessionReplayCaptureState();
}

class SessionReplayCaptureState extends State<SessionReplayCapture> {
  final repaintKey = GlobalKey();

  @override
  void dispose() {
    DatadogSessionReplay.instance?.removeElement(widget.key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintKey,
      child: widget.child,
    );
  }
}
