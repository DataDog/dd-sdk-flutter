// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:collection/collection.dart';
import 'package:js/js_util.dart' as jsutil;

dynamic attributesToJs(Map<String, Object?> attributes, String parameterName) {
  return valueToJs(attributes, parameterName);
}

dynamic valueToJs(Object? value, String parameterName) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }

  if (value is Map) {
    final jsMap = jsutil.newObject();
    for (final item in value.entries) {
      jsutil.setProperty(
          jsMap, item.key, valueToJs(item.value, '$parameterName.${item.key}'));
    }
    return jsMap;
  }

  if (value is List) {
    final jsList =
        value.mapIndexed((e, i) => valueToJs(e, '$parameterName[i]')).toList();
    return jsList;
  }

  throw ArgumentError(
      'Could not convert ${value.runtimeType} to javascript.', parameterName);
}
