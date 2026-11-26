// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:path/path.dart' as p;
import 'package:sr_models_generator/sr_models_generator.dart';
import 'package:test/test.dart';

import 'support/package_root.dart';

/// The result of resolving one fixture.
class Resolved {
  Resolved(this.root, List<Definition> definitions)
    : names = [for (final d in definitions) d.name],
      _byName = {for (final d in definitions) d.name: d};

  final TypeRef root;

  /// Names of all definitions, in the order the resolver returns them.
  final List<String> names;
  final Map<String, Definition> _byName;

  ClassDefinition operator [](String name) => _definition(name);

  EnumDefinition enumeration(String name) => _definition(name);

  UnionDefinition union(String name) => _definition(name);

  NamedType named(String name) => NamedType(_definition(name));

  T _definition<T extends Definition>(String name) => switch (_byName[name]) {
    final T definition => definition,
    final other => throw StateError('No $T named $name (found $other)'),
  };
}

extension on ClassDefinition {
  Field field(String jsonKey) =>
      fields.singleWhere((f) => f.jsonKey == jsonKey);
}

void main() {
  const integer = PrimitiveType(Primitive.integer);
  const number = PrimitiveType(Primitive.number);
  const string = PrimitiveType(Primitive.string);
  const boolean = PrimitiveType(Primitive.boolean);

  late String fixtures;
  setUpAll(() async {
    fixtures = p.join(await packageRoot(), 'test', 'fixtures', 'resolver');
  });

  Resolved resolve(
    String file, {
    NamingOptions naming = const NamingOptions(),
  }) {
    final resolver = ModelResolver(SchemaLoader(fixtures), naming: naming);
    final [root] = resolver.resolveRoots([file]);
    return Resolved(root, resolver.definitions);
  }

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

    test('strips only a prefix from titles', () {
      final names = resolve(
        'wireframe-schema.json',
        naming: const NamingOptions(stripFromTitles: ['Wireframe']),
      ).names;
      expect(names, contains('SRMobileShapeWireframe'));
    });
  });

  group('a union used by one of its variants', () {
    // `children` (the union) comes before `type` (the discriminator), so
    // the union is reached while Branch is only partly resolved.
    for (final root in ['branch-schema.json', 'tree-node-schema.json']) {
      test('resolves from $root', () {
        final resolved = resolve(root);
        final node = resolved.union('SRTreeNode');
        expect(node.discriminatorKey, 'type');
        expect(node.variants, {
          'branch': resolved['SRBranch'],
          'leaf': resolved['SRLeaf'],
        });
        expect(
          resolved['SRBranch'].field('children').type,
          ListType(resolved.named('SRTreeNode')),
        );
      });
    }
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

  group('local schemas', () {
    // flutter/ is test/fixtures/local_resolver, whose schemas refer to
    // the resolver fixtures.
    ModelResolver mounted({NamingOptions naming = const NamingOptions()}) =>
        ModelResolver(
          SchemaLoader(
            fixtures,
            mounts: {'flutter': p.join(p.dirname(fixtures), 'local_resolver')},
          ),
          naming: naming,
        );

    test('use the types of the schemas they refer to', () {
      final resolver = mounted();
      final [_, root] = resolver.resolveRoots([
        'point-schema.json',
        'flutter/envelope-schema.json',
      ]);
      final resolved = Resolved(root, resolver.definitions);

      expect(resolved.root, resolved.named('SREnvelope'));
      expect(resolved['SREnvelope'].location, 'flutter/envelope-schema.json');
      expect(
        resolved['SREnvelope'].field('point').type,
        resolved.named('SRPoint'),
      );
      expect(
        resolved['SREnvelope'].field('shapes').type,
        ListType(resolved.named('SRShape')),
      );
      // The same schema, reached from a root and from a local schema.
      expect(resolved.names.where((name) => name == 'SRPoint'), hasLength(1));
    });

    test('can be renamed when they are not the first root', () {
      final resolver = mounted(
        naming: const NamingOptions(renames: {'SREnvelope': 'SRWrapper'}),
      );
      final [_, root] = resolver.resolveRoots([
        'point-schema.json',
        'flutter/envelope-schema.json',
      ]);
      final resolved = Resolved(root, resolver.definitions);

      expect(resolved.root, resolved.named('SRWrapper'));
      expect(resolved.names, isNot(contains('SREnvelope')));
    });

    test('have their keywords checked', () {
      expect(
        () => mounted().resolveRoots(['flutter/bad-schema.json']),
        throwsA(
          isA<SchemaException>()
              .having(
                (e) => e.message,
                'message',
                'Unsupported keyword "patternProperties"',
              )
              .having(
                (e) => e.node?.location,
                'location',
                'flutter/bad-schema.json#/properties/value',
              ),
        ),
      );
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

    final unsupportedTypes = {
      'unsupported-type.json': 'Unsupported "type": null',
      'type-list.json': 'Unsupported "type": [string, null]',
      'no-type.json': 'Unsupported "type": null',
    };
    for (final MapEntry(key: file, value: message)
        in unsupportedTypes.entries) {
      test(file, () {
        expect(() => resolve('errors/$file'), throwsSchemaException(message));
      });
    }

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

    final unsupportedKeywords = {
      'keyword-anyOf.json': 'anyOf',
      'keyword-not.json': 'not',
      'unknown-keyword.json': 'patternProperties',
      'misspelled-keyword.json': 'requird',
      'keyword-next-to-ref.json': 'default',
      'keyword-in-all-of-part.json': 'dependencies',
      'additional-properties-true.json': 'additionalProperties',
      'additional-properties-schema.json': 'additionalProperties',
      'keyword-in-ref-wrapper.json': 'not',
      'keyword-in-ref-chain.json': 'anyOf',
    };
    for (final MapEntry(key: file, value: keyword)
        in unsupportedKeywords.entries) {
      test(file, () {
        expect(
          () => resolve('errors/$file'),
          throwsSchemaException('Unsupported keyword "$keyword"'),
        );
      });
    }

    test('"additionalProperties": false, which needs nothing generated', () {
      expect(() => resolve('primitives-schema.json'), returnsNormally);
    });
  });

  group('one type per schema location', () {
    test('however the path to the schema is spelled', () {
      final resolved = resolve('shapes-schema.json');
      expect(
        resolved['SRShapes'].field('alias').type,
        resolved.named('SRPoint'),
      );
      expect(resolved.names.where((n) => n == 'SRPoint'), hasLength(1));
    });

    final cycles = {
      'circular-ref.json':
          r'Circular $ref: errors/circular-ref.json#/properties/value -> '
          'errors/circular-ref.json#/definitions/a -> '
          'errors/circular-ref.json#/definitions/b -> '
          'errors/circular-ref.json#/definitions/a',
      'circular-wrapper.json':
          'Circular "allOf": errors/circular-wrapper.json -> '
          'errors/circular-wrapper.json',
      'circular-all-of.json':
          'Circular "allOf": errors/circular-all-of.json -> '
          'errors/circular-all-of.json',
    };
    for (final MapEntry(key: file, value: message) in cycles.entries) {
      test('fails on $file instead of looping', () {
        expect(
          () => resolve('errors/$file'),
          throwsA(
            isA<SchemaException>().having((e) => e.message, 'message', message),
          ),
        );
      });
    }

    final clashes = {
      'name-clash.json':
          'Two schemas produce the type "SRSame": '
          'errors/name-clash.json#/properties/first and '
          'errors/name-clash.json#/properties/second; rename one of them by '
          'its location in "type_renames"',
      'name-clash-inline.json':
          'Two schemas produce the type "SRBadValue": '
          'errors/name-clash-inline.json#/properties/value and '
          'errors/name-clash-inline.json#/properties/other; rename one of '
          'them by its location in "type_renames"',
    };
    for (final MapEntry(key: file, value: message) in clashes.entries) {
      test('fails when two schemas produce the same name ($file)', () {
        expect(
          () => resolve('errors/$file'),
          throwsA(
            isA<SchemaException>().having((e) => e.message, 'message', message),
          ),
        );
      });
    }
  });

  group('renames', () {
    test('rename a titled type and every reference to it', () {
      final resolved = resolve(
        'wireframe-schema.json',
        naming: const NamingOptions(renames: {'SRPoint': 'SRAnchor'}),
      );
      expect(resolved.names, [
        'SRAnchor',
        'SRShapeWireframe',
        'SRShapeWireframeStyle',
      ]);
      expect(
        resolved['SRShapeWireframe'].field('clip').type,
        resolved.named('SRAnchor'),
      );
    });

    test('rename an inline type, and the inline types named after it', () {
      final resolved = resolve(
        'shapes-schema.json',
        naming: const NamingOptions(renames: {'SRShapesMeta': 'SRMeta'}),
      );
      expect(resolved.names, containsAll(['SRMeta', 'SRMetaSize']));
      expect(resolved.names, isNot(contains('SRShapesMeta')));
    });

    test('rename a single schema by its location', () {
      final resolved = resolve(
        'errors/name-clash.json',
        naming: const NamingOptions(
          renames: {'errors/name-clash.json#/properties/second': 'SRSecond'},
        ),
      );
      expect(resolved.names, ['SRBad', 'SRSame', 'SRSecond']);
    });

    test('a location rename wins over a name rename', () {
      final resolved = resolve(
        'errors/name-clash.json',
        naming: const NamingOptions(
          renames: {
            'SRSame': 'SRFirst',
            'errors/name-clash.json#/properties/second': 'SRSecond',
          },
        ),
      );
      expect(resolved.names, ['SRBad', 'SRFirst', 'SRSecond']);
    });

    test('fails when a rename produces a name that is already taken', () {
      expect(
        () => resolve(
          'wireframe-schema.json',
          naming: const NamingOptions(renames: {'SRPoint': 'SRShapeWireframe'}),
        ),
        throwsA(
          isA<SchemaException>().having(
            (e) => e.message,
            'message',
            startsWith('Two schemas produce the type "SRShapeWireframe"'),
          ),
        ),
      );
    });

    test('fails on renames that match no schema', () {
      expect(
        () => resolve(
          'primitives-schema.json',
          naming: const NamingOptions(
            renames: {'SRMissing': 'SRA', 'missing.json': 'SRB'},
          ),
        ),
        throwsA(
          isA<SchemaException>().having(
            (e) => e.message,
            'message',
            'Renames that match no generated type: SRMissing, missing.json',
          ),
        ),
      );
    });
  });
}
