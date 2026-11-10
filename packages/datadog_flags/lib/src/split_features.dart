// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'flags_log.dart';

part 'split_features.g.dart';

/// Where the SDK routes a split feature.
enum SplitFeatureDestination {
  hook('HOOK', '__dd_feature.'),
  exposure('EXPOSURE', '__dd_exposure_feature.'),
  evaluation('EVALUATION', '__dd_evaluation_feature.');

  final String wireName;
  final String metadataPrefix;

  const SplitFeatureDestination(this.wireName, this.metadataPrefix);

  static SplitFeatureDestination? fromWireName(String name) {
    for (final destination in values) {
      if (destination.wireName == name) return destination;
    }
    return null;
  }
}

/// A key and value attached to the selected split of an assignment.
@immutable
@JsonSerializable(createFactory: false)
final class SplitFeature {
  final String key;

  /// A [String], [double], or [bool].
  final Object value;

  /// Destination names as received, including unknown ones.
  final List<String> destinations;

  const SplitFeature({
    required this.key,
    required this.value,
    required this.destinations,
  });

  bool routesTo(SplitFeatureDestination destination) =>
      destinations.contains(destination.wireName);

  /// Parses a `features` list. Invalid entries are skipped and never fail the
  /// assignment. On a repeated key, the first valid entry wins.
  static List<SplitFeature> listFromJson(Object? json) {
    if (json is! List || json.isEmpty) return const [];
    final features = <SplitFeature>[];
    final keys = <String>{};
    for (final entry in json) {
      final feature = _tryParse(entry);
      if (feature != null && keys.add(feature.key)) features.add(feature);
    }
    return features.isEmpty ? const [] : List.unmodifiable(features);
  }

  Map<String, Object?> toJson() => _$SplitFeatureToJson(this);

  static SplitFeature? _tryParse(Object? entry) {
    if (entry is! Map) return null;
    final key = entry['key'];
    if (key is! String || key.isEmpty) return null;
    final value = switch (entry['value']) {
      final String value => value,
      final bool value => value,
      final num value when value.isFinite => value.toDouble(),
      _ => null,
    };
    if (value == null) return null;
    final rawDestinations = entry['destinations'];
    if (rawDestinations is! List) return null;
    final destinations = [
      for (final destination in rawDestinations)
        if (destination is String && destination.isNotEmpty) destination,
    ];
    if (destinations.isEmpty) return null;
    return SplitFeature(
      key: key,
      value: value,
      destinations: List.unmodifiable(destinations),
    );
  }
}

extension SplitFeatureList on List<SplitFeature> {
  /// Features routed to [destination], keyed by feature key.
  Map<String, Object> forDestination(SplitFeatureDestination destination) {
    if (isEmpty) return const {};
    return {
      for (final feature in this)
        if (feature.routesTo(destination)) feature.key: feature.value,
    };
  }

  /// Flag metadata entries for every known destination of every feature.
  Map<String, Object> toFlagMetadata() {
    if (isEmpty) return const {};
    return {
      for (final feature in this)
        for (final destination in SplitFeatureDestination.values)
          if (feature.routesTo(destination))
            '${destination.metadataPrefix}${feature.key}': feature.value,
    };
  }
}

/// Reads the features of one destination back from flag metadata.
Map<String, Object> splitFeaturesFromMetadata(
  Map<String, Object> metadata,
  SplitFeatureDestination destination,
) {
  final prefix = destination.metadataPrefix;
  return Map.unmodifiable({
    for (final entry in metadata.entries)
      if (entry.key.startsWith(prefix))
        entry.key.substring(prefix.length): entry.value,
  });
}

/// Warns once for each distinct unknown destination name.
final class UnknownDestinationWarnings {
  static const maxWarnedValues = 64;

  final FlagsLogger _logger;
  final Set<String> _warned = {};

  UnknownDestinationWarnings(this._logger);

  void check(Iterable<SplitFeature> features) {
    for (final feature in features) {
      for (final name in feature.destinations) {
        if (_warned.length >= maxWarnedValues) return;
        if (SplitFeatureDestination.fromWireName(name) == null &&
            _warned.add(name)) {
          _logger.warning(
            'Ignoring unknown destination "$name" on flag feature '
            '"${feature.key}".',
          );
        }
      }
    }
  }
}
