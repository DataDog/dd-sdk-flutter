// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Converts a [String] to a null-terminated C `char*` allocated with [allocator],
/// typed as [Pointer<Char>] to match what ffigen generates for `const char*` params.
extension StringToNativeChar on String {
  Pointer<Char> toNativeChar({required Allocator allocator}) =>
      toNativeUtf8(allocator: allocator).cast();
}

/// Same as [StringToNativeChar] for nullable strings — returns [nullptr] when null.
extension NullableStringToNativeChar on String? {
  Pointer<Char> toNativeChar({required Allocator allocator}) {
    final s = this;
    return s == null ? nullptr : s.toNativeUtf8(allocator: allocator).cast();
  }
}
