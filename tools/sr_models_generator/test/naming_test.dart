// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:sr_models_generator/src/naming.dart';
import 'package:test/test.dart';

void main() {
  /// Registers one test per input of [cases]: input -> expected output.
  void testEach(
    String Function(String) convert,
    String description,
    Map<String, String> cases,
  ) {
    for (final MapEntry(key: input, value: output) in cases.entries) {
      test('$description: "$input" -> "$output"', () {
        expect(convert(input), output);
      });
    }
  }

  group('pascalCase', () {
    testEach(pascalCase, 'joins words separated by _, - or spaces', {
      'records_count': 'RecordsCount',
      'react-native': 'ReactNative',
      'kotlin multiplatform': 'KotlinMultiplatform',
      'embedded_content': 'EmbeddedContent',
    });
    testEach(pascalCase, 'keeps existing capitals', {
      'backgroundGradient': 'BackgroundGradient',
      'MobileFullSnapshotRecord': 'MobileFullSnapshotRecord',
      'base64': 'Base64',
    });
    testEach(pascalCase, 'ignores leading, trailing and repeated separators', {
      '_has__focus_': 'HasFocus',
      '---': '',
    });
  });

  group('camelCase', () {
    testEach(camelCase, 'lowercases only the first letter', {
      'records_count': 'recordsCount',
      'ShapeStyle': 'shapeStyle',
      'sourceOver': 'sourceOver',
      '': '',
    });
  });

  group('fieldName', () {
    testEach(fieldName, 'converts JSON keys to Dart names', {
      'has_full_snapshot': 'hasFullSnapshot',
      'index_in_view': 'indexInView',
      'permanentId': 'permanentId',
    });
    testEach(fieldName, 'escapes reserved words and generated members', {
      'default': 'defaultValue',
      'class': 'classValue',
      'hashCode': 'hashCodeValue',
      'to_json': 'toJsonValue',
    });
    // Composition layer modifiers have a `value` property, and `type` is not
    // reserved in Dart.
    testEach(fieldName, 'keeps names that are only reserved in enums', {
      'value': 'value',
      'index': 'index',
      'type': 'type',
    });
    testEach(fieldName, 'prefixes names that start with a digit or are empty', {
      '2d': 'v2d',
      '-': 'v',
    });
  });

  group('enumCaseName', () {
    testEach(enumCaseName, 'converts JSON values to Dart case names', {
      'react-native': 'reactNative',
      'kotlin-multiplatform': 'kotlinMultiplatform',
      'sourceOver': 'sourceOver',
    });
    testEach(enumCaseName, 'escapes members of Dart enums', {
      'values': 'valuesValue',
      'index': 'indexValue',
      'value': 'valueValue',
      'default': 'defaultValue',
    });
  });
}
