// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:path/path.dart' as p;
import 'package:sr_models_generator/sr_models_generator.dart';
import 'package:test/test.dart';

void main() {
  late SchemaLoader loader;
  late SchemaNode document;

  /// The `$ref` node of `document.json#/properties/<name>`.
  SchemaNode property(String name) => document.child('properties').child(name);

  Matcher throwsSchemaException(String message) => throwsA(
    isA<SchemaException>().having(
      (e) => e.message,
      'message',
      contains(message),
    ),
  );

  setUp(() {
    loader = SchemaLoader(p.join('test', 'fixtures', 'loader'));
    document = loader.load('document.json');
  });

  group('load', () {
    test('returns the root of the file', () {
      expect(document.file, 'document.json');
      expect(document.pointer, isEmpty);
      expect(document.json['title'], 'Document');
    });

    test('reads each file once', () {
      final again = loader.load('./nested/../document.json');
      expect(again.file, 'document.json');
      expect(identical(again.json, document.json), isTrue);
    });

    test('fails on missing, invalid or non-object files', () {
      expect(
        () => loader.load('missing.json'),
        throwsSchemaException('not found'),
      );
      expect(
        () => loader.load('invalid.json'),
        throwsSchemaException('Invalid JSON'),
      );
      expect(
        () => loader.load('array.json'),
        throwsSchemaException('not a JSON object'),
      );
    });
  });

  group('resolveRef', () {
    test('resolves a file next to the current one', () {
      final target = loader.resolveRef(property('sibling'));
      expect(target.location, 'sibling.json');
      expect(target.json['title'], 'Sibling');
    });

    test('resolves paths relative to the current file', () {
      final child = loader.resolveRef(property('nested'));
      expect(child.location, 'nested/child.json');

      // nested/child.json refers to "../sibling.json".
      final up = loader.resolveRef(child.child('properties').child('up'));
      expect(up.location, 'sibling.json');
    });

    test('resolves fragments in the same file', () {
      expect(
        loader.resolveRef(property('local')).location,
        'document.json#/definitions/local',
      );
      expect(loader.resolveRef(property('indexed')).json['title'], 'First');
      expect(loader.resolveRef(property('root')).location, 'document.json');
    });

    test('resolves escaped fragment segments', () {
      final target = loader.resolveRef(property('escaped'));
      expect(target.json['title'], 'Escaped');
    });

    test('resolves fragments in another file', () {
      final target = loader.resolveRef(property('remote'));
      expect(target.location, 'sibling.json#/definitions/remote');
      expect(target.json['title'], 'Remote');
    });

    test('fails on references it cannot follow', () {
      expect(
        () => loader.resolveRef(document),
        throwsSchemaException(r'Expected a string "$ref"'),
      );
      expect(
        () => loader.resolveRef(property('notAString')),
        throwsSchemaException(r'Expected a string "$ref"'),
      );
      expect(
        () => loader.resolveRef(property('missingFile')),
        throwsSchemaException('not found'),
      );
      expect(
        () => loader.resolveRef(property('missingPointer')),
        throwsSchemaException('points to nothing'),
      );
      expect(
        () => loader.resolveRef(property('outOfRange')),
        throwsSchemaException('points to nothing'),
      );
      expect(
        () => loader.resolveRef(property('anchor')),
        throwsSchemaException('only JSON pointer fragments'),
      );
      expect(
        () => loader.resolveRef(property('toArray')),
        throwsSchemaException('does not point to an object'),
      );
    });
  });

  group('deref', () {
    test('returns nodes without a \$ref unchanged', () {
      expect(identical(loader.deref(document), document), isTrue);
    });

    test('follows a chain of references across files', () {
      // chain -> nested/forward.json -> ../sibling.json
      final target = loader.deref(property('chain'));
      expect(target.location, 'sibling.json');
    });

    test('fails on cycles', () {
      expect(
        () => loader.deref(loader.load('cycle-a.json')),
        throwsSchemaException('cycle-a.json -> cycle-b.json -> cycle-a.json'),
      );
      expect(
        () => loader.deref(loader.load('self-cycle.json')),
        throwsSchemaException('Circular'),
      );
    });
  });
}
