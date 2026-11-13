// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_flags/src/assignment.dart';
import 'package:datadog_flags/src/numeric_value.dart';
import 'package:datadog_flags/datadog_flags.dart';
import 'package:test/test.dart';

void main() {
  for (final (label, literal) in <(String, String)>[
    ('integer', '42'),
    ('integer', '-7'),
    ('float', '2.25'),
    ('number', '5.0'),
    ('number', '9007199254740993'),
    ('number', '100000000000000000001'),
    ('float', '1e300'),
    ('integer', '0'),
    ('float', '-0.0'),
    ('number', '0e999999'),
  ]) {
    test('$label $literal snapshot remains readable by the legacy decoder', () {
      final snapshot = _numericSnapshot(label, literal);
      final encoded = jsonDecode(jsonEncode(snapshot.toJson())) as Map;
      final assignment = (encoded['flags'] as Map)['flag'] as Map;
      expect(_legacyNumericValue(assignment), jsonDecode(literal));
      expect(assignment['variationValue'], jsonDecode(literal));
      expect(assignment['_numericLiteral'], literal);
      final restored = FlagsData.fromJson(Map<String, Object?>.from(encoded));
      expect(restored.flags['flag']!.numericValue!.literal, literal);
      expect(snapshot.flags['flag']!.variationValue, jsonDecode(literal));
    });
  }

  for (final literal in ['1e400', '1e-400']) {
    test('$literal snapshot retains an explicit unsupported numeric token', () {
      final snapshot = _numericSnapshot('number', literal);
      final encoded = jsonDecode(jsonEncode(snapshot.toJson())) as Map;
      final assignment = (encoded['flags'] as Map)['flag'] as Map;
      expect(snapshot.flags['flag']!.variationValue, {
        '_numericLiteral': literal,
      });
      expect(assignment['variationValue'], {'_numericLiteral': literal});
      expect(() => _legacyNumericValue(assignment), throwsFormatException);
      final restored = FlagsData.fromJson(Map<String, Object?>.from(encoded));
      expect(restored.flags['flag']!.numericValue!.literal, literal);
      expect(restored.flags['flag']!.numericValue!.integer, isNull);
      expect(restored.flags['flag']!.numericValue!.floating, isNull);
    });
  }

  test('cache reader accepts the interim object marker', () {
    final snapshot = _numericSnapshot('number', '5.0').toJson();
    final assignment = (snapshot['flags'] as Map)['flag'] as Map;
    assignment.remove('_numericLiteral');
    assignment['variationValue'] = {'_numericLiteral': '5.0'};
    final restored = FlagsData.fromJson(snapshot);
    expect(restored.flags['flag']!.numericValue!.integer, 5);
  });

  test(
    'cache reader prefers sibling numeric metadata over the rounded value',
    () {
      final snapshot = _numericSnapshot(
        'number',
        '100000000000000000001',
      ).toJson();
      final restored = FlagsData.fromJson(snapshot);
      expect(restored.flags['flag']!.variationValue, 1e20);
      expect(restored.flags['flag']!.numericValue!.integer, isNull);
      expect(restored.flags['flag']!.numericValue!.floating, isNull);
    },
  );

  test('numeric wire values do not trust cache-only sibling metadata', () {
    final assignment = FlagAssignment.fromJson({
      'allocationKey': 'a',
      'variationKey': 'v',
      'variationType': 'number',
      'variationValue': 5,
      '_numericLiteral': '7',
      'reason': 'STATIC',
      'doLog': false,
    });
    expect(assignment.variationValue, 5);
    expect(assignment.numericValue, isNull);
  });

  final cases = <(String, int?, double?)>[
    ('5.0', 5, 5),
    ('1.20000000000000001', null, 1.2),
    ('1.00000000000000001', null, 1),
    ('4503599627370497.5', null, 4503599627370498),
    ('9007199254740993.5', null, 9007199254740994),
    ('9007199254740993', null, null),
    ('1e-400', null, null),
    ('1e400', null, null),
    ('0e999999', 0, 0),
    ('-0.0', 0, 0),
  ];
  for (final label in ['number', 'integer', 'float']) {
    for (final (literal, integer, floating) in cases) {
      test('$label $literal preserves original number across cache restore', () {
        final text =
            '{"data":{"attributes":{"flags":{"flag":{'
            '"allocationKey":"a","variationKey":"v","variationType":"$label",'
            '"variationValue":$literal,"reason":"STATIC","doLog":false}}}}}';
        final envelope = decodeNumericAssignments(text);
        final flags =
            ((envelope['data'] as Map)['attributes'] as Map)['flags'] as Map;
        final assignment = FlagAssignment.fromJson(
          Map<String, Object?>.from(flags['flag'] as Map),
        );
        final restored = FlagAssignment.fromCacheJson(
          Map<String, Object?>.from(
            jsonDecode(jsonEncode(assignment.toJson())) as Map,
          ),
        );
        for (final value in [assignment, restored]) {
          // The native Int64 value is available on the VM; JS integers have a smaller exact range.
          if (literal == '9007199254740993') {
            expect(
              value.numericValue!.integer?.toString(),
              identical(1, 1.0) ? isNull : '9007199254740993',
            );
          } else {
            expect(value.numericValue!.integer, integer);
          }
          expect(value.numericValue!.floating, floating);
        }
      });
    }
  }

  test(
    'object flag payloads cannot be mistaken for numeric cache metadata',
    () {
      final assignment = FlagAssignment.fromJson({
        'allocationKey': 'a',
        'variationKey': 'v',
        'variationType': 'object',
        'variationValue': {'_numericLiteral': 'customer data'},
        'reason': 'STATIC',
        'doLog': false,
      });
      final restored = FlagAssignment.fromCacheJson(
        Map<String, Object?>.from(
          jsonDecode(jsonEncode(assignment.toJson())) as Map,
        ),
      );
      expect(restored.variationValue, {'_numericLiteral': 'customer data'});
      expect(restored.numericValue, isNull);
    },
  );

  for (final (name, value) in <(String, Object)>[
    ('wire string', '5'),
    ('cache-shaped object', {'_numericLiteral': '5'}),
  ]) {
    test('$name is not a numeric wire value', () {
      expect(
        () => FlagAssignment.fromJson({
          'allocationKey': 'a',
          'variationKey': 'v',
          'variationType': 'number',
          'variationValue': value,
          'reason': 'STATIC',
          'doLog': false,
        }),
        throwsFormatException,
      );
    });
  }
}

FlagsData _numericSnapshot(String label, String literal) {
  final envelope = decodeNumericAssignments(
    '{"data":{"attributes":{"flags":{"flag":{'
    '"allocationKey":"a","variationKey":"v","variationType":"$label",'
    '"variationValue":$literal,"reason":"STATIC","doLog":false}}}}}',
  );
  final flags =
      ((envelope['data'] as Map)['attributes'] as Map)['flags'] as Map;
  return FlagsData(
    flags: {
      'flag': FlagAssignment.fromJson(
        Map<String, Object?>.from(flags['flag'] as Map),
      ),
    },
    context: FlagsEvaluationContext(targetingKey: 'test'),
    date: DateTime.utc(2026, 11, 13),
  );
}

// Numeric decoder frozen from develop at 1e5bcd162c0399f24b3f3d6ca1e70bcacc14ebce.
// It must remain independent of the current FlagVariationType implementation.
num _legacyNumericValue(Map<Object?, Object?> assignment) {
  final value = assignment['variationValue'];
  return switch (assignment['variationType']) {
    'integer' when value is int => value,
    'float' when value is num => value.toDouble(),
    'number' when value is num => value,
    _ => throw const FormatException('Invalid legacy numeric variation value'),
  };
}
