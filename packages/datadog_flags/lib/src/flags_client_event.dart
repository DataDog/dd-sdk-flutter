// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:meta/meta.dart';

/// Implemented flag client event types. Declaring a value does not emit it.
enum FlagsClientEventType {
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

  /// A snapshot of the supplied flag keys.
  ///
  /// `null` means keys were not supplied; an empty list means an explicitly
  /// supplied empty list. This value does not infer or evaluate any keys.
  final List<String>? flagsChanged;

  /// Creates an event, copying [flagsChanged] into an unmodifiable list when
  /// supplied. Later changes to the caller's list cannot change this value.
  FlagsClientEvent({required this.type, List<String>? flagsChanged})
      : flagsChanged = flagsChanged == null
            ? null
            : List<String>.unmodifiable(flagsChanged);
}
