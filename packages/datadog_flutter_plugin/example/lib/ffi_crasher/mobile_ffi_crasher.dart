// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:ffi';
import 'dart:io';

import 'ffi_crasher.dart';

class MobileFfiCrasher implements FfiCrasher {
  @override
  void crash(int value) {
    ffi_crash_test(value);
  }

  @override
  int crashCallback(int attribute, NativeCallback callback) {
    return ffi_callback_test(attribute, Pointer.fromFunction(callback, 8));
  }
}

FfiCrasher createFfiCrasher() {
  return MobileFfiCrasher();
}

final DynamicLibrary ffiLibrary = Platform.isAndroid
    ? DynamicLibrary.open('libffi_crash_test.so')
    : DynamicLibrary.process();

// ignore: non_constant_identifier_names
final void Function(int attribute) ffi_crash_test = ffiLibrary
    .lookup<NativeFunction<Void Function(Int32)>>('ffi_crash_test')
    .asFunction();

typedef NativeFfiCallback = Int32 Function(Int32);

final int Function(
        int attribute, Pointer<NativeFunction<NativeFfiCallback>> callback)
    // ignore: non_constant_identifier_names
    ffi_callback_test = ffiLibrary
        .lookup<
                NativeFunction<
                    Int32 Function(
                        Int32, Pointer<NativeFunction<NativeFfiCallback>>)>>(
            'ffi_callback_test')
        .asFunction();
