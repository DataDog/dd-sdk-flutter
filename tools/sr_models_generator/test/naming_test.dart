// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:sr_models_generator/src/naming.dart';
import 'package:test/test.dart';

void main() {
  group('pascalCase', () {
    test('joins words separated by _, - or spaces', () {
      expect(pascalCase('records_count'), 'RecordsCount');
      expect(pascalCase('react-native'), 'ReactNative');
      expect(pascalCase('kotlin multiplatform'), 'KotlinMultiplatform');
      expect(pascalCase('embedded_content'), 'EmbeddedContent');
    });

    test('keeps existing capitals', () {
      expect(pascalCase('backgroundGradient'), 'BackgroundGradient');
      expect(
        pascalCase('MobileFullSnapshotRecord'),
        'MobileFullSnapshotRecord',
      );
      expect(pascalCase('base64'), 'Base64');
    });

    test('ignores leading, trailing and repeated separators', () {
      expect(pascalCase('_has__focus_'), 'HasFocus');
      expect(pascalCase('---'), isEmpty);
    });
  });

  test('camelCase lowercases only the first letter', () {
    expect(camelCase('records_count'), 'recordsCount');
    expect(camelCase('ShapeStyle'), 'shapeStyle');
    expect(camelCase('sourceOver'), 'sourceOver');
    expect(camelCase(''), isEmpty);
  });

  group('fieldName', () {
    test('converts JSON keys to Dart names', () {
      expect(fieldName('has_full_snapshot'), 'hasFullSnapshot');
      expect(fieldName('index_in_view'), 'indexInView');
      expect(fieldName('permanentId'), 'permanentId');
    });

    test('escapes reserved words and generated members', () {
      expect(fieldName('default'), 'defaultValue');
      expect(fieldName('class'), 'classValue');
      expect(fieldName('hashCode'), 'hashCodeValue');
      expect(fieldName('to_json'), 'toJsonValue');
    });

    test('keeps names that are only reserved in enums', () {
      // Composition layer modifiers have a `value` property.
      expect(fieldName('value'), 'value');
      expect(fieldName('index'), 'index');
      // `type` is not reserved in Dart.
      expect(fieldName('type'), 'type');
    });

    test('prefixes names that would start with a digit or be empty', () {
      expect(fieldName('2d'), 'v2d');
      expect(fieldName('-'), 'v');
    });
  });

  group('enumCaseName', () {
    test('converts JSON values to Dart case names', () {
      expect(enumCaseName('react-native'), 'reactNative');
      expect(enumCaseName('kotlin-multiplatform'), 'kotlinMultiplatform');
      expect(enumCaseName('sourceOver'), 'sourceOver');
    });

    test('escapes members of Dart enums', () {
      expect(enumCaseName('values'), 'valuesValue');
      expect(enumCaseName('index'), 'indexValue');
      expect(enumCaseName('value'), 'valueValue');
      expect(enumCaseName('default'), 'defaultValue');
    });
  });
}
