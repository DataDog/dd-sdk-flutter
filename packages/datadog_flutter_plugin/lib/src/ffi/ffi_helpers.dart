// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'dd_sdk_cpp.dart';

Pointer<dd_attribute> attributesToFfiAttribute(Map<String, Object?> attributes,
    dd_sdk_cpp dd, Allocator allocator, String parameterName) {
  return valueToFfiAttribute(attributes, dd, allocator, parameterName);
}

Pointer<dd_attribute> valueToFfiAttribute(
    Object? value, dd_sdk_cpp dd, Allocator allocator, String parameterName) {
  final cAttribute = allocator<dd_attribute>();
  if (value == null) {
    cAttribute.ref = dd.dd_attribute_null();
    return cAttribute;
  }

  if (value is int) {
    cAttribute.ref = dd.dd_attribute_int(value);
    return cAttribute;
  }

  if (value is double) {
    cAttribute.ref = dd.dd_attribute_double(value);
    return cAttribute;
  }

  if (value is bool) {
    cAttribute.ref = dd.dd_attribute_bool(value);
    return cAttribute;
  }

  if (value is String) {
    final cValue = value.toNativeUtf8(allocator: allocator);
    cAttribute.ref = dd.dd_attribute_string(cValue.cast());
    return cAttribute;
  }

  if (value is Map) {
    cAttribute.ref = dd.dd_attribute_object(value.length);
    for (final item in value.entries) {
      String key = item.key is String ? item.key : item.key.toString();
      final cKey = key.toNativeUtf8(allocator: allocator);
      dd.dd_attribute_object_property_set(
        cAttribute,
        cKey.cast(),
        valueToFfiAttribute(item, dd, allocator, '$parameterName.${item.key}'),
      );
    }
    return cAttribute;
  }

  if (value is List) {
    cAttribute.ref = dd.dd_attribute_array(value.length);
    for (int i = 0; i < value.length; ++i) {
      dd.dd_attribute_array_push(
        cAttribute,
        valueToFfiAttribute(value[i], dd, allocator, '$parameterName[$i]'),
      );
    }
    return cAttribute;
  }

  throw ArgumentError(
    'Could not convert ${value.runtimeType} to FFI attribute.',
    parameterName,
  );
}
