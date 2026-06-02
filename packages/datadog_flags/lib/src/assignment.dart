// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'json_value.dart';

enum FlagVariationType { boolean, string, integer, float, object, unknown }

class FlagAssignment {
  final String allocationKey;
  final String variationKey;
  final FlagVariationType variationType;
  final Object? variationValue;
  final String reason;
  final bool doLog;

  const FlagAssignment({
    required this.allocationKey,
    required this.variationKey,
    required this.variationType,
    required this.variationValue,
    required this.reason,
    required this.doLog,
  });

  factory FlagAssignment.fromJson(Map<String, Object?> json) {
    final typeName = json['variationType'] as String?;
    final value = json['variationValue'];
    final variationType = normalizeVariationType(typeName, value);

    return FlagAssignment(
      allocationKey: json['allocationKey'] as String,
      variationKey: json['variationKey'] as String,
      variationType: variationType,
      variationValue: _decodeVariationValue(variationType, value),
      reason: json['reason'] as String,
      doLog: json['doLog'] as bool,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'allocationKey': allocationKey,
      'variationKey': variationKey,
      'variationType': variationTypeToString(variationType),
      'variationValue': sanitizeJsonValue(variationValue),
      'reason': reason,
      'doLog': doLog,
    };
  }

  Object? typedValue(FlagVariationType requestedType) {
    if (variationType != requestedType) {
      return null;
    }

    return switch (requestedType) {
      FlagVariationType.boolean when variationValue is bool => variationValue,
      FlagVariationType.string when variationValue is String => variationValue,
      FlagVariationType.integer when variationValue is int => variationValue,
      FlagVariationType.float when variationValue is double => variationValue,
      FlagVariationType.object => variationValue,
      _ => null,
    };
  }

  static const defaultAssignment = FlagAssignment(
    allocationKey: '',
    variationKey: '',
    variationType: FlagVariationType.unknown,
    variationValue: null,
    reason: 'DEFAULT',
    doLog: false,
  );
}

FlagVariationType normalizeVariationType(String? typeName, Object? value) {
  if (typeName == 'number') {
    if (value is int) {
      return FlagVariationType.integer;
    }
    if (value is num) {
      return FlagVariationType.float;
    }
  }
  return variationTypeFromString(typeName);
}

FlagVariationType variationTypeFromString(String? value) {
  return switch (value) {
    'boolean' => FlagVariationType.boolean,
    'string' => FlagVariationType.string,
    'integer' => FlagVariationType.integer,
    'float' => FlagVariationType.float,
    'object' => FlagVariationType.object,
    _ => FlagVariationType.unknown,
  };
}

String variationTypeToString(FlagVariationType type) {
  return switch (type) {
    FlagVariationType.boolean => 'boolean',
    FlagVariationType.string => 'string',
    FlagVariationType.integer => 'integer',
    FlagVariationType.float => 'float',
    FlagVariationType.object => 'object',
    FlagVariationType.unknown => 'unknown',
  };
}

Object? _decodeVariationValue(FlagVariationType type, Object? value) {
  return switch (type) {
    FlagVariationType.integer when value is int => value,
    FlagVariationType.float when value is num => value.toDouble(),
    FlagVariationType.object => sanitizeJsonValue(value),
    _ => value,
  };
}
