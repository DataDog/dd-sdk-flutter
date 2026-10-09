// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:meta/meta.dart';

/// The kinds of notifications emitted by a flag client.
enum FlagsClientEventType {
  /// A flag configuration has been installed.
  configurationChanged('CONFIGURATION_CHANGED');

  /// Cross-SDK event name corresponding to this Dart case.
  final String code;

  const FlagsClientEventType(this.code);
}

/// Immutable event data, independent of event registration and delivery.
@immutable
final class FlagsClientEvent {
  /// The kind of event represented by this value.
  final FlagsClientEventType type;

  /// Keys in the accepted configuration represented by this event.
  ///
  /// `null` means keys were not supplied; an empty list means an explicitly
  /// supplied empty list. This value does not infer or evaluate any keys.
  final List<String>? flagsChanged;

  /// SDK-internal event construction; applications receive events from
  /// [DatadogFlagsClient.onFirstFlags] rather than constructing them.
  ///
  /// Copies [flagsChanged] into an unmodifiable list when supplied. Later
  /// changes to the source list cannot change this value.
  @internal
  FlagsClientEvent({required this.type, List<String>? flagsChanged})
      : flagsChanged = flagsChanged == null
            ? null
            : List<String>.unmodifiable(flagsChanged);
}
