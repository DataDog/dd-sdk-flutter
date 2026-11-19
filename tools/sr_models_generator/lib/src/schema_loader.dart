// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'schema_node.dart';

/// Reads schema files from a directory and resolves `$ref`s between them.
///
/// Files are identified by posix paths relative to [rootDirectory], so
/// locations are the same on every platform.
final class SchemaLoader {
  SchemaLoader(this.rootDirectory);

  final String rootDirectory;

  /// Parsed files, so that each file is read once and the same file always
  /// yields the same [JsonMap] instance.
  final _files = <String, JsonMap>{};

  /// Loads [file] (relative to [rootDirectory]) and returns its root schema.
  SchemaNode load(String file) {
    final path = p.posix.normalize(file);
    final json = _files.putIfAbsent(path, () => _read(path));
    return SchemaNode(path, '', json);
  }

  JsonMap _read(String path) {
    final file = File(p.joinAll([rootDirectory, ...p.posix.split(path)]));
    if (!file.existsSync()) {
      throw SchemaException('Schema file not found: ${file.path}');
    }
    final Object? json;
    try {
      json = jsonDecode(file.readAsStringSync());
    } on FormatException catch (e) {
      throw SchemaException('Invalid JSON in ${file.path}: ${e.message}');
    }
    if (json is! JsonMap) {
      throw SchemaException('Schema file is not a JSON object: ${file.path}');
    }
    return json;
  }

  /// Returns the schema that the `$ref` of [node] points to.
  ///
  /// Supports the reference forms used by rum-events-format.
  SchemaNode resolveRef(SchemaNode node) {
    final ref = node.json[r'$ref'];
    if (ref is! String) {
      throw SchemaException(r'Expected a string "$ref"', node);
    }

    final hash = ref.indexOf('#');
    final filePart = hash < 0 ? ref : ref.substring(0, hash);
    final fragment = hash < 0 ? '' : ref.substring(hash + 1);

    final file = filePart.isEmpty
        ? node.file
        : p.posix.join(p.posix.dirname(node.file), filePart);
    return _resolvePointer(load(file), fragment, ref: ref, from: node);
  }

  /// Follows `$ref`s from [node] until reaching a schema without one.
  ///
  /// Throws if the chain loops back on itself.
  SchemaNode deref(SchemaNode node) {
    final visited = <String>{};
    var current = node;
    while (current.has(r'$ref')) {
      if (!visited.add(current.location)) {
        throw SchemaException(
          'Circular \$ref: ${[...visited, current.location].join(' -> ')}',
          node,
        );
      }
      current = resolveRef(current);
    }
    return current;
  }

  /// Walks the JSON [pointer] from [root].
  /// An empty pointer is the root itself.
  SchemaNode _resolvePointer(
    SchemaNode root,
    String pointer, {
    required String ref,
    required SchemaNode from,
  }) {
    if (pointer.isEmpty) return root;
    if (!pointer.startsWith('/')) {
      throw SchemaException(
        'Unsupported \$ref "$ref": only JSON pointer fragments (#/...) '
        'are supported',
        from,
      );
    }

    Object? current = root.json;
    for (final segment in pointer.substring(1).split('/')) {
      final key = unescapePointerSegment(segment);
      final index = int.tryParse(key);
      if (current is JsonMap && current.containsKey(key)) {
        current = current[key];
      } else if (current is List<Object?> &&
          index != null &&
          index >= 0 &&
          index < current.length) {
        current = current[index];
      } else {
        throw SchemaException(
          '\$ref "$ref" points to nothing (no "$key" in ${root.file})',
          from,
        );
      }
    }
    if (current is! JsonMap) {
      throw SchemaException('\$ref "$ref" does not point to an object', from);
    }
    return SchemaNode(root.file, pointer, current);
  }
}
