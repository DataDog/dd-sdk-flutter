// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:jni/jni.dart';

import '../../datadog_session_replay.dart';
import '../datadog_session_replay_platform_interface.dart';
import '../rum_context.dart';
import 'datadog_session_replay_bridge_android.dart';

// See comment in DatadogSessionReplayPlugin.onAttachedToEngine for why we use a
// method channel to claim engine ownership after the FFI enable() call.
// Flutter issue: https://github.com/flutter/flutter/issues/184124
const _engineChannel = MethodChannel('datadog_session_replay/engine');

class DatadogSessionReplayPlatformAndroid extends DatadogSessionReplayPlatform {
  late FlutterSessionReplayBridge _bridge;

  DatadogSessionReplayPlatformAndroid() {
    _bridge = FlutterSessionReplayBridge.INSTANCE;
  }

  DatadogSessionReplayPlatformAndroid.fromJObject(JObject ref)
    : _bridge = ref.as(FlutterSessionReplayBridge.type);

  @override
  Object? get isolateToken => _bridge;

  @override
  FutureOr<bool> enable(
    DatadogSessionReplayConfiguration configuration,
    void Function(RUMContext p1) onContextChanged,
  ) {
    final listener = FlutterSessionReplayBridge$ContextListener.implement(
      $FlutterSessionReplayBridge$ContextListener(
        onContextChanged: (context) {
          onContextChanged(
            RUMContext(
              applicationId: context.applicationId?.toDartString() ?? '',
              sessionId: context.sessionId?.toDartString() ?? '',
              viewId: context.viewId?.toDartString(),
              viewServerTimeOffset: context.viewServerTimeOffset?.doubleValue(),
            ),
          );
        },
        onContextChanged$async: false,
      ),
    );
    final mappedConfig = FlutterSessionReplayBridge$Configuration(
      configuration.customEndpoint?.toJString(),
      listener,
    );

    _bridge.enable(mappedConfig, null);
    // Non-awaited: routes through the method channel to the correct engine's plugin
    // instance, which calls claimOwnership() with that engine's BinaryMessenger.
    // ignore: unawaited_futures
    _engineChannel.invokeMethod<void>('claimOwnership');

    return true;
  }

  @override
  FutureOr<void> setHasReplay(String viewId, bool hasReplay) {
    _bridge.setHasReplay(viewId.toJString(), hasReplay);
  }

  @override
  FutureOr<void> setRecordCount(String viewId, int count) {
    _bridge.setRecordCount(viewId.toJString(), count);
  }

  @override
  FutureOr<void> telemetryDebug(String id, String message) {
    _bridge.telemetryDebug(message.toJString());
  }

  @override
  FutureOr<void> telemetryError(String message, String kind, String stack) {
    _bridge.telemetryError(
      message.toJString(),
      stack.toJString(),
      kind.toJString(),
    );
  }

  @override
  FutureOr<void> writeSegment(String record, String viewId) {
    _bridge.writeSegment(record.toJString());
  }

  @override
  String? resourceIdForKey(int resourceKey) {
    return _bridge.resourceIdForKey(resourceKey)?.toDartString();
  }

  @override
  FutureOr<void> saveImageForProcessing(
    int resourceKey,
    int width,
    int height,
    ByteData byteData,
  ) {
    final jbuffer = JByteBuffer.fromList(byteData.buffer.asUint8List());
    _bridge.saveImageForProcessing(resourceKey, jbuffer, width, height);
    jbuffer.release();
  }
}
