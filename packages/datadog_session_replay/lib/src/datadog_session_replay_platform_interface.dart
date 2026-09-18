// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../datadog_session_replay.dart';
import 'datadog_session_replay_platform_noop.dart';
import 'rum_context.dart';

abstract class DatadogSessionReplayPlatform extends PlatformInterface {
  /// Constructs a DatadogSessionReplayPlatform.
  DatadogSessionReplayPlatform() : super(token: _token);

  static final Object _token = Object();

  static DatadogSessionReplayPlatform _instance =
      DatadogSessionReplayPlatformNoop();

  /// The default instance of [DatadogSessionReplayPlatform] to use.
  ///
  /// Defaults to [MethodChannelDatadogSessionReplay].
  static DatadogSessionReplayPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DatadogSessionReplayPlatform] when
  /// they register themselves.
  static set instance(DatadogSessionReplayPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Object? get isolateToken;

  FutureOr<bool> enable(
    DatadogSessionReplayConfiguration configuration,
    void Function(RUMContext) onContextChanged,
  );

  FutureOr<void> setHasReplay(String viewId, bool hasReplay);

  FutureOr<void> setRecordCount(String viewId, int count);

  FutureOr<void> writeSegment(String record, String viewId);

  FutureOr<void> telemetryDebug(String id, String message);

  FutureOr<void> telemetryError(String message, String kind, String stack);

  FutureOr<void> saveImageForProcessing(
    int resourceKey,
    int width,
    int height,
    ByteData byteData,
  );

  String? resourceIdForKey(int resourceKey);
}
