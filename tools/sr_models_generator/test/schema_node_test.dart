// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:sr_models_generator/sr_models_generator.dart';
import 'package:test/test.dart';

void main() {
  final root = SchemaNode('schemas/thing.json', '', {
    'title': 'Thing',
    'allOf': [
      {'title': 'A'},
      {'title': 'B'},
    ],
    'properties': {
      'a/b': {'type': 'string'},
    },
    'mixed': [
      {'title': 'ok'},
      'not an object',
    ],
  });

  test('location is the file for a root node, file#pointer otherwise', () {
    expect(root.location, 'schemas/thing.json');
    expect(root.child('properties').location, 'schemas/thing.json#/properties');
  });

  test('child() extends the pointer and escapes the key', () {
    final property = root.child('properties').child('a/b');
    expect(property.pointer, '/properties/a~1b');
    expect(property.json, {'type': 'string'});
    expect(property.file, root.file);
  });

  test('children() returns one node per array item, indexed', () {
    final parts = root.children('allOf');
    expect(parts.map((n) => n.pointer), ['/allOf/0', '/allOf/1']);
    expect(parts.map((n) => n.json['title']), ['A', 'B']);
  });

  test('child() and children() reject values of the wrong type', () {
    expect(() => root.child('title'), throwsA(isA<SchemaException>()));
    expect(() => root.child('missing'), throwsA(isA<SchemaException>()));
    expect(() => root.children('properties'), throwsA(isA<SchemaException>()));
    expect(() => root.children('mixed'), throwsA(isA<SchemaException>()));
  });

  test('pointer segments escape ~ and / and round-trip', () {
    expect(escapePointerSegment('a/b~c'), 'a~1b~0c');
    expect(unescapePointerSegment('a~1b~0c'), 'a/b~c');
    // ~01 is an escaped "~" followed by "1", not an escaped "/".
    expect(unescapePointerSegment('~01'), '~1');
  });

  test('SchemaException mentions the location when known', () {
    expect(SchemaException('Boom').toString(), 'Boom');
    expect(
      SchemaException('Boom', root).toString(),
      'Boom (at schemas/thing.json)',
    );
  });
}
