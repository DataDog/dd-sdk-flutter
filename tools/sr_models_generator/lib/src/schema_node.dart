// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

typedef JsonMap = Map<String, Object?>;

/// A JSON Schema object together with where it was found.
///
/// The location ([file] + [pointer]) identifies a schema: two nodes with the
/// same location are the same schema, however they were reached.
class SchemaNode {
  SchemaNode(this.file, this.pointer, this.json);

  final String file;
  final String pointer;
  final JsonMap json;

  String get location => pointer.isEmpty ? file : '$file#$pointer';

  bool has(String key) => json.containsKey(key);

  /// The schema object under [key] (e.g. `child('items')`).
  SchemaNode child(String key) {
    final value = json[key];
    if (value is! JsonMap) {
      throw SchemaException('Expected an object at "$key"', this);
    }
    return SchemaNode(file, '$pointer/${escapePointerSegment(key)}', value);
  }

  /// The schema objects in the array under [key] (e.g. `children('allOf')`).
  List<SchemaNode> children(String key) {
    final value = json[key];
    if (value is! List<Object?>) {
      throw SchemaException('Expected an array at "$key"', this);
    }
    return [
      for (var i = 0; i < value.length; i++)
        switch (value[i]) {
          final JsonMap item => SchemaNode(
            file,
            '$pointer/${escapePointerSegment(key)}/$i',
            item,
          ),
          _ => throw SchemaException('Expected an object at "$key/$i"', this),
        },
    ];
  }

  @override
  String toString() => location;
}

String escapePointerSegment(String key) =>
    key.replaceAll('~', '~0').replaceAll('/', '~1');

/// Reverses [escapePointerSegment]
String unescapePointerSegment(String segment) =>
    segment.replaceAll('~1', '/').replaceAll('~0', '~');

/// A schema the generator cannot read or does not support.
class SchemaException implements Exception {
  SchemaException(this.message, [this.node]);

  final String message;

  /// The schema the problem was found in, when known.
  final SchemaNode? node;

  @override
  String toString() =>
      node == null ? message : '$message (at ${node!.location})';
}
