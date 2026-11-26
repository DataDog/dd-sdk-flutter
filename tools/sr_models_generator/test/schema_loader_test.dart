// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:path/path.dart' as p;
import 'package:sr_models_generator/sr_models_generator.dart';
import 'package:test/test.dart';

import 'support/package_root.dart';

void main() {
  late String fixtures;
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

  setUpAll(() async {
    fixtures = p.join(await packageRoot(), 'test', 'fixtures', 'loader');
  });

  setUp(() {
    loader = SchemaLoader(fixtures);
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

    final unreadableFiles = {
      'missing.json': 'not found',
      'invalid.json': 'Invalid JSON',
      'array.json': 'not a JSON object',
    };
    for (final MapEntry(key: file, value: message) in unreadableFiles.entries) {
      test('fails on $file', () {
        expect(() => loader.load(file), throwsSchemaException(message));
      });
    }
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

    // Property of document.json -> where its `$ref` points.
    final references = {
      'local': 'document.json#/definitions/local',
      'escaped': 'document.json#/definitions/a~1b~0c',
      'indexed': 'document.json#/allOf/0',
      'root': 'document.json',
      'remote': 'sibling.json#/definitions/remote',
    };
    for (final MapEntry(key: name, value: location) in references.entries) {
      test('resolves the "$name" reference to $location', () {
        expect(loader.resolveRef(property(name)).location, location);
      });
    }

    test('reads the schema an escaped fragment points to', () {
      expect(loader.resolveRef(property('escaped')).json['title'], 'Escaped');
    });

    test('fails on a node without a \$ref', () {
      expect(
        () => loader.resolveRef(document),
        throwsSchemaException(r'Expected a string "$ref"'),
      );
    });

    // Property of document.json -> why its `$ref` cannot be followed.
    final brokenReferences = {
      'notAString': r'Expected a string "$ref"',
      'missingFile': 'not found',
      'missingPointer': 'points to nothing',
      'outOfRange': 'points to nothing',
      'anchor': 'only JSON pointer fragments',
      'toArray': 'does not point to an object',
    };
    for (final MapEntry(key: name, value: message)
        in brokenReferences.entries) {
      test('fails on the "$name" reference', () {
        expect(
          () => loader.resolveRef(property(name)),
          throwsSchemaException(message),
        );
      });
    }
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

    test('visits every schema of the chain, in order', () {
      final visited = <String>[];
      loader.deref(property('chain'), visit: (n) => visited.add(n.location));
      expect(visited, [
        'document.json#/properties/chain',
        'nested/forward.json',
        'sibling.json',
      ]);
    });

    test('visits a schema without a \$ref once', () {
      final visited = <String>[];
      loader.deref(document, visit: (n) => visited.add(n.location));
      expect(visited, ['document.json']);
    });

    test('stops at the first schema visit throws on', () {
      final visited = <String>[];
      expect(
        () => loader.deref(
          property('chain'),
          visit: (n) {
            visited.add(n.location);
            if (n.location == 'nested/forward.json') throw StateError('stop');
          },
        ),
        throwsStateError,
      );
      expect(visited, [
        'document.json#/properties/chain',
        'nested/forward.json',
      ]);
    });

    final cycles = {
      'cycle-a.json': 'cycle-a.json -> cycle-b.json -> cycle-a.json',
      'self-cycle.json': 'self-cycle.json -> self-cycle.json',
    };
    for (final MapEntry(key: file, value: chain) in cycles.entries) {
      test('fails on the cycle in $file', () {
        expect(
          () => loader.deref(loader.load(file)),
          throwsSchemaException(chain),
        );
      });
    }
  });

  group('mounts', () {
    late SchemaLoader mounted;
    late String local;

    setUp(() {
      local = p.join(p.dirname(fixtures), 'local_loader');
      mounted = SchemaLoader(fixtures, mounts: {'flutter': local});
    });

    SchemaNode envelope(String name) =>
        mounted.load('flutter/envelope.json').child('properties').child(name);

    test('loads a mounted file under its folder', () {
      final node = mounted.load('flutter/envelope.json');
      expect(node.location, 'flutter/envelope.json');
      expect(node.json['title'], 'Envelope');
    });

    // Property of flutter/envelope.json -> where its `$ref` points.
    final references = {
      'document': 'document.json',
      'note': 'flutter/note.json',
      'remote': 'sibling.json#/definitions/remote',
    };
    for (final MapEntry(key: name, value: location) in references.entries) {
      test('resolves the "$name" reference to $location', () {
        expect(mounted.resolveRef(envelope(name)).location, location);
      });
    }

    test('reports the real path of a missing mounted file', () {
      expect(
        () => mounted.load('flutter/missing.json'),
        throwsSchemaException(p.join(local, 'missing.json')),
      );
    });

    test('hides a folder of the root with the same name', () {
      final hiding = SchemaLoader(fixtures, mounts: {'nested': local});
      expect(hiding.load('nested/note.json').json['title'], 'Note');
      expect(
        () => hiding.load('nested/child.json'),
        throwsSchemaException('not found'),
      );
    });

    for (final name in ['', 'a/b', '.', '..']) {
      test('rejects "$name" as a mount', () {
        expect(
          () => SchemaLoader(fixtures, mounts: {name: local}),
          throwsArgumentError,
        );
      });
    }
  });

  group('files outside the schemas', () {
    test('fails on a reference that leaves them', () {
      final mounted = SchemaLoader(
        fixtures,
        mounts: {'flutter': p.join(p.dirname(fixtures), 'local_loader')},
      );
      expect(
        () => mounted.resolveRef(
          mounted
              .load('flutter/envelope.json')
              .child('properties')
              .child('outside'),
        ),
        throwsSchemaException(
          'outside the schemas: flutter/../../outside.json',
        ),
      );
    });

    for (final file in ['../schema_node_test.dart', '/etc/hosts']) {
      test('fails on $file', () {
        expect(
          () => loader.load(file),
          throwsSchemaException('outside the schemas'),
        );
      });
    }
  });
}
