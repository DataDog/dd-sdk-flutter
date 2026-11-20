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

  final wrongShapes = {
    'child("title"), a string': () => root.child('title'),
    'child("missing"), absent': () => root.child('missing'),
    'children("properties"), an object': () => root.children('properties'),
    'children("mixed"), with a non-object item': () => root.children('mixed'),
  };
  for (final MapEntry(key: call, value: read) in wrongShapes.entries) {
    test('$call fails', () {
      expect(read, throwsA(isA<SchemaException>()));
    });
  }

  // Key -> its JSON pointer segment.
  final escapes = {'a/b~c': 'a~1b~0c', '~1': '~01', 'plain': 'plain'};
  for (final MapEntry(key: key, value: segment) in escapes.entries) {
    test('the pointer segment of "$key" is "$segment", and back', () {
      expect(escapePointerSegment(key), segment);
      expect(unescapePointerSegment(segment), key);
    });
  }

  test('title and description are read when present', () {
    expect(root.title, 'Thing');
    expect(root.description, isNull);
    expect(
      SchemaNode('x.json', '', {'description': 'Some thing.'}).description,
      'Some thing.',
    );
  });

  final node = SchemaNode('x.json', '', {'title': 1, 'description': true});
  final notStrings = {
    'title': () => node.title,
    'description': () => node.description,
  };
  for (final MapEntry(key: keyword, value: read) in notStrings.entries) {
    test('$keyword must be a string', () {
      expect(read, throwsA(isA<SchemaException>()));
    });
  }

  test('SchemaException mentions the location when known', () {
    expect(SchemaException('Boom').toString(), 'Boom');
    expect(
      SchemaException('Boom', root).toString(),
      'Boom (at schemas/thing.json)',
    );
  });
}
