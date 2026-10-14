// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:meta/meta.dart';

import 'assignment.dart';
import 'evaluation_context.dart';
import 'flag_key_obfuscation.dart';

/// Storage contract for last-known feature flag assignments.
abstract class DatadogFlagsStore {
  /// Creates a storage adapter for flag assignment snapshots.
  const DatadogFlagsStore();

  /// Reads stored assignment data for [clientName].
  Future<FlagsData?> read(String clientName);

  /// Writes assignment [data] for [clientName].
  Future<void> write(String clientName, FlagsData data);

  /// Deletes stored assignment data for [clientName].
  Future<void> delete(String clientName);
}

/// Snapshot of flag assignments for a specific evaluation context.
@immutable
class FlagsData {
  /// Assignments keyed by the wire key for this snapshot's encoding.
  final Map<String, FlagAssignment> flags;

  /// Evaluation context that produced [flags].
  final FlagsEvaluationContext context;

  /// Timestamp when this data was created or stored.
  final DateTime date;

  /// Encoding metadata stored with these assignments. Null means legacy keys.
  final FlagKeyObfuscation? obfuscation;

  /// Creates a flag assignment snapshot.
  const FlagsData({
    required this.flags,
    required this.context,
    required this.date,
    this.obfuscation,
  });

  /// Creates a flag assignment snapshot from persisted JSON.
  factory FlagsData.fromJson(Map<String, Object?> json) {
    final obfuscation = FlagKeyObfuscation.fromSnapshot(json);
    final flags = obfuscation == null
        ? json['flags'] as Map<String, Object?>? ?? const {}
        : json['encodedFlags'] as Map<String, Object?>;
    obfuscation?.validateKeys(flags.keys);
    return FlagsData(
      flags: flags.map((key, value) {
        return MapEntry(
          key,
          FlagAssignment.fromJson(Map<String, Object?>.from(value as Map)),
        );
      }),
      context: FlagsEvaluationContext.fromJson(
        Map<String, Object?>.from(json['context'] as Map),
      ),
      date: DateTime.parse(json['date'] as String),
      obfuscation: obfuscation,
    );
  }

  /// Converts this snapshot to persisted JSON.
  Map<String, Object?> toJson() {
    return {
      // Older SDKs read only `flags`. Keep encoded assignments separate so a
      // downgraded SDK cannot interpret their digests as plaintext flag keys.
      if (obfuscation == null)
        'flags': flags.map((key, value) => MapEntry(key, value.toJson()))
      else
        'encodedFlags':
            flags.map((key, value) => MapEntry(key, value.toJson())),
      'context': context.toJson(),
      'date': date.toIso8601String(),
      if (obfuscation != null) ...{
        'obfuscated': true,
        'obfuscation': obfuscation!.toJson(),
      },
    };
  }
}

class InMemoryDatadogFlagsStore implements DatadogFlagsStore {
  final Map<String, FlagsData> _values = {};

  @override
  Future<FlagsData?> read(String clientName) async {
    final value = _values[clientName];
    return value == null ? null : _cloneFlagsData(value);
  }

  @override
  Future<void> write(String clientName, FlagsData data) async {
    _values[clientName] = _cloneFlagsData(data);
  }

  @override
  Future<void> delete(String clientName) async {
    _values.remove(clientName);
  }
}

FlagsData _cloneFlagsData(FlagsData value) {
  return FlagsData.fromJson(value.toJson());
}
