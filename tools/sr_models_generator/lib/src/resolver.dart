// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'model.dart';
import 'naming.dart';
import 'schema_loader.dart';
import 'schema_node.dart';

/// How generated types are named.
class NamingOptions {
  const NamingOptions({
    this.typePrefix = 'SR',
    this.stripFromTitles = const ['Mobile'],
  });

  /// Prefix of every generated type name.
  final String typePrefix;

  /// Words removed from schema titles: `MobileSegment` -> `SRSegment`.
  final List<String> stripFromTitles;
}

/// Turns JSON schemas into the [Definition]s to generate.
///
/// Starting from a root schema, every schema it uses is visited once.
///
/// The same schema location always gives the same definition, however
/// many times it is referenced. Validation-only keywords (`pattern`,
/// `minimum`, `minItems`, `readOnly`, ...) are ignored; anything else the
/// resolver does not support makes it throw a [SchemaException].
class ModelResolver {
  ModelResolver(this.loader, {this.naming = const NamingOptions()});

  final SchemaLoader loader;
  final NamingOptions naming;

  /// Definitions by schema location.
  final _definitions = <String, Definition>{};

  /// Every definition found so far, sorted by name.
  List<Definition> get definitions =>
      _definitions.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  /// Resolves the schema in [file] (relative to the loader root) and every
  /// schema it uses. Returns the type of the root schema.
  TypeRef resolveRoot(String file) {
    final root = _unwrap(loader.load(file));
    if (root.title == null) {
      throw SchemaException('The root schema needs a "title"', root);
    }
    return _typeOf(root, owner: '', property: '');
  }

  /// The type of [schema].
  ///
  /// [owner] and [property] tell where the schema is used (e.g. owner
  /// `SRMetaRecord`, property `data`); they name schemas without a title.
  TypeRef _typeOf(
    SchemaNode schema, {
    required String owner,
    required String property,
  }) {
    final node = _unwrap(schema);

    for (final keyword in _notSupportedYet) {
      if (node.has(keyword)) {
        throw SchemaException('"$keyword" is not supported yet', node);
      }
    }
    if (node.has('const')) {
      throw SchemaException(
        '"const" is only supported on object properties',
        node,
      );
    }
    if (node.has('enum')) {
      return NamedType(_enum(node, owner: owner, property: property));
    }
    if (node.has('oneOf')) {
      return NamedType(_union(node, owner: owner, property: property));
    }

    switch (node.json['type']) {
      case 'object':
        return NamedType(_class(node, owner: owner, property: property));
      case 'array':
        if (!node.has('items')) {
          throw SchemaException('An array needs "items"', node);
        }
        return ListType(
          _typeOf(node.child('items'), owner: owner, property: property),
        );
      case 'integer':
        return const PrimitiveType(Primitive.integer);
      case 'number':
        return const PrimitiveType(Primitive.number);
      case 'string':
        return const PrimitiveType(Primitive.string);
      case 'boolean':
        return const PrimitiveType(Primitive.boolean);
      // Some objects only declare their parts, without `"type": "object"`.
      case null when node.has('properties') || node.has('allOf'):
        return NamedType(_class(node, owner: owner, property: property));
      case final type:
        throw SchemaException('Unsupported "type": $type', node);
    }
  }

  static const _notSupportedYet = ['anyOf', 'not'];

  /// Follows `$ref`s and `allOf: [{$ref}]` wrappers to the schema that
  /// defines the type.
  SchemaNode _unwrap(SchemaNode schema) {
    var node = loader.deref(schema);
    while (_isRefWrapper(node)) {
      node = loader.deref(node.children('allOf').single);
    }
    return node;
  }

  bool _isRefWrapper(SchemaNode node) {
    final allOf = node.json['allOf'];
    return allOf is List<Object?> &&
        allOf.length == 1 &&
        allOf.single is JsonMap &&
        (allOf.single as JsonMap).containsKey(r'$ref') &&
        !node.has('properties') &&
        !node.has('required');
  }

  // MARK: - Classes

  ClassDefinition _class(
    SchemaNode node, {
    required String owner,
    required String property,
  }) {
    if (_definitions[node.location] case final ClassDefinition existing) {
      return existing;
    }

    final definition = ClassDefinition(
      name: _typeName(node, owner: owner, property: property),
      location: node.location,
      description: node.description,
    );
    // Registered before its fields are resolved, so that a schema that uses
    // itself finds this definition instead of starting over.
    _definitions[node.location] = definition;

    final object = _flatten(node);
    for (final MapEntry(key: key, value: schema) in object.properties.entries) {
      final target = _unwrap(schema);
      final isRequired = object.required.contains(key);
      final description =
          schema.description ??
          (target.title == null ? target.description : null);

      final isConst = target.has('const');
      if (isConst && !isRequired) {
        throw SchemaException('A "const" property must be required', target);
      }

      definition.fields.add(
        Field(
          jsonKey: key,
          dartName: fieldName(key),
          type: isConst
              ? _constType(target)
              : _typeOf(schema, owner: definition.name, property: key),
          isRequired: isRequired,
          description: description,
          constValue: target.json['const'],
        ),
      );
    }
    return definition;
  }

  /// The type of a `const` property: a string or an integer, matching its
  /// `type`, e.g. `{"type": "string", "const": "shape"}`.
  PrimitiveType _constType(SchemaNode node) =>
      switch ((node.json['type'], node.json['const'])) {
        ('string', String()) => const PrimitiveType(Primitive.string),
        ('integer', int()) => const PrimitiveType(Primitive.integer),
        _ => throw SchemaException(
          'Unsupported "const": only string and integer values, with a '
          'matching "type", are supported',
          node,
        ),
      };

  /// The properties and required keys of [schema] and of all its `allOf`
  /// parts, merged in order: parts first, then the schema's own properties.
  _Object _flatten(SchemaNode schema) {
    final node = loader.deref(schema);
    if (node.has('oneOf')) {
      throw SchemaException('A "oneOf" cannot be merged into an object', node);
    }
    final result = _Object();
    if (node.has('allOf')) {
      for (final part in node.children('allOf')) {
        result.merge(_flatten(part));
      }
    }
    if (node.has('properties')) {
      final properties = node.child('properties');
      for (final key in properties.json.keys) {
        result.properties[key] = properties.child(key);
      }
    }
    result.required.addAll(_required(node));
    return result;
  }

  Set<String> _required(SchemaNode node) {
    final required = node.json['required'];
    if (required == null) return const {};
    if (required is! List<Object?> || required.any((key) => key is! String)) {
      throw SchemaException('"required" must be a list of strings', node);
    }
    return required.cast<String>().toSet();
  }

  // MARK: - Enums

  /// A string enum, e.g. `{"type": "string", "enum": ["clip", "tail"]}`.
  EnumDefinition _enum(
    SchemaNode node, {
    required String owner,
    required String property,
  }) {
    if (_definitions[node.location] case final EnumDefinition existing) {
      return existing;
    }
    if (node.json['type'] != 'string') {
      throw SchemaException('Only string enums are supported', node);
    }
    final values = node.json['enum'];
    if (values is! List<Object?> ||
        values.isEmpty ||
        values.any((value) => value is! String)) {
      throw SchemaException('"enum" must be a non-empty list of strings', node);
    }

    final cases = <String, String>{};
    for (final value in values.cast<String>()) {
      if (cases.containsKey(value)) {
        throw SchemaException('Duplicate enum value "$value"', node);
      }
      final caseName = enumCaseName(value);
      for (final MapEntry(key: other, value: otherCase) in cases.entries) {
        if (otherCase == caseName) {
          throw SchemaException(
            'Enum values "$other" and "$value" both become "$caseName"',
            node,
          );
        }
      }
      cases[value] = caseName;
    }

    final definition = EnumDefinition(
      name: _typeName(node, owner: owner, property: property),
      location: node.location,
      description: node.description,
      values: cases,
    );
    _definitions[node.location] = definition;
    return definition;
  }

  // MARK: - Unions

  /// One of several object schemas (`oneOf`), e.g. the wireframe kinds.
  UnionDefinition _union(
    SchemaNode node, {
    required String owner,
    required String property,
  }) {
    if (_definitions[node.location] case final UnionDefinition existing) {
      return existing;
    }
    if (node.has('properties') || node.has('allOf')) {
      throw SchemaException(
        'A "oneOf" cannot be combined with "properties" or "allOf"',
        node,
      );
    }
    final parts = node.children('oneOf');
    if (parts.isEmpty) {
      throw SchemaException('A "oneOf" needs at least one schema', node);
    }

    final union = UnionDefinition(
      name: _typeName(node, owner: owner, property: property),
      location: node.location,
      description: node.description,
    );
    // Registered before its variants are resolved, so that a variant that
    // uses the union finds this definition instead of starting over.
    _definitions[node.location] = union;

    final variants = [for (final part in parts) _variant(part, union)];
    union.discriminatorKey = _discriminator(variants, node);
    for (final variant in variants) {
      if (variant.constField(union.discriminatorKey) case Field(
        constValue: final Object value,
      )) {
        union.variants[value] = variant;
        variant.unions.add(union);
      }
    }
    return union;
  }

  /// The class of a `oneOf` part, which must be a titled object schema.
  ClassDefinition _variant(SchemaNode part, UnionDefinition union) {
    final node = _unwrap(part);
    if (node.title == null) {
      throw SchemaException('A "oneOf" variant needs a "title"', node);
    }
    if (_typeOf(node, owner: union.name, property: '') case NamedType(
      definition: final ClassDefinition variant,
    )) {
      return variant;
    }
    throw SchemaException('A "oneOf" variant must be an object schema', node);
  }

  /// The key of the property that tells the [variants] apart: the only
  /// `const` property every variant has, with a different value in each.
  String _discriminator(List<ClassDefinition> variants, SchemaNode node) {
    final candidates = [
      for (final field in variants.first.fields)
        if (field.isConst &&
            {
              for (final variant in variants)
                variant.constField(field.jsonKey)?.constValue,
            }.nonNulls.length == variants.length
          )
            field.jsonKey,
    ];
    return switch (candidates) {
      [final key] => key,
      [] => throw SchemaException(
        'Cannot tell the "oneOf" variants apart: no "const" property has a '
        'different value in each of them',
        node,
      ),
      _ => throw SchemaException(
        'Cannot tell the "oneOf" variants apart: several "const" properties '
        'could (${candidates.join(', ')})',
        node,
      ),
    };
  }

  // MARK: - Naming

  String _typeName(
    SchemaNode node, {
    required String owner,
    required String property,
  }) {
    final title = node.title;
    if (title == null) return '$owner${pascalCase(property)}';

    var name = title;
    for (final word in naming.stripFromTitles) {
      name = name.replaceAll(word, '');
    }
    return '${naming.typePrefix}${pascalCase(name)}';
  }
}

/// The merged properties of an object schema.
class _Object {
  /// Property name -> its schema, in declaration order.
  final properties = <String, SchemaNode>{};
  final required = <String>{};

  void merge(_Object other) {
    properties.addAll(other.properties);
    required.addAll(other.required);
  }
}
