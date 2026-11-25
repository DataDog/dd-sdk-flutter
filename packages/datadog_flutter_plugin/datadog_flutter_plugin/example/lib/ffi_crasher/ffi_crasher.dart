// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'noop_ffi_crasher.dart' if (dart.library.io) 'mobile_ffi_crasher.dart';

typedef NativeCallback = int Function(int value);

abstract class FfiCrasher {
  void crash(int value);
  int crashCallback(int attribute, NativeCallback callback);

  factory FfiCrasher() {
    return createFfiCrasher();
  }
}
