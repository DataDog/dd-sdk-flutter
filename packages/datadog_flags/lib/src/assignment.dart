// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'json_value.dart';

part 'assignment.g.dart';

enum FlagVariationType {
  boolean('boolean'),
  string('string'),
  integer('integer'),
  float('float'),
  number('number'),
  object('object');

  final String wireName;

  const FlagVariationType(this.wireName);

  factory FlagVariationType.fromWireName(String name) {
    for (final type in values) {
      if (type.wireName == name) {
        return type;
      }
    }
    throw FormatException('Unsupported flag variation type: $name');
  }

  Object decodeVariationValue(Object value) {
    return switch (this) {
      FlagVariationType.boolean when value is bool => value,
      FlagVariationType.string when value is String => value,
      FlagVariationType.integer when value is int => value,
      FlagVariationType.float when value is num => value.toDouble(),
      FlagVariationType.number when value is num => value,
      FlagVariationType.object => sanitizeJsonValue(value)!,
      _ => throw FormatException('Invalid variation value for $wireName'),
    };
  }

  static String toWireName(FlagVariationType type) => type.wireName;
}

@immutable
final class PrecomputedAssignments {
  final Map<String, FlagAssignment> flags;
  final DateTime? createdAt;
  final String? environment;

  const PrecomputedAssignments({
    required this.flags,
    this.createdAt,
    this.environment,
  });
}

@immutable
@JsonSerializable(constructor: '_')
final class FlagAssignment {
  final String allocationKey;
  final String variationKey;
  @JsonKey(
    fromJson: FlagVariationType.fromWireName,
    toJson: FlagVariationType.toWireName,
  )
  final FlagVariationType variationType;
  @JsonKey(toJson: sanitizeJsonValue)
  final Object variationValue;
  final String reason;
  final bool doLog;

  const FlagAssignment._({
    required this.allocationKey,
    required this.variationKey,
    required this.variationType,
    required this.variationValue,
    required this.reason,
    required this.doLog,
  });

  factory FlagAssignment.fromJson(Map<String, Object?> json) {
    final assignment = _$FlagAssignmentFromJson(json);
    final variationValue = assignment.variationType.decodeVariationValue(
      assignment.variationValue,
    );

    return FlagAssignment._(
      allocationKey: assignment.allocationKey,
      variationKey: assignment.variationKey,
      variationType: assignment.variationType,
      variationValue: variationValue,
      reason: assignment.reason,
      doLog: assignment.doLog,
    );
  }

  Map<String, Object?> toJson() => _$FlagAssignmentToJson(this);
}
