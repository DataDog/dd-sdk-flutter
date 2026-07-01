// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'json_value.dart';

part 'evaluation_context.g.dart';

/// Subject and attributes used to evaluate feature flags.
@immutable
@JsonSerializable()
final class FlagsEvaluationContext {
  /// Empty context used when an application has no targeting data yet.
  static const empty = FlagsEvaluationContext();

  /// Primary subject key, such as a user id, device id, or organization id.
  @JsonKey(includeIfNull: false)
  final String? targetingKey;

  /// JSON-compatible targeting attributes sent with assignment requests.
  @JsonKey(toJson: sanitizeJsonValue)
  final Map<String, Object?> attributes;

  /// Creates an evaluation context for assignment requests.
  const FlagsEvaluationContext({
    this.targetingKey,
    this.attributes = const {},
  });

  /// Creates an evaluation context from a JSON map.
  factory FlagsEvaluationContext.fromJson(Map<String, Object?> json) =>
      _$FlagsEvaluationContextFromJson(json);

  /// Converts this context to a JSON map.
  Map<String, Object?> toJson() => _$FlagsEvaluationContextToJson(this);
}
