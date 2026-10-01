// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';

import 'package:meta/meta.dart';

import 'flags_client.dart';

/// Observes the first accepted installation for a client instance.
///
/// The client is usable during this callback. Errors, including errors from a
/// returned Future, are isolated from initialization and flag evaluation.
typedef OnFirstFlags = FutureOr<void> Function(
  DatadogFlagsClient client,
  FlagsClientEvent event,
);

/// Event vocabulary shared with OpenFeature; this API only emits
/// [configurationChanged] through [OnFirstFlags].
enum FlagsClientEventType {
  configurationChanged('CONFIGURATION_CHANGED'),
  ready('READY'),
  error('ERROR'),
  stale('STALE'),
  reconciling('RECONCILING'),
  contextChanged('CONTEXT_CHANGED');

  /// OpenFeature-compatible event name.
  final String code;
  const FlagsClientEventType(this.code);
}

/// OpenFeature-compatible event error vocabulary, independent of its SDK.
enum FlagsClientErrorCode {
  providerNotReady('PROVIDER_NOT_READY'),
  flagNotFound('FLAG_NOT_FOUND'),
  parseError('PARSE_ERROR'),
  typeMismatch('TYPE_MISMATCH'),
  targetingKeyMissing('TARGETING_KEY_MISSING'),
  invalidContext('INVALID_CONTEXT'),
  providerFatal('PROVIDER_FATAL'),
  general('GENERAL');

  /// OpenFeature-compatible error code.
  final String code;
  const FlagsClientErrorCode(this.code);
}

/// Immutable details of a flag client event.
@immutable
final class FlagsClientEvent {
  final FlagsClientEventType type;
  final String providerName;

  /// A detached key snapshot. For [OnFirstFlags], this is the complete first
  /// installed configuration, including an empty list for an empty installation.
  /// Ordering is unspecified; subsequent client reads may observe newer data.
  final List<String>? flagsChanged;
  final String? message;
  final FlagsClientErrorCode? errorCode;

  /// Flat string, numeric, or boolean values. First-flags events leave this empty.
  final Map<String, Object> metadata;

  FlagsClientEvent({
    required this.type,
    required this.providerName,
    List<String>? flagsChanged,
    this.message,
    this.errorCode,
    Map<String, Object> metadata = const {},
  })  : flagsChanged =
            flagsChanged == null ? null : List.unmodifiable(flagsChanged),
        metadata = Map.unmodifiable(metadata) {
    if (this
        .metadata
        .values
        .any((value) => value is! String && value is! num && value is! bool)) {
      throw ArgumentError.value(
          metadata, 'metadata', 'Expected flat primitive values');
    }
  }
}
