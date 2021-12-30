// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'dart:io';
import 'package:collection/collection.dart';

T getNestedProperty<T>(String key, Map<String, dynamic> from) {
  if (Platform.isIOS) {
    return from[key] as T;
  }

  var lookupMap = from;
  var parts = key.split('.');
  parts.forEachIndexedWhile((index, element) {
    lookupMap = lookupMap[element] as Map<String, dynamic>;
    // Continue until we're the second to last index
    return (index + 1) < (parts.length - 1);
  });

  return lookupMap[parts.last] as T;
}
