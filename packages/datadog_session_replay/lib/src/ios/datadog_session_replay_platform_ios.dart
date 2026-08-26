// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:async';
import 'dart:ffi' as ffi;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:objective_c/objective_c.dart';

import '../../datadog_session_replay.dart';
import '../datadog_session_replay_platform_interface.dart';
import '../rum_context.dart';
import 'datadog_session_replay_bridge_ios.dart';

// See comment in DatadogSessionReplayPlugin.register(with:) for why we use a
// method channel to claim engine ownership after the FFI enable() call.
// Flutter issue: https://github.com/flutter/flutter/issues/184124
const _engineChannel = MethodChannel('datadog_session_replay/engine');

class DatadogSessionReplayPlatformIos extends DatadogSessionReplayPlatform {
  late FlutterSessionReplay _iosBridge;

  // Create the
  DatadogSessionReplayPlatformIos() {
    _iosBridge = FlutterSessionReplay();
  }

  DatadogSessionReplayPlatformIos.fromObjCRef(ObjCObjectBase ref)
      : _iosBridge = FlutterSessionReplay.castFrom(ref);

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
      ..initWithCustomEndpoint(
        url,
        onContextChanged: contextChangedListener,
      );
    _iosBridge.enableWith(iOsConfiguration);
    // Non-awaited: routes through the method channel to the correct engine's plugin
    // instance, which calls claimOwnership(messenger:) with that engine's messenger.
    // ignore: unawaited_futures
    _engineChannel.invokeMethod<void>('claimOwnership');

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
    return NSData.castFromPointer(ret, retain: true, release: true);
  }
}

@ffi.Native<
    ffi.Pointer<ObjCObject> Function(
      ffi.Pointer<ObjCObject>,
      ffi.Pointer<ObjCSelector>,
      ffi.Pointer<ffi.Void>,
      ffi.UnsignedLong,
    )>(symbol: 'objc_msgSend', isLeaf: true)
// ignore: non_constant_identifier_names
external ffi.Pointer<ObjCObject> objc_msgSend_3nbx5e(
  ffi.Pointer<ObjCObject> object,
  ffi.Pointer<ObjCSelector> selector,
  ffi.Pointer<ffi.Void> a,
  int b,
);
