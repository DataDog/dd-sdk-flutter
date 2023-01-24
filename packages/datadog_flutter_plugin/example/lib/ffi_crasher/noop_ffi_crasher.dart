// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'ffi_crasher.dart';

class NoopFfiCrasher implements FfiCrasher {
  @override
  int crashCallback(int attribute, NativeCallback callback) {
    return 0;
  }

  @override
  void crash(int value) {}
}

FfiCrasher createFfiCrasher() {
  return NoopFfiCrasher();
}
