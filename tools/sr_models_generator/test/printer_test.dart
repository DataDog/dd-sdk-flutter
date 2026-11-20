// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:path/path.dart' as p;
import 'package:sr_models_generator/sr_models_generator.dart';
import 'package:test/test.dart';

import 'support/package_root.dart';
import 'support/round_trip.dart';

void main() {
  // Values that must be escaped in a Dart string literal.
  final quirky = EnumDefinition(
    name: 'SRQuirky',
    location: 'quirky.json',
    description: null,
    values: {
      "it's": 'itS',
      r'$price': 'price',
      r'back\slash': 'backSlash',
      'line\nbreak': 'lineBreak',
      'tab\there': 'tabHere',
      'bell\u0007': 'bell',
      'naïve': 'naive',
    },
  );

  late List<EnumDefinition> enums;
  late String library;

  setUpAll(() async {
    final fixtures = p.join(await packageRoot(), 'test', 'fixtures');
    final resolver = ModelResolver(SchemaLoader(p.join(fixtures, 'resolver')))
      ..resolveRoot('text-schema.json');
    enums = [...resolver.definitions.whereType<EnumDefinition>(), quirky];
    library = const DartPrinter().printLibrary(enums);
  });

  group('enums', () {
    late Map<String, RoundTripResult> results;

    setUpAll(() async {
      results = {
        for (final result in await roundTrip(library, [
          for (final e in enums)
            for (final value in e.values.keys)
              RoundTripCase('${e.name} ${dartString(value)}', e.name, value),
          const RoundTripCase('unknown', 'SRPlatform', 'nope'),
        ]))
          result.name: result,
      };
    });

    test('prints the enums of the schemas', () {
      expect(
        [for (final e in enums) e.name],
        ['SRPlatform', 'SRTextAlignments', 'SRTextTruncationMode', 'SRQuirky'],
      );
    });

    // Every value of every enum, decoded and encoded back unchanged.
    final values = {
      'SRPlatform': ['ios', 'react-native', 'kotlin-multiplatform', 'values'],
      'SRTextAlignments': ['left', 'right'],
      'SRTextTruncationMode': ['clip', 'head', 'tail', 'middle'],
      'SRQuirky': [...quirky.values.keys],
    };
    for (final MapEntry(key: name, value: jsonValues) in values.entries) {
      for (final value in jsonValues) {
        test('$name round-trips ${dartString(value)}', () {
          expect(results['$name ${dartString(value)}']?.errors, isEmpty);
        });
      }
    }

    test('fromJson fails on a value the enum does not have', () {
      expect(results['unknown']?.errors, [
        'threw FormatException: Unknown SRPlatform value: nope',
      ]);
    });

    test('names each case after its value', () {
      expect(library, contains("  reactNative('react-native')"));
      expect(library, contains("  valuesValue('values')"));
    });
  });

  test('starts with the header, as comments', () {
    expect(
      const DartPrinter(
        header: ['Generated.', '', 'Do not edit.'],
      ).printLibrary([quirky]).split('\n').take(3),
      ['// Generated.', '//', '// Do not edit.'],
    );
  });

  final notPrintedYet = {
    'a union': UnionDefinition(
      name: 'SRShape',
      location: 'shape.json',
      description: null,
    ),
  };
  for (final MapEntry(key: kind, value: definition) in notPrintedYet.entries) {
    test('does not print $kind yet', () {
      expect(
        () => const DartPrinter().printLibrary([definition]),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            'Printing ${definition.name} is not supported yet',
          ),
        ),
      );
    });
  }

  group('classes', () {
    // Fixtures with objects, lists, enums and const fields, but no unions.
    const fixtures = [
      'primitives-schema.json',
      'shapes-schema.json',
      'text-schema.json',
      'wireframe-schema.json',
      'tree-schema.json',
    ];
    late String library;
    late Map<String, RoundTripResult> results;

    // Case -> the errors the round trip must report.
    final cases = {
      const RoundTripCase('every primitive', 'SRPrimitives', {
        'count': 1,
        'ratio': 0.5,
        'text': 'a',
        'is_visible': true,
      }): <String>[],
      const RoundTripCase('only the required keys', 'SRPrimitives', {
        'count': 1,
        'text': 'a',
      }): <String>[],
      const RoundTripCase('an integer written as 2.0', 'SRPrimitives', {
        'count': 2.0,
        'text': 'a',
      }): <String>[],
      const RoundTripCase('a number written as 1', 'SRPrimitives', {
        'count': 1,
        'ratio': 1,
        'text': 'a',
      }): <String>[],
      const RoundTripCase('lists, nested and inline objects', 'SRShapes', {
        'tags': ['a', 'b'],
        'grid': [
          [1, 2],
          [3],
        ],
        'points': [
          {'x': 1, 'y': 2},
        ],
        'origin': {'x': 0, 'y': 0},
        'center': {'x': 5, 'y': 5},
        'meta': {
          'size': {'width': 3},
        },
        'stops': [
          {'offset': 0.5},
        ],
        'alias': {'x': 1, 'y': 1},
      }): <String>[],
      const RoundTripCase('enums and const fields', 'SRText', {
        'type': 'text',
        'version': 0,
        'truncation_mode': 'tail',
        'platform': 'react-native',
        'fallback_platform': 'ios',
        'alignments': ['left', 'right'],
      }): <String>[],
      const RoundTripCase('merged allOf parts', 'SRShapeWireframe', {
        'id': 1,
        'clip': {'x': 0, 'y': 0},
        'border': 'red',
        'style': {'color': 'blue'},
        'type': 'shape',
      }): <String>[],
      const RoundTripCase('a class that uses itself', 'SRTree', {
        'children': [
          {'children': <Object?>[]},
          <String, Object?>{},
        ],
      }): <String>[],
      const RoundTripCase('a missing required key', 'SRPrimitives', {
        'text': 'a',
      }): [
        'threw FormatException: Invalid SRPrimitives.count: null',
      ],
      const RoundTripCase('a value of the wrong type', 'SRPrimitives', {
        'count': 'one',
        'text': 'a',
      }): [
        'threw FormatException: Invalid SRPrimitives.count: one',
      ],
      const RoundTripCase('a decimal for an integer', 'SRPrimitives', {
        'count': 1.5,
        'text': 'a',
      }): [
        'threw FormatException: Invalid SRPrimitives.count: 1.5',
      ],
      const RoundTripCase('a list item of the wrong type', 'SRShapes', {
        'tags': ['a', 1],
        'points': <Object?>[],
      }): [
        'threw FormatException: Invalid SRShapes.tags[1]: 1',
      ],
      const RoundTripCase('a nested object that is not one', 'SRShapes', {
        'tags': <Object?>[],
        'points': <Object?>[],
        'origin': 'here',
      }): [
        'threw FormatException: Invalid SRShapes.origin: here',
      ],
      const RoundTripCase('an unknown enum value', 'SRText', {
        'type': 'text',
        'version': 0,
        'truncation_mode': 'nope',
        'platform': 'ios',
      }): [
        'threw FormatException: Unknown SRTextTruncationMode value: nope',
      ],
    };

    late String resolverFixtures;

    /// The definitions of the resolver fixture [file] alone.
    List<Definition> definitionsOf(String file) => (ModelResolver(
      SchemaLoader(resolverFixtures),
    )..resolveRoot(file)).definitions;

    setUpAll(() async {
      resolverFixtures = p.join(
        await packageRoot(),
        'test',
        'fixtures',
        'resolver',
      );
      final resolver = ModelResolver(SchemaLoader(resolverFixtures));
      for (final fixture in fixtures) {
        resolver.resolveRoot(fixture);
      }
      library = const DartPrinter().printLibrary(resolver.definitions);
      results = {
        for (final result in await roundTrip(library, [...cases.keys]))
          result.name: result,
      };
    });

    for (final MapEntry(key: roundTripCase, value: errors) in cases.entries) {
      test('round-trips ${roundTripCase.name}', () {
        expect(results[roundTripCase.name]?.errors, errors);
      });
    }

    test('prints immutable final classes with a const constructor', () {
      expect(library, contains('@immutable\nfinal class SRPoint {'));
      expect(
        library,
        contains('const SRPoint({required this.x, required this.y});'),
      );
    });

    test('prints const fields as getters, not constructor parameters', () {
      expect(library, contains("String get type => 'text';"));
      expect(library, contains('int get version => 0;'));
      final constructor = RegExp(
        r'const SRText\(\{[^}]*\}\);',
      ).firstMatch(library)?[0];
      expect(constructor, isNotNull);
      expect(constructor, isNot(contains('this.type')));
      expect(constructor, isNot(contains('this.version')));
    });

    test('declares only the decoding helpers it uses', () {
      final enumsOnly = const DartPrinter().printLibrary([quirky]);
      expect(enumsOnly, isNot(contains('_invalid')));
      expect(enumsOnly, isNot(contains("import 'package:meta/meta.dart';")));
      expect(library, contains("import 'package:meta/meta.dart';"));
    });

    group('==', () {
      const primitives = {'count': 1, 'ratio': 0.5, 'text': 'a'};
      const shapes = {
        'tags': ['a'],
        'grid': [
          [1, 2],
        ],
        'points': [
          {'x': 1, 'y': 2},
        ],
        'origin': {'x': 0, 'y': 0},
      };
      Map<String, Object?> withValue(String key, Object? value) => {
        ...shapes,
        key: value,
      };

      // Case -> whether the two models are equal.
      final cases = {
        const ComparisonCase('the same JSON', 'SRPrimitives', primitives, {
          ...primitives,
        }): true,
        const ComparisonCase('another value', 'SRPrimitives', primitives, {
          'count': 2,
          'ratio': 0.5,
          'text': 'a',
        }): false,
        ComparisonCase(
          'an optional field left out',
          'SRPrimitives',
          primitives,
          {
            for (final MapEntry(:key, :value) in primitives.entries)
              if (key != 'ratio') key: value,
          },
        ): false,
        const ComparisonCase('equal lists, at any depth', 'SRShapes', shapes, {
          ...shapes,
        }): true,
        ComparisonCase(
          'another value in a nested list',
          'SRShapes',
          shapes,
          withValue('grid', [
            [1, 3],
          ]),
        ): false,
        ComparisonCase(
          'a list with another length',
          'SRShapes',
          shapes,
          withValue('tags', ['a', 'b']),
        ): false,
        ComparisonCase(
          'another value in a listed object',
          'SRShapes',
          shapes,
          withValue('points', [
            {'x': 1, 'y': 3},
          ]),
        ): false,
        ComparisonCase(
          'another value in a nested object',
          'SRShapes',
          shapes,
          withValue('origin', {'x': 0, 'y': 1}),
        ): false,
        const ComparisonCase(
          'enums and const fields',
          'SRText',
          {
            'type': 'text',
            'version': 0,
            'truncation_mode': 'tail',
            'platform': 'ios',
          },
          {
            'type': 'text',
            'version': 0,
            'truncation_mode': 'tail',
            'platform': 'ios',
          },
        ): true,
        const ComparisonCase(
          'another enum value',
          'SRText',
          {
            'type': 'text',
            'version': 0,
            'truncation_mode': 'tail',
            'platform': 'ios',
          },
          {
            'type': 'text',
            'version': 0,
            'truncation_mode': 'clip',
            'platform': 'ios',
          },
        ): false,
        const ComparisonCase(
          'a class without fields',
          'SRShapesMetaSize',
          {'width': 1},
          {'width': 1},
        ): true,
      };
      late Map<String, Comparison> comparisons;

      setUpAll(() async {
        comparisons = {
          for (final result in await compareModels(library, [...cases.keys]))
            result.name: result,
        };
      });

      for (final MapEntry(key: comparison, value: equal) in cases.entries) {
        test('is $equal for ${comparison.name}', () {
          expect(comparisons[comparison.name]?.equal, equal);
          if (equal) expect(comparisons[comparison.name]?.sameHash, isTrue);
        });
      }

      test('compares lists item by item only when the class has lists', () {
        final primitivesOnly = const DartPrinter().printLibrary(
          definitionsOf('primitives-schema.json'),
        );
        expect(primitivesOnly, contains('other.count == count'));
        expect(primitivesOnly, isNot(contains('_equals')));
        expect(library, contains('_equals(other.grid, grid)'));
      });
    });
  });

  group('dartString', () {
    final literals = {
      'plain': "'plain'",
      "it's": r"'it\'s'",
      r'$price': r"'\$price'",
      r'back\slash': r"'back\\slash'",
      'line\nbreak': r"'line\nbreak'",
      'bell\u0007': r"'bell\u{7}'",
      'naïve': "'naïve'",
    };
    for (final MapEntry(key: value, value: literal) in literals.entries) {
      test('writes $literal', () {
        expect(dartString(value), literal);
      });
    }
  });
}
