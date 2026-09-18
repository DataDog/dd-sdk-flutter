// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_internal.dart';
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

/// Provides a PointerSnapshotRecorder to other classes that need it.
/// This is used primarily by [SessionReplayPrivacy] to cancel pointer
/// tracking that occurs in its subtree if [TouchPrivacyLevel] is set
class PointerSnapshotRecorderProvider extends InheritedWidget {
  final PointerSnapshotRecorder recorder;

  const PointerSnapshotRecorderProvider({
    super.key,
    required super.child,
    required this.recorder,
  }) : super();

  @override
  bool updateShouldNotify(
    covariant PointerSnapshotRecorderProvider oldWidget,
  ) =>
      recorder != oldWidget.recorder;

  static PointerSnapshotRecorderProvider? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PointerSnapshotRecorderProvider>();
  }
}

class PointerSnapshotRecorder {
  final DatadogTimeProvider timeProvider;
  final bool Function() _isCapturing;

  List<PointerCapture> _pointerBuffer = [];
  final Set<int> _hiddenPointers = {};

  PointerSnapshotRecorder(
    this.timeProvider, {
    bool Function() isCapturing = _alwaysCapturing,
  }) : _isCapturing = isCapturing;

  static bool _alwaysCapturing() => true;

  void capturePointer(
    int pointerId,
    SRPointerEventType eventType,
    double x,
    double y,
  ) {
    if (!_isCapturing()) return;

    final now = timeProvider.now();

    if (_hiddenPointers.contains(pointerId)) {
      return;
    }

    _pointerBuffer.add(
      PointerCapture(
        date: now,
        pointerId: pointerId,
        eventType: eventType,
        x: x,
        y: y,
      ),
    );
  }

  // Uncapturing a pointer removes any previous events from the pointer, and
  // flags it as hidden until the next snapshot. This is partially to support
  // 'hover' events that don't have up / down that are trackable, and because
  // "up" triggers occur in reverse tree order, which means we can't 'uncapture'
  // the tracking that happens at the root of the tree.
  //
  // This may result in some touches being ignored if they alternate between a
  // hidden area and a non-hidden area in between tree captures, but we'd rather
  // miss a few pointer events than capture private ones.
  void uncapturePointer(int pointerId) {
    _hiddenPointers.add(pointerId);
    _pointerBuffer.removeWhere((c) => c.pointerId == pointerId);
  }

  PointerSnapshot? takeSnapshot() {
    if (_pointerBuffer.isEmpty) {
      return null;
    }

    final copy = _pointerBuffer;
    _pointerBuffer = [];
    _hiddenPointers.clear();
    return PointerSnapshot(copy.first.date, copy);
  }
}
