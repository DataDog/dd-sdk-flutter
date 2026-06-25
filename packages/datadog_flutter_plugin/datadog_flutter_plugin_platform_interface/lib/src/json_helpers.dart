// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'package:json_annotation/json_annotation.dart';

const commonJsonOptions = JsonSerializable(
  fieldRename: FieldRename.snake,
  anyMap: true,
  includeIfNull: false,
  explicitToJson: true,
);

Map<String, Object?> attributesFromJson(Map<dynamic, dynamic>? attributes) {
  return attributes?.map(
          (Object? key, Object? value) => MapEntry(key as String, value)) ??
      {};
}

List<String> actionListFromJson(Object? value) {
  if (value == null) {
    return [];
  }
  if (value is String) {
    return [value];
  }
  if (value is List) {
    return value.map((dynamic e) => value.toString()).toList();
  }

  return [];
}
