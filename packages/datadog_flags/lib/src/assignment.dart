// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'json_value.dart';
import 'numeric_value.dart';
import 'flag_key_obfuscation.dart';
import 'split_features.dart';

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
      FlagVariationType.integer
          when (value is num && value.isFinite) || value is NumericValue =>
        value,
      FlagVariationType.float
          when (value is num && value.isFinite) || value is NumericValue =>
        value,
      FlagVariationType.number
          when (value is num && value.isFinite) || value is NumericValue =>
        value,
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
  final FlagKeyObfuscation? obfuscation;

  const PrecomputedAssignments({
    required this.flags,
    this.createdAt,
    this.environment,
    this.obfuscation,
  });
}

@immutable
@JsonSerializable(constructor: '_', explicitToJson: true)
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
  @JsonKey(includeFromJson: false, includeToJson: false)
  final NumericValue? numericValue;
  final String reason;
  final bool doLog;
  final int? serialId;
  @JsonKey(fromJson: SplitFeature.listFromJson, includeToJson: false)
  final List<SplitFeature> features;

  // Stored assignments omit `features` when there are none.
  @JsonKey(name: 'features', includeIfNull: false, includeToJson: true)
  List<SplitFeature>? get _storedFeatures => features.isEmpty ? null : features;

  const FlagAssignment._({
    required this.allocationKey,
    required this.variationKey,
    required this.variationType,
    required this.variationValue,
    this.numericValue,
    required this.reason,
    required this.doLog,
    this.serialId,
    this.features = const [],
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
      variationValue: variationValue is NumericValue
          ? variationValue.integer ?? variationValue.floating ?? 0
          : variationValue,
      numericValue: variationValue is NumericValue ? variationValue : null,
      reason: assignment.reason,
      doLog: assignment.doLog,
      serialId: assignment.serialId,
      features: assignment.features,
    );
  }

  factory FlagAssignment.fromCacheJson(Map<String, Object?> json) {
    final value = json['variationValue'];
    if (const ['number', 'integer', 'float'].contains(json['variationType']) &&
        value is Map &&
        value['_numericLiteral'] is String) {
      json = {
        ...json,
        'variationValue': NumericValue(value['_numericLiteral'] as String),
      };
    }
    return FlagAssignment.fromJson(json);
  }

  Map<String, Object?> toJson() {
    final json = _$FlagAssignmentToJson(this);
    if (numericValue case final numeric?) {
      json['variationValue'] = {'_numericLiteral': numeric.literal};
    }
    return json;
  }
}
