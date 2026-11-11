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
  const FlagsEvaluationContext({this.targetingKey, this.attributes = const {}});

  /// Creates an evaluation context from a JSON map.
  factory FlagsEvaluationContext.fromJson(Map<String, Object?> json) =>
      _$FlagsEvaluationContextFromJson(json);

  /// Converts this context to a JSON map.
  Map<String, Object?> toJson() => _$FlagsEvaluationContextToJson(this);
}

// Local context controls are excluded from assignment and telemetry attributes.
extension ContextSwitchingPolicy on FlagsEvaluationContext {
  bool get strictContextSwitching =>
      identical(attributes['dd_strict_evaluation_context_switching'], true);

  FlagsEvaluationContext get targetingContext =>
      !attributes.containsKey('dd_strict_evaluation_context_switching')
      ? this
      : FlagsEvaluationContext(
          targetingKey: targetingKey,
          attributes: {
            for (final entry in attributes.entries)
              if (entry.key != 'dd_strict_evaluation_context_switching')
                entry.key: entry.value,
          },
        );
}

bool targetingContextsMatch(
  FlagsEvaluationContext left,
  FlagsEvaluationContext right,
) {
  if ((left.targetingKey ?? '') != (right.targetingKey ?? '')) {
    return false;
  }

  try {
    return _jsonValuesMatch(
      sanitizeJsonValue(left.targetingContext.attributes),
      sanitizeJsonValue(right.targetingContext.attributes),
    );
  } catch (_) {
    return false;
  }
}

bool _jsonValuesMatch(Object? left, Object? right) {
  if (left is Map<Object?, Object?> && right is Map<Object?, Object?>) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_jsonValuesMatch(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  if (left is Iterable<Object?> && right is Iterable<Object?>) {
    final leftIterator = left.iterator;
    final rightIterator = right.iterator;
    while (true) {
      final hasLeft = leftIterator.moveNext();
      final hasRight = rightIterator.moveNext();
      if (hasLeft != hasRight) {
        return false;
      }
      if (!hasLeft) {
        return true;
      }
      if (!_jsonValuesMatch(leftIterator.current, rightIterator.current)) {
        return false;
      }
    }
  }
  return left == right;
}
