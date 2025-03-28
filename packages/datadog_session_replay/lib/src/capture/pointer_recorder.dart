// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../sr_data_models.dart';

@immutable
class PointerSnapshot {
  final DateTime firstRecord;
  final List<PointerCapture> pointerEvents;

  const PointerSnapshot(this.firstRecord, this.pointerEvents);
}

@immutable
class PointerCapture {
  final DateTime date;
  final int pointerId;
  final SRPointerEventType eventType;
  final double x;
  final double y;

  const PointerCapture({
    required this.date,
    required this.pointerId,
    required this.eventType,
    required this.x,
    required this.y,
  });
}

class PointerSnapshotRecorder {
  final DatadogTimeProvider timeProvider;

  List<PointerCapture> _pointerBuffer = [];

  PointerSnapshotRecorder(this.timeProvider);

  void capturePointer(
      int pointerId, SRPointerEventType eventType, double x, double y) {
    final now = timeProvider.now();

    _pointerBuffer.add(PointerCapture(
        date: now, pointerId: pointerId, eventType: eventType, x: x, y: y));
  }

  PointerSnapshot? takeSnapshot() {
    if (_pointerBuffer.isEmpty) {
      return null;
    }

    final copy = _pointerBuffer;
    _pointerBuffer = [];
    return PointerSnapshot(copy.first.date, copy);
  }
}

@immutable
class PointerRecorderWidget extends StatelessWidget {
  final PointerSnapshotRecorder snapshotRecorder;
  final Widget child;

  const PointerRecorderWidget({
    super.key,
    required this.snapshotRecorder,
    required this.child,
  });

  void _onPointerDown(PointerDownEvent event) =>
      _capturePointerEvent(SRPointerEventType.down, event);

  void _onPointerMove(PointerMoveEvent event) =>
      _capturePointerEvent(SRPointerEventType.move, event);

  void _onPointerCancel(PointerCancelEvent event) =>
      _capturePointerEvent(SRPointerEventType.up, event);

  void _onPointerHover(PointerHoverEvent event) =>
      _capturePointerEvent(SRPointerEventType.move, event);

  void _onPointerUp(PointerUpEvent event) =>
      _capturePointerEvent(SRPointerEventType.up, event);

  void _capturePointerEvent(SRPointerEventType type, PointerEvent event) {
    snapshotRecorder.capturePointer(
      event.pointer,
      type,
      event.position.dx,
      event.position.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerCancel: _onPointerCancel,
      onPointerHover: _onPointerHover,
      onPointerUp: _onPointerUp,
      child: child,
    );
  }
}
