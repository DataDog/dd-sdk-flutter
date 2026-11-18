// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:path/path.dart' as p;
import 'package:sr_models_generator/sr_models_generator.dart';
import 'package:test/test.dart';

const integer = PrimitiveType(Primitive.integer);
const number = PrimitiveType(Primitive.number);
const string = PrimitiveType(Primitive.string);
const boolean = PrimitiveType(Primitive.boolean);

/// The result of resolving one fixture.
class Resolved {
  Resolved(this.root, List<Definition> definitions)
    : names = [for (final d in definitions) d.name],
      _byName = {for (final d in definitions) d.name: d};

  final TypeRef root;

  /// Names of all definitions, in the order the resolver returns them.
  final List<String> names;
  final Map<String, Definition> _byName;

  ClassDefinition operator [](String name) => _byName[name]! as ClassDefinition;

  NamedType named(String name) => NamedType(_byName[name]!);
}

Resolved resolve(String file) {
  final resolver = ModelResolver(
    SchemaLoader(p.join('test', 'fixtures', 'resolver')),
  );
  final root = resolver.resolveRoot(file);
  return Resolved(root, resolver.definitions);
}

extension on ClassDefinition {
  Field field(String jsonKey) =>
      fields.singleWhere((f) => f.jsonKey == jsonKey);
}

void main() {
  group('primitives', () {
    late Resolved resolved;
    setUp(() => resolved = resolve('primitives-schema.json'));

    test('the root object becomes a class named after its title', () {
      expect(resolved.names, ['SRPrimitives']);
      expect(resolved.root, resolved.named('SRPrimitives'));
      expect(
        resolved['SRPrimitives'].description,
        'One property of each primitive type.',
      );
      expect(resolved['SRPrimitives'].location, 'primitives-schema.json');
    });

    test('maps each JSON type to a primitive, in schema order', () {
      final fields = resolved['SRPrimitives'].fields;
      expect(fields.map((f) => f.jsonKey), [
        'count',
        'ratio',
        'text',
        'is_visible',
      ]);
      expect(fields.map((f) => f.type), [integer, number, string, boolean]);
    });

    test('marks the keys listed in "required"', () {
      final fields = resolved['SRPrimitives'].fields;
      expect(fields.map((f) => f.isRequired), [true, false, true, false]);
    });

    test('names fields in Dart style and keeps descriptions', () {
      final primitives = resolved['SRPrimitives'];
      expect(primitives.field('is_visible').dartName, 'isVisible');
      expect(primitives.field('count').description, 'An integer.');
      expect(primitives.field('ratio').description, isNull);
      expect(primitives.fields.every((f) => !f.isConst), isTrue);
    });
  });

  group('lists, references and inline objects', () {
    late Resolved resolved;
    setUp(() => resolved = resolve('shapes-schema.json'));

    test('arrays become lists of their items', () {
      final shapes = resolved['SRShapes'];
      expect(shapes.field('tags').type, const ListType(string));
      expect(shapes.field('grid').type, const ListType(ListType(integer)));
      expect(shapes.field('points').type, ListType(resolved.named('SRPoint')));
    });

    test('a schema referenced several times is one definition', () {
      final shapes = resolved['SRShapes'];
      final point = resolved.named('SRPoint');
      expect(shapes.field('origin').type, point);
      expect(shapes.field('center').type, point);
      expect(resolved.names.where((n) => n == 'SRPoint'), hasLength(1));
    });

    test('allOf around a single \$ref is that reference', () {
      final center = resolved['SRShapes'].field('center');
      expect(center.type, resolved.named('SRPoint'));
      expect(
        center.description,
        'A wrapped reference keeps its own description.',
      );
    });

    test('a field using a titled type does not copy its description', () {
      expect(resolved['SRPoint'].description, 'A point.');
      expect(resolved['SRShapes'].field('origin').description, isNull);
    });

    test('inline objects are named after their owner and property', () {
      expect(resolved.names, [
        'SRPoint',
        'SRShapes',
        'SRShapesMeta',
        'SRShapesMetaSize',
        'SRShapesStops',
      ]);
      final meta = resolved['SRShapes'].field('meta');
      expect(meta.type, resolved.named('SRShapesMeta'));
      expect(meta.description, 'An inline object.');
      expect(
        resolved['SRShapesMeta'].field('size').type,
        resolved.named('SRShapesMetaSize'),
      );
      // Inline array items are named after the array property.
      expect(
        resolved['SRShapes'].field('stops').type,
        ListType(resolved.named('SRShapesStops')),
      );
    });
  });

  group('allOf', () {
    late Resolved resolved;
    setUp(() => resolved = resolve('wireframe-schema.json'));

    test('merges the properties of every part into one class', () {
      expect(resolved.names, [
        'SRPoint',
        'SRShapeWireframe',
        'SRShapeWireframeStyle',
      ]);
      // Parts first, depth-first, then the schema's own properties.
      expect(resolved['SRShapeWireframe'].fields.map((f) => f.jsonKey), [
        'id',
        'clip',
        'border',
        'style',
        'type',
      ]);
    });

    test('merges the required keys of every part', () {
      final wireframe = resolved['SRShapeWireframe'];
      expect(wireframe.field('id').isRequired, isTrue);
      expect(wireframe.field('type').isRequired, isTrue);
      expect(wireframe.field('clip').isRequired, isFalse);
      expect(wireframe.field('style').isRequired, isFalse);
    });

    test(
      'a redeclared property keeps its position and takes the last schema',
      () {
        final border = resolved['SRShapeWireframe'].field('border');
        expect(border.type, string);
        expect(border.isRequired, isTrue);
        expect(border.description, 'Redeclared: last declaration wins.');
      },
    );

    test('parts do not become types of their own', () {
      expect(resolved.names, isNot(contains('SRCommon')));
      expect(resolved.names, isNot(contains('SRCommonShape')));
    });

    test(
      'strips "Mobile" from titles and names inline parts after the class',
      () {
        expect(
          resolved['SRShapeWireframe'].field('style').type,
          resolved.named('SRShapeWireframeStyle'),
        );
      },
    );
  });

  test('a schema can use itself', () {
    final resolved = resolve('tree-schema.json');
    expect(resolved.names, ['SRTree']);
    expect(
      resolved['SRTree'].field('children').type,
      ListType(resolved.named('SRTree')),
    );
  });

  test('a root file that is only a \$ref resolves to the referenced type', () {
    final resolved = resolve('root-schema.json');
    expect(resolved.root, resolved.named('SRPoint'));
  });

  group('fails on schemas it does not support', () {
    Matcher throwsSchemaException(String message) => throwsA(
      isA<SchemaException>().having((e) => e.message, 'message', message),
    );

    test('a root schema without a title', () {
      expect(
        () => resolve('errors/untitled-root.json'),
        throwsSchemaException('The root schema needs a "title"'),
      );
    });

    test('unknown, list or missing types', () {
      expect(
        () => resolve('errors/unsupported-type.json'),
        throwsSchemaException('Unsupported "type": null'),
      );
      expect(
        () => resolve('errors/type-list.json'),
        throwsSchemaException('Unsupported "type": [string, null]'),
      );
      expect(
        () => resolve('errors/no-type.json'),
        throwsSchemaException('Unsupported "type": null'),
      );
    });

    test('an array without items', () {
      expect(
        () => resolve('errors/array-without-items.json'),
        throwsSchemaException('An array needs "items"'),
      );
    });

    test('"required" that is not a list of strings', () {
      expect(
        () => resolve('errors/required-not-a-list.json'),
        throwsSchemaException('"required" must be a list of strings'),
      );
    });

    for (final keyword in ['enum', 'const', 'oneOf', 'anyOf', 'not']) {
      test('"$keyword"', () {
        expect(
          () => resolve('errors/keyword-$keyword.json'),
          throwsSchemaException('"$keyword" is not supported yet'),
        );
      });
    }
  });
}
