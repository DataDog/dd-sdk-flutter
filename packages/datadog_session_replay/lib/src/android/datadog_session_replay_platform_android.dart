// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:jni/jni.dart';

import '../../datadog_session_replay.dart';
import '../datadog_session_replay_platform_interface.dart';
import '../rum_context.dart';
import 'datadog_session_replay_bridge_android.dart';

// Per-engine method channel used to pair this engine's bridge with its messenger
// (`registerEngine`). The FFI `enable()` call can't tell which engine invoked it, so
// this channel — which routes to the plugin instance for a specific engine — provides
// that engine's messenger natively. See DatadogSessionReplayPlugin.onAttachedToEngine.
// Flutter issue: https://github.com/flutter/flutter/issues/184124
const _engineChannel = MethodChannel('datadog_session_replay/engine');

class DatadogSessionReplayPlatformAndroid extends DatadogSessionReplayPlatform {
  late FlutterSessionReplayBridge _bridge;

  DatadogSessionReplayPlatformAndroid() {
    _bridge = FlutterSessionReplayBridge();
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
              applicationId: context.getApplicationId()?.toDartString() ?? '',
              sessionId: context.getSessionId()?.toDartString() ?? '',
              viewId: context.getViewId()?.toDartString(),
              viewServerTimeOffset:
                  context.getViewServerTimeOffset()?.doubleValue(),
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

    // Tell the bridge which path its segments take. Embedded records go to the native
    // recording, standalone records to the Flutter feature. The slotId is deliberately not
    // part of this: the bridge resolves it natively per segment, from the view the host
    // registered, so Dart never has to observe its own view to keep up.
    _bridge.setEmbedded(configuration.isEmbedded);

    // Hand this bridge's token to the plugin instance for this engine. The bridge is
    // created over JNI and never sees a messenger, while the plugin has the messenger but
    // never sees the bridge — this call is what pairs them, which is both how the engine's
    // Dart context callback gets released on detach and how the bridge reaches the messenger
    // it resolves slotIds through. Segments captured before it lands are buffered natively.
    // ignore: unawaited_futures
    _engineChannel.invokeMethod<void>(
        'registerEngine', _bridge.getEngineToken().toDartString());

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
    _bridge.telemetryDebug(JString.fromString(message));
  }

  @override
  FutureOr<void> telemetryError(String message, String kind, String stack) {
    _bridge.telemetryError(
      JString.fromString(message),
      JString.fromString(stack),
      JString.fromString(kind),
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
