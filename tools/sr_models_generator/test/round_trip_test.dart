// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:test/test.dart';

import 'support/round_trip.dart';

void main() {
  // A correct model, and one model per kind of mistake the round trip must
  // catch. Only Point and Path define ==, so the others are also reported
  // as not equal after decoding again.
  const library = r'''
import 'package:meta/meta.dart';

@immutable
final class Point {
  const Point({required this.x, this.label});

  factory Point.fromJson(Map<String, Object?> json) => switch (json) {
    {'x': final int x, 'label': final String? label} => Point(x: x, label: label),
    {'x': final int x} => Point(x: x),
    _ => throw FormatException('Invalid Point: $json'),
  };

  final int x;
  final String? label;

  Map<String, Object?> toJson() => {'x': x, 'label': ?label};

  @override
  bool operator ==(Object other) =>
      other is Point && other.x == x && other.label == label;

  @override
  int get hashCode => Object.hash(x, label);
}

@immutable
final class Path {
  const Path(this.points);

  factory Path.fromJson(Map<String, Object?> json) => switch (json) {
    {'points': final List<Object?> points} => Path([
      for (final point in points)
        if (point case final Map<String, Object?> point) Point.fromJson(point),
    ]),
    _ => throw FormatException('Invalid Path: $json'),
  };

  final List<Point> points;

  Map<String, Object?> toJson() => {
    'points': [for (final point in points) point.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is Path &&
      other.points.length == points.length &&
      [for (var i = 0; i < points.length; i++) other.points[i] == points[i]]
          .every((same) => same);

  @override
  int get hashCode => Object.hashAll(points);
}

/// Leaves `label` out of its JSON.
final class DropsKey {
  const DropsKey(this.x);
  factory DropsKey.fromJson(Map<String, Object?> json) =>
      DropsKey(json['x'] as int);
  final int x;
  Map<String, Object?> toJson() => {'x': x};
}

/// Adds a key to its JSON.
final class AddsKey {
  const AddsKey(this.x);
  factory AddsKey.fromJson(Map<String, Object?> json) =>
      AddsKey(json['x'] as int);
  final int x;
  Map<String, Object?> toJson() => {'x': x, 'extra': true};
}

/// Writes a different value.
final class ChangesValue {
  const ChangesValue(this.x);
  factory ChangesValue.fromJson(Map<String, Object?> json) =>
      ChangesValue(json['x'] as int);
  final int x;
  Map<String, Object?> toJson() => {'x': x + 1};
}

/// Writes one point fewer.
final class DropsItem {
  const DropsItem(this.path);
  factory DropsItem.fromJson(Map<String, Object?> json) =>
      DropsItem(Path.fromJson(json));
  final Path path;
  Map<String, Object?> toJson() => {
    'points': [for (final point in path.points.skip(1)) point.toJson()],
  };
}

/// Changes the `x` of its last point.
final class ChangesNestedValue {
  const ChangesNestedValue(this.path);
  factory ChangesNestedValue.fromJson(Map<String, Object?> json) =>
      ChangesNestedValue(Path.fromJson(json));
  final Path path;
  Map<String, Object?> toJson() => {
    'points': [
      for (final point in path.points)
        point == path.points.last ? {'x': point.x + 1} : point.toJson(),
    ],
  };
}

/// Correct JSON, but no `==`.
final class NoEquality {
  NoEquality(this.x);
  factory NoEquality.fromJson(Map<String, Object?> json) =>
      NoEquality(json['x'] as int);
  final int x;
  Map<String, Object?> toJson() => {'x': x};
}
''';

  const point = {'x': 1, 'label': 'a'};
  const path = {
    'points': [
      {'x': 1},
      {'x': 2, 'label': 'b'},
    ],
  };

  // Case -> the errors the round trip must report.
  final cases = {
    const RoundTripCase('a point', 'Point', point): <String>[],
    const RoundTripCase('a point without its optional key', 'Point', {'x': 1}):
        <String>[],
    const RoundTripCase('a path of points', 'Path', path): <String>[],
    const RoundTripCase('a dropped key', 'DropsKey', point): [
      r'$.label: missing',
      'decoding the encoded JSON gives a model that is not ==',
    ],
    const RoundTripCase('an added key', 'AddsKey', {'x': 1}): [
      r'$.extra: unexpected',
      'decoding the encoded JSON gives a model that is not ==',
    ],
    const RoundTripCase('a changed value', 'ChangesValue', {'x': 1}): [
      r'$.x: expected 1, found 2',
      'decoding the encoded JSON gives a model that is not ==',
    ],
    const RoundTripCase('a dropped list item', 'DropsItem', path): [
      r'$.points: 2 items expected, 1 found',
      'decoding the encoded JSON gives a model that is not ==',
    ],
    const RoundTripCase('a changed nested value', 'ChangesNestedValue', path): [
      r'$.points[1].x: expected 2, found 3',
      r'$.points[1].label: missing',
      'decoding the encoded JSON gives a model that is not ==',
    ],
    const RoundTripCase('a model without ==', 'NoEquality', {'x': 1}): [
      'decoding the encoded JSON gives a model that is not ==',
    ],
  };

  late Map<String, RoundTripResult> results;

  setUpAll(() async {
    results = {
      for (final result in await roundTrip(library, [...cases.keys]))
        result.name: result,
    };
  });

  test('returns one result per case', () {
    expect(results.keys, [for (final c in cases.keys) c.name]);
  });

  for (final MapEntry(key: roundTripCase, value: errors) in cases.entries) {
    test('reports ${errors.isEmpty ? 'nothing' : 'it'} for '
        '${roundTripCase.name}', () {
      expect(results[roundTripCase.name]?.errors, unorderedEquals(errors));
    });
  }

  test('reports what fromJson throws', () async {
    final [result] = await roundTrip(library, [
      const RoundTripCase('an invalid point', 'Point', {'x': 'one'}),
    ]);
    expect(result.errors, [startsWith('threw FormatException: Invalid Point')]);
  });

  test('fails with the compiler output when the library does not compile', () {
    expect(
      roundTrip('final class Broken {', [
        const RoundTripCase('anything', 'Broken', {}),
      ]),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Error'),
        ),
      ),
    );
  });
}
