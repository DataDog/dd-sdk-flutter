// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

Object? sanitizeJsonValue(Object? value) {
  if (value == null ||
      value is String ||
      value is bool ||
      value is int ||
      value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is Map<Object?, Object?>) {
    return value.map((key, value) {
      if (key is! String) {
        throw ArgumentError.value(
            key, 'key', 'JSON object keys must be String');
      }
      return MapEntry(key, sanitizeJsonValue(value));
    });
  }
  if (value is Iterable<Object?>) {
    return value.map(sanitizeJsonValue).toList();
  }
  throw ArgumentError.value(value, 'value', 'Unsupported JSON value');
}

Object? sortedJson(Object? value) {
  if (value is Map<String, Object?>) {
    final sortedKeys = value.keys.toList()..sort();
    return {
      for (final key in sortedKeys) key: sortedJson(value[key]),
    };
  }
  if (value is List<Object?>) {
    return value.map(sortedJson).toList();
  }
  return value;
}
