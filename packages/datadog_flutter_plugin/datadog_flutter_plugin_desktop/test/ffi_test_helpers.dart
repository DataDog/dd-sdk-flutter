// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

/// Reads a C string argument of a mocked native call, or null for a null
/// pointer. Must be called while the call is in flight, before the plugin
/// frees the string.
String? nativeString(Object? pointer) {
  final ptr = pointer as ffi.Pointer<ffi.Char>;
  return ptr.address == 0 ? null : ptr.cast<Utf8>().toDartString();
}
