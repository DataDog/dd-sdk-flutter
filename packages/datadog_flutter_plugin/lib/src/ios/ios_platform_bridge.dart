// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

import '../../datadog_internal.dart';

// We call the ObjC runtime directly rather than using package:objective_c to
// avoid adding that dependency to Core. The ObjC runtime functions
// (objc_getClass, sel_registerName, objc_msgSend) are stable C symbols in
// libobjc.A.dylib, which is always loaded into every iOS process. @Native
// resolves from DynamicLibrary.process() by default, so no explicit library
// handle is needed.

@ffi.Native<ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Char>)>(
    symbol: 'objc_getClass', isLeaf: true)
external ffi.Pointer<ffi.Void> _objcGetClass(ffi.Pointer<ffi.Char> name);

@ffi.Native<ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Char>)>(
    symbol: 'sel_registerName', isLeaf: true)
external ffi.Pointer<ffi.Void> _selRegisterName(ffi.Pointer<ffi.Char> name);

@ffi.Native<
    ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>,
        ffi.Pointer<ffi.Void>)>(symbol: 'objc_msgSend', isLeaf: true)
external ffi.Pointer<ffi.Void> _objcMsgSend(
    ffi.Pointer<ffi.Void> receiver, ffi.Pointer<ffi.Void> sel);

class IosPlatformBridge {
  static DatadogContext? getContext() {
    // A single arena frees all toNativeUtf8() allocations when the block exits.
    return using((arena) {
      final cls = _objcGetClass(
          'DatadogContextBridge'.toNativeUtf8(allocator: arena).cast());
      if (cls == ffi.nullptr) return null;

      final obj = _objcMsgSend(cls,
          _selRegisterName('current'.toNativeUtf8(allocator: arena).cast()));
      if (obj == ffi.nullptr) return null;

      final sessionId = _readNSString(obj, 'sessionId', arena);
      final accountId = _readNSString(obj, 'accountId', arena);
      final userId = _readNSString(obj, 'userId', arena);

      if (sessionId == null && accountId == null && userId == null) return null;
      return DatadogContext(
          sessionId: sessionId, userId: userId, accountId: accountId);
    });
  }

  static String? _readNSString(
      ffi.Pointer<ffi.Void> obj, String property, Arena arena) {
    final nsStr = _objcMsgSend(
        obj, _selRegisterName(property.toNativeUtf8(allocator: arena).cast()));
    if (nsStr == ffi.nullptr) return null;

    ffi.Pointer<ffi.Char> chars = _objcMsgSend(
            nsStr,
            _selRegisterName(
                'UTF8String'.toNativeUtf8(allocator: arena).cast()))
        .cast();
    if (chars == ffi.nullptr) return null;

    // toDartString() copies the bytes into Dart. The NSString (and the chars
    // pointer it owns) is kept alive by the autorelease pool for the duration
    // of this synchronous call — the pool won't drain until the current run
    // loop iteration completes. Do not free chars; it is not a separate
    // allocation.
    return chars.cast<Utf8>().toDartString();
  }
}
