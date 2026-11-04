// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_flags/src/assignment.dart';
import 'package:datadog_flags/src/numeric_value.dart';
import 'package:test/test.dart';

void main() {
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
              const bool.fromEnvironment('dart.library.js_interop')
                  ? isNull
                  : '9007199254740993',
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

  test('wire strings and cache-shaped objects are not numeric values', () {
    for (final value in [
      '5',
      {'_numericLiteral': '5'},
    ]) {
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
    }
  });
}
