// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

/// The types to generate: produced by the resolver from the JSON schemas and
/// turned into Dart code by the printer.
///
/// Nothing here knows about JSON Schema keywords (`$ref`, `allOf`, ...) or
/// about Dart syntax; it only describes types and their fields.
library;

import 'package:meta/meta.dart';

/// The type of a [Field] (or of the items of a [ListType]).
@immutable
sealed class TypeRef {
  const TypeRef();
}

/// The JSON value types that map to built-in Dart types.
enum Primitive {
  /// JSON Schema `integer`.
  integer,

  /// JSON Schema `number` (integer or decimal).
  number,

  /// JSON Schema `string`.
  string,

  /// JSON Schema `boolean`.
  boolean,
}

/// A built-in type, such as an integer or a string.
/// Basic JSON value
final class PrimitiveType extends TypeRef {
  const PrimitiveType(this.primitive);

  final Primitive primitive;

  @override
  bool operator ==(Object other) =>
      other is PrimitiveType && other.primitive == primitive;

  @override
  int get hashCode => primitive.hashCode;

  @override
  String toString() => primitive.name;
}

/// A JSON array whose items are all of type [item].
final class ListType extends TypeRef {
  const ListType(this.item);

  final TypeRef item;

  @override
  bool operator ==(Object other) => other is ListType && other.item == item;

  @override
  int get hashCode => Object.hash(ListType, item);

  @override
  String toString() => 'List<$item>';
}

/// A generated type, such as `SRShapeWireframe`.
final class NamedType extends TypeRef {
  const NamedType(this.definition);

  final Definition definition;

  @override
  bool operator ==(Object other) =>
      other is NamedType && identical(other.definition, definition);

  @override
  int get hashCode => identityHashCode(definition);

  @override
  String toString() => definition.name;
}

/// A generated top-level type.
sealed class Definition {
  Definition({
    required this.name,
    required this.location,
    required this.description,
  });

  /// The Dart type name, e.g. `SRShapeWireframe`.
  final String name;

  /// Location of the schema this was generated from
  final String location;

  /// The schema `description`, if any; becomes the documentation comment.
  final String? description;

  @override
  String toString() => name;
}

/// A property of a [ClassDefinition].
@immutable
final class Field {
  Field({
    required this.jsonKey,
    required this.dartName,
    required this.type,
    required this.isRequired,
    required this.description,
    this.constValue,
  }) : assert(
         constValue == null || isRequired,
         'A const field always has its value, so it is required',
       );

  /// The key in JSON, e.g. `records_count`.
  final String jsonKey;

  /// The Dart member name, e.g. `recordsCount`.
  final String dartName;

  final TypeRef type;

  /// Whether the key is always present; optional fields are nullable.
  final bool isRequired;

  final String? description;

  /// The only value the schema allows (`const`), e.g. `'shape'` for the
  /// `type` of a shape wireframe.
  final Object? constValue;

  bool get isConst => constValue != null;

  @override
  String toString() => '$jsonKey: $type${isRequired ? '' : '?'}';
}

/// A JSON object, e.g. `SRShapeWireframe`.
final class ClassDefinition extends Definition {
  ClassDefinition({
    required super.name,
    required super.location,
    required super.description,
  });

  /// The properties, in schema order.
  final List<Field> fields = [];

  /// The unions this class is "oneOf" the variants of, e.g. `SRWireframe`
  /// for `SRShapeWireframe`.
  final List<UnionDefinition> unions = [];

  /// The const field with [jsonKey], if any.
  Field? constField(String jsonKey) =>
      fields.where((f) => f.isConst && f.jsonKey == jsonKey).firstOrNull;
}

/// One of several kinds of object (`oneOf`), e.g. `SRWireframe`.
final class UnionDefinition extends Definition {
  UnionDefinition({
    required super.name,
    required super.location,
    required super.description,
  });

  /// The JSON key of the discriminator, e.g. `type` or `source`.
  late final String discriminatorKey;

  /// Discriminator value -> the variant with that value, e.g.
  /// `'shape' -> SRShapeWireframe`.
  final Map<Object, ClassDefinition> variants = {};

  /// The fields every variant has, with the same name, type and
  /// requiredness, in the order of the first variant.
  ///
  /// The union exposes them directly (e.g. `wireframe.id`), so callers only
  /// need to check the kind for the fields that differ. The discriminator is
  /// always one of them.
  List<Field> get sharedFields {
    final classes = variants.values.toList();
    if (classes.isEmpty) return const [];
    return [
      for (final field in classes.first.fields)
        if (classes.every(
          (c) => c.fields.any(
            (f) =>
                f.jsonKey == field.jsonKey &&
                f.dartName == field.dartName &&
                f.type == field.type &&
                f.isRequired == field.isRequired &&
                f.isConst == field.isConst,
          ),
        ))
          field,
    ];
  }
}

/// A string with a fixed set of values (`enum`), e.g.
/// `SRTextStyleTruncationMode`.
final class EnumDefinition extends Definition {
  EnumDefinition({
    required super.name,
    required super.location,
    required super.description,
    required this.values,
  });

  /// JSON value -> Dart case name, in schema order, e.g.
  /// `'react-native' -> 'reactNative'`.
  final Map<String, String> values;
}
