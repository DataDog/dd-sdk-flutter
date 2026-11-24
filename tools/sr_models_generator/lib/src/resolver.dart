// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:meta/meta.dart';

import 'model.dart';
import 'naming.dart';
import 'schema_loader.dart';
import 'schema_node.dart';

/// How generated types are named.
@immutable
final class NamingOptions {
  const NamingOptions({
    this.typePrefix = 'SR',
    this.stripFromTitles = const ['Mobile'],
    this.renames = const {},
  });

  /// Prefix of every generated type name.
  final String typePrefix;

  /// Prefixes removed from schema titles: `MobileSegment` -> `SRSegment`.
  final List<String> stripFromTitles;

  /// The name to use instead, e.g. `SRWireframeClip -> SRContentClip`.
  final Map<String, String> renames;
}

/// Turns JSON schemas into the [Definition]s to generate.
///
/// Starting from a root schema, every schema it uses is visited once.
///
/// The same schema location always gives the same definition, however
/// many times it is referenced, and two locations never give the same type
/// name. Validation-only keywords (`pattern`, `minimum`, `minItems`,
/// `readOnly`, ...) are ignored; any other keyword the resolver does not
/// support makes it throw a [SchemaException].
final class ModelResolver {
  ModelResolver(this.loader, {this.naming = const NamingOptions()});

  final SchemaLoader loader;
  final NamingOptions naming;

  /// Definitions by schema location.
  final _definitions = <String, Definition>{};

  /// Definitions by name, to detect two locations with the same name.
  final _definitionsByName = <String, Definition>{};

  /// Unions whose discriminator is picked once every schema is resolved.
  final _unfinishedUnions =
      <(UnionDefinition, List<ClassDefinition>, SchemaNode)>[];

  /// Keys of [NamingOptions.renames] that matched a schema.
  final _appliedRenames = <String>{};

  /// Every definition found so far, sorted by name.
  List<Definition> get definitions =>
      _definitions.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  /// Resolves the schemas in [files] (relative to the loader root) and
  /// every schema they use. Returns the types of the root schemas, in the
  /// order of [files].
  List<TypeRef> resolveRoots(List<String> files) {
    final types = <TypeRef>[];
    for (final file in files) {
      final root = _unwrap(loader.load(file));
      if (root.title == null) {
        throw SchemaException('The root schema needs a "title"', root);
      }
      types.add(_typeOf(root, owner: '', property: ''));
    }

    // Every variant now has all its fields, including variants that use
    // their own union before declaring their discriminator.
    for (final (union, variants, node) in _unfinishedUnions) {
      _finishUnion(union, variants, node);
    }
    _unfinishedUnions.clear();

    // A rename that matches nothing is most likely stale after a schema
    // change, and would silently stop applying. Checked once every root is
    // resolved, as any of them can use it.
    final unusedRenames = [
      for (final name in naming.renames.keys)
        if (!_appliedRenames.contains(name)) name,
    ];
    if (unusedRenames.isNotEmpty) {
      throw SchemaException(
        'Renames that match no generated type: ${unusedRenames.join(', ')}',
      );
    }
    return types;
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

  /// Follows `$ref`s and `allOf: [{$ref}]` wrappers to the schema that
  /// defines the type.
  SchemaNode _unwrap(SchemaNode schema) {
    final wrappers = <String>{};
    var node = loader.deref(schema, visit: _checkKeywords);
    while (_isRefWrapper(node)) {
      if (!wrappers.add(node.location)) {
        throw SchemaException(
          'Circular "allOf": ${[...wrappers, node.location].join(' -> ')}',
          schema,
        );
      }
      node = loader.deref(node.children('allOf').single, visit: _checkKeywords);
    }
    return node;
  }

  /// The keywords the resolver understands, or ignores because they only
  /// validate values and do not change the generated types.
  static const _supportedKeywords = {
    r'$schema', r'$id', r'$ref', r'$comment', 'definitions', r'$defs', //
    'title', 'description', 'type', 'properties', 'required', 'items',
    'allOf', 'oneOf', 'enum', 'const',
    // Validation and annotations only:
    'readOnly', 'pattern', 'format', 'minimum', 'maximum',
    'exclusiveMinimum', 'exclusiveMaximum', 'multipleOf', 'minLength',
    'maxLength', 'minItems', 'maxItems', 'uniqueItems', 'examples',
  };

  /// Throws on keywords the resolver does not support, so that a schema
  /// using one is not silently generated without it.
  void _checkKeywords(SchemaNode node) {
    for (final MapEntry(:key, :value) in node.json.entries) {
      if (_supportedKeywords.contains(key)) continue;
      // `false` only forbids other keys, which needs nothing generated.
      if (key == 'additionalProperties' && value == false) continue;
      throw SchemaException('Unsupported keyword "$key"', node);
    }
  }

  bool _isRefWrapper(SchemaNode node) => switch (node.json['allOf']) {
    [final JsonMap part] =>
      part.containsKey(r'$ref') &&
          !node.has('properties') &&
          !node.has('required'),
    _ => false,
  };

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
    _register(definition, node);

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
  ///
  /// [merging] are the schemas whose parts are being merged, to detect a
  /// part that leads back to one of them.
  _Object _flatten(SchemaNode schema, {Set<String> merging = const {}}) {
    final node = loader.deref(schema, visit: _checkKeywords);
    if (merging.contains(node.location)) {
      throw SchemaException(
        'Circular "allOf": ${[...merging, node.location].join(' -> ')}',
        node,
      );
    }
    if (node.has('oneOf')) {
      throw SchemaException('A "oneOf" cannot be merged into an object', node);
    }
    final result = _Object();
    if (node.has('allOf')) {
      for (final part in node.children('allOf')) {
        result.merge(_flatten(part, merging: {...merging, node.location}));
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
    return required.whereType<String>().toSet();
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
    for (final value in values.whereType<String>()) {
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
    _register(definition, node);
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
    _register(union, node);

    // A variant can still be missing fields here, when it uses this union
    // before declaring its discriminator, so the union is finished once
    // every schema is resolved.
    _unfinishedUnions.add((
      union,
      [for (final part in parts) _variant(part, union)],
      node,
    ));
    return union;
  }

  /// Picks the discriminator of [union] and links it to its [variants].
  void _finishUnion(
    UnionDefinition union,
    List<ClassDefinition> variants,
    SchemaNode node,
  ) {
    union.discriminatorKey = _discriminator(variants, node);
    for (final variant in variants) {
      if (variant.constField(union.discriminatorKey) case Field(
        constValue: final Object value,
      )) {
        union.variants[value] = variant;
        variant.unions.add(union);
      }
    }
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
                }.nonNulls.length ==
                variants.length)
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

  // MARK: - Registry

  /// Records [definition] as the type of the schema at [node].
  ///
  /// Throws when another schema already produced a type with the same name:
  /// the generated file would have two declarations of it.
  void _register(Definition definition, SchemaNode node) {
    final other = _definitionsByName[definition.name];
    if (other != null) {
      throw SchemaException(
        'Two schemas produce the type "${definition.name}": '
        '${other.location} and ${node.location}; '
        'rename one of them by its location in "type_renames"',
        node,
      );
    }
    _definitions[node.location] = definition;
    _definitionsByName[definition.name] = definition;
  }

  // MARK: - Naming

  /// `SR` + the title without "Mobile" (`MobileFullSnapshotRecord` ->
  /// `SRFullSnapshotRecord`), or for schemas without a title, the owner
  /// followed by the property (`SRMetaRecord` + `data` -> `SRMetaRecordData`);
  /// then [NamingOptions.renames] applies, by location first.
  String _typeName(
    SchemaNode node, {
    required String owner,
    required String property,
  }) {
    final name = switch (node.title) {
      final title? => '${naming.typePrefix}${pascalCase(_stripTitle(title))}',
      null => '$owner${pascalCase(property)}',
    };
    for (final key in [node.location, name]) {
      final renamed = naming.renames[key];
      if (renamed != null) {
        _appliedRenames.add(key);
        return renamed;
      }
    }
    return name;
  }

  /// [title] without the first of [NamingOptions.stripFromTitles] it
  /// starts with.
  String _stripTitle(String title) {
    for (final prefix in naming.stripFromTitles) {
      if (title.startsWith(prefix)) return title.substring(prefix.length);
    }
    return title;
  }
}

/// The merged properties of an object schema.
final class _Object {
  /// Property name -> its schema, in declaration order.
  final properties = <String, SchemaNode>{};
  final required = <String>{};

  void merge(_Object other) {
    properties.addAll(other.properties);
    required.addAll(other.required);
  }
}
