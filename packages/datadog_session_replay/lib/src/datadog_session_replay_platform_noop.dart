// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:async';
import 'dart:typed_data';

import '../datadog_session_replay.dart';
import 'datadog_session_replay_platform_interface.dart';
import 'rum_context.dart';

/// A NoOp implementation of the Session Replay platform interface. This is the
/// default interface as native platform work is now performed by the FFI
/// plugins: [DatadogSessionReplayPlatformIos] and
/// [DatadogSessionReplayPlatformAndroid]
class DatadogSessionReplayPlatformNoop extends DatadogSessionReplayPlatform {
  @override
  FutureOr<bool> enable(
    DatadogSessionReplayConfiguration configuration,
    void Function(RUMContext p1) onContextChanged,
  ) {
    return false;
  }

  @override
  Object? get isolateToken => null;

  @override
  FutureOr<void> setHasReplay(String viewId, bool hasReplay) {}

  @override
  FutureOr<void> setRecordCount(String viewId, int count) {}

  @override
  FutureOr<void> telemetryDebug(String id, String message) {}

  @override
  FutureOr<void> telemetryError(String message, String kind, String stack) {}

  @override
  FutureOr<void> writeSegment(String record, String viewId) {}

  @override
  String? resourceIdForKey(int resourceKey) {
    return null;
  }

  @override
  FutureOr<void> saveImageForProcessing(
    int resourceKey,
    int width,
    int height,
    ByteData byteData,
  ) {}
}
