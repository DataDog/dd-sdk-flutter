// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:async';
import 'dart:ffi' as ffi;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:objective_c/objective_c.dart';
import 'package:objective_c/objective_c.dart' as objc;

import '../../datadog_session_replay.dart';
import '../datadog_session_replay_platform_interface.dart';
import '../rum_context.dart';
import 'datadog_session_replay_bridge_ios.dart';

// Per-engine method channel used to pair this engine's bridge with its messenger
// (`registerEngine`). The FFI `enable()` call can't tell which engine invoked it, so
// this channel — which routes to the plugin instance for a specific engine — provides
// that engine's messenger natively. See DatadogSessionReplayPlugin.register(with:).
// Flutter issue: https://github.com/flutter/flutter/issues/184124
const _engineChannel = MethodChannel('datadog_session_replay/engine');

class DatadogSessionReplayPlatformIos extends DatadogSessionReplayPlatform {
  late FlutterSessionReplay _iosBridge;

  // Create the
  DatadogSessionReplayPlatformIos() {
    _iosBridge = FlutterSessionReplay();
  }

  DatadogSessionReplayPlatformIos.fromObjCRef(ObjCObject ref)
    : _iosBridge = FlutterSessionReplay.as(ref);

  @override
  Object? get isolateToken => _iosBridge;

  @override
  FutureOr<bool> enable(
    DatadogSessionReplayConfiguration configuration,
    void Function(RUMContext p1) onContextChanged,
  ) {
    NSURL? url;
    if (configuration.customEndpoint case final customEndpoint?) {
      url = NSURL.alloc().initWithString(NSString(customEndpoint));
      if (url == null) {
        final message =
            'Failed to parse custom endpoint $customEndpoint. Session replay was not initialized.';
        if (kDebugMode) {
          print('Datadog SR] ERROR: $message');
        }
        _iosBridge.postTelemetryDebugWithId(
          NSString('bad_custom_url'),
          message: NSString(message),
        );
      }
    }

    final contextChangedListener =
        ObjCBlock_ffiVoid_FlutterRUMCoreContext.listener((context) {
          RUMContext? dartContext;
          if (context != null) {
            dartContext = RUMContext(
              applicationId: context.applicationID.toDartString(),
              sessionId: context.sessionID.toDartString(),
              viewId: context.viewID?.toDartString(),
            );
            onContextChanged(dartContext);
          }
        });

    final iOsConfiguration = FlutterSessionReplayConfiguration.alloc()
      ..initWithCustomEndpoint(url, onContextChanged: contextChangedListener);
    _iosBridge.enableWith(iOsConfiguration);

    // Tell the bridge which path its segments take. Embedded records go to the native
    // recording, standalone records to the Flutter feature. The slotId is deliberately not
    // part of this: the bridge resolves it natively per segment, from the view the host
    // registered, so Dart never has to observe its own view to keep up.
    _iosBridge.setEmbedded(configuration.isEmbedded);

    // Hand this bridge's token to the plugin instance for this engine. The bridge is
    // created over FFI and never sees a messenger, while the plugin has the messenger but
    // never sees the bridge — this call is what pairs them, which is both how the engine's
    // Dart context callback gets released on detach and how the bridge reaches the messenger
    // it resolves slotIds through. Segments captured before it lands are buffered natively.
    unawaited(_engineChannel.invokeMethod<void>(
        'registerEngine', _iosBridge.engineToken.toDartString()));

    return true;
  }

  @override
  FutureOr<void> setHasReplay(String viewId, bool hasReplay) {
    _iosBridge.setHasReplayWithHasReplay(hasReplay);
  }

  @override
  FutureOr<void> setRecordCount(String viewId, int count) {
    _iosBridge.setRecordCountFor(NSString(viewId), count: count);
  }

  @override
  FutureOr<void> writeSegment(String record, String viewId) {
    _iosBridge.writeSegmentWithSegment(NSString(record));
  }

  @override
  FutureOr<void> telemetryDebug(String id, String message) {
    _iosBridge.postTelemetryDebugWithId(
      NSString(id),
      message: NSString(message),
    );
  }

  @override
  FutureOr<void> telemetryError(String message, String kind, String stack) {
    _iosBridge.postTelemetryErrorWithMessage(
      NSString(message),
      kind: NSString(kind),
      stackTrace: NSString(stack),
    );
  }

  @override
  FutureOr<void> saveImageForProcessing(
    int resourceKey,
    int width,
    int height,
    ByteData byteData,
  ) {
    NSData data = nsDataFromByteData(byteData);
    _iosBridge.saveImageForProcessingWithResourceKey(
      resourceKey,
      width: width,
      height: height,
      data: data,
    );
  }

  @override
  String? resourceIdForKey(int resourceKey) {
    return _iosBridge.resourceIdForKey(resourceKey)?.toDartString();
  }

  // Bypass `package:objective_c` here to allow a direct leaf call. This allows us
  // to copy the ByteData directly to NSData without an intermediary allocation,
  // and allows NSData to deal with owning the resulting memory.
  // ignore: non_constant_identifier_names
  late final _class_NSData = getClass('NSData');
  // ignore: non_constant_identifier_names
  late final _sel_dataWithBytes_length_ = registerName('dataWithBytes:length:');

  // This is not private because of this Dart issue:
  // https://github.com/dart-lang/sdk/issues/61321
  NSData nsDataFromByteData(ByteData byteData) {
    final ret = objc_msgSend_3nbx5e(
      _class_NSData,
      _sel_dataWithBytes_length_,
      byteData.buffer.asUint8List().address.cast(),
      byteData.lengthInBytes,
    );
    return NSData.fromPointer(ret, retain: true, release: true);
  }
}

@ffi.Native<
  ffi.Pointer<objc.ObjCObjectImpl> Function(
    ffi.Pointer<objc.ObjCObjectImpl>,
    ffi.Pointer<objc.ObjCSelector>,
    ffi.Pointer<ffi.Void>,
    ffi.UnsignedLong,
  )
>(symbol: 'objc_msgSend', isLeaf: true)
// ignore: non_constant_identifier_names
external ffi.Pointer<objc.ObjCObjectImpl> objc_msgSend_3nbx5e(
  ffi.Pointer<objc.ObjCObjectImpl> object,
  ffi.Pointer<objc.ObjCSelector> selector,
  ffi.Pointer<ffi.Void> a,
  int b,
);
