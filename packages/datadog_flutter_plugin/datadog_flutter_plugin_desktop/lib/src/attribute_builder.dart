// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

import 'ffi_bindings.dart';
import 'native_char.dart';

ffi.Pointer<dd_attribute> buildAttrObject(
  Map<String, Object?> map,
  Arena arena,
  DdSdkFfi sdk,
) {
  if (map.isEmpty) return ffi.nullptr;

  final obj = arena<dd_attribute>();
  arena.using(obj, sdk.dd_attribute_free);
  sdk.dd_attribute_init_object(obj, map.length);

  for (final entry in map.entries) {
    final key = entry.key.toNativeChar(allocator: arena);
    final val = buildSingleAttr(entry.value, arena, sdk);
    sdk.dd_attribute_object_property_set(obj, key, val);
  }

  return obj;
}

ffi.Pointer<dd_attribute> buildSingleAttr(
  Object? value,
  Arena arena,
  DdSdkFfi sdk,
) {
  final attr = arena<dd_attribute>();
  arena.using(attr, sdk.dd_attribute_free);
  _fillAttr(attr, value, arena, sdk);
  return attr;
}

void _fillAttr(
  ffi.Pointer<dd_attribute> out,
  Object? value,
  Arena arena,
  DdSdkFfi sdk,
) {
  if (value == null) {
    // zero-init = DD_VALUE_TYPE_NULL — already correct, nothing to do
    return;
  }

  if (value is bool) {
    sdk.dd_attribute_set_bool(out, value);
  } else if (value is int) {
    sdk.dd_attribute_set_int(out, value);
  } else if (value is double) {
    sdk.dd_attribute_set_double(out, value);
  } else if (value is String) {
    sdk.dd_attribute_set_string(out, value.toNativeChar(allocator: arena));
  } else if (value is Map<String, Object?>) {
    sdk.dd_attribute_init_object(out, value.length);
    for (final entry in value.entries) {
      final key = entry.key.toNativeChar(allocator: arena);
      final val = buildSingleAttr(entry.value, arena, sdk);
      sdk.dd_attribute_object_property_set(out, key, val);
    }
  } else if (value is List) {
    sdk.dd_attribute_init_array(out, value.length);
    for (final item in value) {
      final el = buildSingleAttr(item, arena, sdk);
      sdk.dd_attribute_array_push(out, el);
    }
  } else {
    sdk.dd_attribute_set_string(
        out, value.toString().toNativeChar(allocator: arena));
  }
}
