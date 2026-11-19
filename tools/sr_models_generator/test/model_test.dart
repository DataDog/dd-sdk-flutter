// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:sr_models_generator/sr_models_generator.dart';
import 'package:test/test.dart';

void main() {
  const integer = PrimitiveType(Primitive.integer);
  const string = PrimitiveType(Primitive.string);

  Field field(
    String key, {
    TypeRef type = integer,
    bool isRequired = true,
    Object? constValue,
  }) => Field(
    jsonKey: key,
    dartName: key,
    type: type,
    isRequired: isRequired,
    description: null,
    constValue: constValue,
  );

  ClassDefinition classWith(String name, List<Field> fields) =>
      ClassDefinition(name: name, location: '$name.json', description: null)
        ..fields.addAll(fields);

  UnionDefinition unionOf(Map<Object, ClassDefinition> variants) =>
      UnionDefinition(
          name: 'SRShape',
          location: 'shape.json',
          description: null,
        )
        ..discriminatorKey = 'type'
        ..variants.addAll(variants);

  group('TypeRef equality', () {
    test('primitives are equal when they are the same primitive', () {
      expect(const PrimitiveType(Primitive.integer), integer);
      expect(integer, isNot(string));
    });

    test('lists are equal when their items are', () {
      expect(const ListType(integer), const ListType(integer));
      expect(
        const ListType(ListType(string)),
        const ListType(ListType(string)),
      );
      expect(const ListType(integer), isNot(const ListType(string)));
    });

    test('named types are equal only for the same definition', () {
      final a = classWith('SRA', []);
      final sameName = classWith('SRA', []);
      expect(NamedType(a), NamedType(a));
      expect(NamedType(a).hashCode, NamedType(a).hashCode);
      expect(NamedType(a), isNot(NamedType(sameName)));
    });

    test('toString reads like a type', () {
      expect(
        ListType(NamedType(classWith('SRWireframe', []))).toString(),
        'List<SRWireframe>',
      );
    });
  });

  group('Field', () {
    test('is const when it has a const value, including 0', () {
      expect(field('id').isConst, isFalse);
      expect(field('type', type: string, constValue: 'shape').isConst, isTrue);
      expect(field('source', constValue: 0).isConst, isTrue);
    });

    test('a const field must be required', () {
      expect(
        () => field('type', isRequired: false, constValue: 'shape'),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  test('ClassDefinition.constField finds const fields only', () {
    final circle = classWith('SRCircle', [
      field('id'),
      field('type', type: string, constValue: 'circle'),
    ]);
    expect(circle.constField('type')?.constValue, 'circle');
    expect(circle.constField('id'), isNull);
    expect(circle.constField('missing'), isNull);
  });

  group('UnionDefinition.sharedFields', () {
    test('keeps the fields every variant has, in first-variant order', () {
      final union = unionOf({
        'circle': classWith('SRCircle', [
          field('id'),
          field('type', type: string, constValue: 'circle'),
          field('radius'),
          field('clip', isRequired: false),
        ]),
        'square': classWith('SRSquare', [
          field('clip', isRequired: false),
          field('side'),
          field('type', type: string, constValue: 'square'),
          field('id'),
        ]),
      });
      expect(union.sharedFields.map((f) => f.jsonKey), ['id', 'type', 'clip']);
    });

    test('includes the discriminator even though its value differs', () {
      final union = unionOf({
        'circle': classWith('SRCircle', [
          field('type', type: string, constValue: 'circle'),
        ]),
        'square': classWith('SRSquare', [
          field('type', type: string, constValue: 'square'),
        ]),
      });
      expect(union.sharedFields.single.jsonKey, 'type');
    });

    test('drops fields that differ in type, requiredness or constness', () {
      final union = unionOf({
        'circle': classWith('SRCircle', [
          field('size'),
          field('label', type: string),
          field('kind', type: string),
        ]),
        'square': classWith('SRSquare', [
          field('size', type: string),
          field('label', type: string, isRequired: false),
          field('kind', type: string, constValue: 'square'),
        ]),
      });
      expect(union.sharedFields, isEmpty);
    });

    test('is empty for a union without variants', () {
      expect(unionOf({}).sharedFields, isEmpty);
    });
  });
}
