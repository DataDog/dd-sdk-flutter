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

  EnumDefinition enumeration(String name) => _byName[name]! as EnumDefinition;

  UnionDefinition union(String name) => _byName[name]! as UnionDefinition;

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

  group('enums', () {
    late Resolved resolved;
    setUp(() => resolved = resolve('text-schema.json'));

    test('a string enum becomes an enum definition', () {
      final truncationMode = resolved['SRText'].field('truncation_mode');
      expect(truncationMode.type, resolved.named('SRTextTruncationMode'));
      expect(truncationMode.isRequired, isTrue);
      expect(truncationMode.description, 'How text is truncated.');
      expect(resolved.enumeration('SRTextTruncationMode').values, {
        'clip': 'clip',
        'head': 'head',
        'tail': 'tail',
        'middle': 'middle',
      });
    });

    test('maps values to Dart case names, in schema order', () {
      final platform = resolved.enumeration('SRPlatform');
      expect(platform.values, {
        'ios': 'ios',
        'react-native': 'reactNative',
        'kotlin-multiplatform': 'kotlinMultiplatform',
        'values': 'valuesValue',
      });
      expect(platform.description, 'The platform.');
      expect(platform.location, 'platform-schema.json');
    });

    test('a titled enum referenced twice is one definition', () {
      final text = resolved['SRText'];
      expect(text.field('platform').type, resolved.named('SRPlatform'));
      expect(
        text.field('fallback_platform').type,
        resolved.named('SRPlatform'),
      );
      expect(text.field('fallback_platform').isRequired, isFalse);
    });

    test('enum array items are named after the array property', () {
      expect(
        resolved['SRText'].field('alignments').type,
        ListType(resolved.named('SRTextAlignments')),
      );
      expect(resolved.enumeration('SRTextAlignments').values.keys, [
        'left',
        'right',
      ]);
    });

    test('lists every enum among the definitions', () {
      expect(resolved.names, [
        'SRPlatform',
        'SRText',
        'SRTextAlignments',
        'SRTextTruncationMode',
      ]);
    });
  });

  group('const', () {
    late Resolved resolved;
    setUp(() => resolved = resolve('text-schema.json'));

    test('a string const is a required string field with a fixed value', () {
      final type = resolved['SRText'].field('type');
      expect(type.type, string);
      expect(type.isRequired, isTrue);
      expect(type.isConst, isTrue);
      expect(type.constValue, 'text');
      expect(type.description, 'The kind of element.');
    });

    test('an integer const keeps its value, including 0', () {
      final version = resolved['SRText'].field('version');
      expect(version.type, integer);
      expect(version.constValue, 0);
      expect(version.isConst, isTrue);
    });

    test('other fields are not const', () {
      expect(resolved['SRText'].field('platform').isConst, isFalse);
    });
  });

  group('unions', () {
    late Resolved resolved;
    setUp(() => resolved = resolve('drawing-schema.json'));

    test('a oneOf becomes a union of its variant classes', () {
      final shape = resolved.union('SRShape');
      expect(shape.description, 'A shape.');
      expect(shape.location, 'shape-schema.json');
      expect(shape.variants, {
        'circle': resolved['SRCircle'],
        'square': resolved['SRSquare'],
      });
    });

    test(
      'the discriminator is the const property with a value per variant',
      () {
        expect(resolved.union('SRShape').discriminatorKey, 'type');
      },
    );

    test('integer discriminators keep their values', () {
      final event = resolved.union('SREvent');
      expect(event.discriminatorKey, 'source');
      expect(event.variants, {
        2: resolved['SRTapEvent'],
        3: resolved['SRScrollEvent'],
      });
    });

    test('a union can have a single variant', () {
      final gradient = resolved.union('SRGradient');
      expect(gradient.discriminatorKey, 'type');
      expect(gradient.variants, {'linear': resolved['SRLinearGradient']});
    });

    test('each variant knows the unions it belongs to', () {
      expect(resolved['SRCircle'].unions, [resolved.union('SRShape')]);
      expect(resolved['SRTapEvent'].unions, [resolved.union('SREvent')]);
    });

    test('fields shared by every variant are shared by the union', () {
      // `label` is in both variants, but with different types.
      expect(resolved.union('SRShape').sharedFields.map((f) => f.jsonKey), [
        'id',
        'clip',
        'type',
      ]);
      expect(resolved.union('SREvent').sharedFields.map((f) => f.jsonKey), [
        'source',
      ]);
    });

    test('fields can be unions, or lists of them', () {
      final drawing = resolved['SRDrawing'];
      expect(drawing.field('shapes').type, ListType(resolved.named('SRShape')));
      expect(drawing.field('main').type, resolved.named('SRShape'));
      expect(drawing.field('events').type, ListType(resolved.named('SREvent')));
    });

    test('allOf around a single \$ref to a union is that union', () {
      final background = resolved['SRDrawing'].field('background');
      expect(background.type, resolved.named('SRShape'));
      expect(background.description, 'A wrapped union reference.');
    });

    test('a union referenced several times is one definition', () {
      expect(resolved.names, [
        'SRCircle',
        'SRDrawing',
        'SREvent',
        'SRGradient',
        'SRLinearGradient',
        'SRPoint',
        'SRScrollEvent',
        'SRShape',
        'SRSquare',
        'SRTapEvent',
      ]);
    });
  });

  group('fails on schemas it does not support', () {
    Matcher throwsSchemaException(String message) => throwsA(
      isA<SchemaException>().having((e) => e.message, 'message', message),
    );

    final invalidEnumsAndConsts = {
      'enum-not-string-type.json': 'Only string enums are supported',
      'enum-non-string-values.json':
          '"enum" must be a non-empty list of strings',
      'enum-empty.json': '"enum" must be a non-empty list of strings',
      'enum-not-a-list.json': '"enum" must be a non-empty list of strings',
      'enum-duplicate.json': 'Duplicate enum value "a"',
      'enum-case-collision.json':
          'Enum values "react-native" and "react_native" both become '
          '"reactNative"',
      'const-optional.json': 'A "const" property must be required',
      'const-type-mismatch.json':
          'Unsupported "const": only string and integer values, with a '
          'matching "type", are supported',
      'const-boolean.json':
          'Unsupported "const": only string and integer values, with a '
          'matching "type", are supported',
      'const-outside-property.json':
          '"const" is only supported on object properties',
      'one-of-empty.json': 'A "oneOf" needs at least one schema',
      'one-of-no-discriminator.json':
          'Cannot tell the "oneOf" variants apart: no "const" property has a '
          'different value in each of them',
      'one-of-same-value.json':
          'Cannot tell the "oneOf" variants apart: no "const" property has a '
          'different value in each of them',
      'one-of-missing-in-one.json':
          'Cannot tell the "oneOf" variants apart: no "const" property has a '
          'different value in each of them',
      'one-of-ambiguous.json':
          'Cannot tell the "oneOf" variants apart: several "const" properties '
          'could (type, kind)',
      'one-of-primitive-variant.json':
          'A "oneOf" variant must be an object schema',
      'one-of-untitled-variant.json': 'A "oneOf" variant needs a "title"',
      'one-of-nested.json': 'A "oneOf" variant must be an object schema',
      'one-of-in-all-of.json': 'A "oneOf" cannot be merged into an object',
      'one-of-with-properties.json':
          'A "oneOf" cannot be combined with "properties" or "allOf"',
    };
    for (final MapEntry(key: file, value: message)
        in invalidEnumsAndConsts.entries) {
      test(file, () {
        expect(() => resolve('errors/$file'), throwsSchemaException(message));
      });
    }

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

    for (final keyword in ['anyOf', 'not']) {
      test('"$keyword"', () {
        expect(
          () => resolve('errors/keyword-$keyword.json'),
          throwsSchemaException('"$keyword" is not supported yet'),
        );
      });
    }
  });
}
