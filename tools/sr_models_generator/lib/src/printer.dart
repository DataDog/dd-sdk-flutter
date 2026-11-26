// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:code_builder/code_builder.dart' hide Field;
import 'package:code_builder/code_builder.dart' as cb show Field;
import 'package:meta/meta.dart';

import 'model.dart';

const _jsonAnnotation = 'package:json_annotation/json_annotation.dart';
const _meta = 'package:meta/meta.dart';

/// Prints the [Definition]s of the resolver as one Dart library, whose JSON
/// code `json_serializable` generates in the [part] file.
///
/// The output is not formatted; it is meant for `dart format`.
@immutable
final class DartPrinter {
  const DartPrinter({required this.part, this.header = const []});

  /// The file name of the part `json_serializable` generates, e.g.
  /// `sr_data_models.g.dart`.
  final String part;

  /// Comment lines at the top of the library, without the leading `//`.
  final List<String> header;

  String printLibrary(Iterable<Definition> definitions) {
    final helpers = <_Helper>{};
    final library = Library(
      (b) => b
        ..directives.add(Directive.part(part))
        ..body.addAll([
          for (final definition in definitions)
            switch (definition) {
              EnumDefinition() => definition.toSpec(),
              ClassDefinition() => definition.toSpec(helpers),
              UnionDefinition() => definition.toSpec(),
            },
          for (final helper in _Helper.values)
            if (helpers.contains(helper)) Code(helper.code),
        ]),
    );
    final emitter = DartEmitter(
      allocator: Allocator(),
      orderDirectives: true,
      useNullSafetySyntax: true,
    );
    return [
      for (final line in header) line.isEmpty ? '//' : '// $line',
      '',
      library.accept(emitter),
    ].join('\n');
  }
}

extension on EnumDefinition {
  Enum toSpec() => Enum(
    (b) => b
      ..name = name
      ..docs.addAll(description.docComment())
      ..values.addAll([
        for (final MapEntry(key: value, value: caseName) in values.entries)
          EnumValue(
            (v) => v
              ..name = caseName
              ..annotations.add(
                refer('JsonValue', _jsonAnnotation).call([_string(value)]),
              ),
          ),
      ]),
  );
}

extension on UnionDefinition {
  /// A sealed class that the variants implement.
  Class toSpec() {
    final cases = [
      for (final MapEntry(key: tag, value: variant) in variants.entries)
        '${tag is String ? dartString(tag) : '$tag'} => '
            '${variant.name}.fromJson(json),',
    ];
    return Class(
      (b) => b
        ..name = name
        ..sealed = true
        ..docs.addAll(description.docComment())
        ..annotations.add(refer('immutable', _meta))
        ..constructors.add(
          Constructor(
            (c) => c
              ..factory = true
              ..name = 'fromJson'
              ..requiredParameters.add(_jsonParameter)
              ..lambda = true
              ..body = Code('''
switch (json[${dartString(discriminatorKey)}]) {
  ${cases.join('\n  ')}
  final other => throw FormatException(
    ${dartString('Unknown $name $discriminatorKey: ')} '\$other',
  ),
}'''),
          ),
        )
        ..methods.addAll([
          for (final field in sharedFields)
            Method(
              (m) => m
                ..type = MethodType.getter
                ..name = field.dartName
                ..docs.addAll(field.description.docComment(indent: 2))
                ..returns = refer(field.dartType),
            ),
          Method(
            (m) => m
              ..name = 'toJson'
              ..returns = refer('Map<String, dynamic>'),
          ),
        ]),
    );
  }
}

extension on ClassDefinition {
  /// An immutable class compared by value; records in [helpers] the helpers
  /// its `==` and `hashCode` use.
  Class toSpec(Set<_Helper> helpers) {
    // The fields this class implements for the unions it belongs to.
    final overrides = {
      for (final union in unions)
        for (final field in union.sharedFields) field.jsonKey,
    };
    // Const fields are the same in every instance, so == ignores them.
    final comparisons = <String>[];
    final hashes = <String>[];
    for (final field in fields) {
      if (field.isConst) continue;
      // In ==, the parameter `other` hides a field named `other`, which
      // then needs `this.`; anywhere else, `this.` is unnecessary.
      final own = field.dartName == 'other' ? 'this.other' : field.dartName;
      if (field.type is ListType) {
        // List == compares identity; lists are compared item by item.
        helpers.addAll([_Helper.equals, _Helper.hash]);
        comparisons.add('_equals(other.${field.dartName}, $own)');
        hashes.add('_hash(${field.dartName})');
      } else {
        comparisons.add('other.${field.dartName} == $own');
        hashes.add(field.dartName);
      }
    }
    final override = refer('override');
    return Class(
      (b) => b
        ..name = name
        ..modifier = ClassModifier.final$
        ..docs.addAll(description.docComment())
        ..annotations.addAll([
          refer('immutable', _meta),
          refer('JsonSerializable', _jsonAnnotation).call([], {
            // Nested objects become maps, as platform channels need.
            'explicitToJson': literalTrue,
            'includeIfNull': literalFalse,
            // Errors name the class and the key.
            'checked': literalTrue,
          }),
        ])
        ..implements.addAll([for (final union in unions) refer(union.name)])
        ..constructors.addAll([
          Constructor(
            (c) => c
              ..constant = true
              ..optionalParameters.addAll([
                for (final field in fields)
                  if (!field.isConst)
                    Parameter(
                      (p) => p
                        ..name = field.dartName
                        ..named = true
                        ..toThis = true
                        ..required = field.isRequired,
                    ),
              ]),
          ),
          Constructor(
            (c) => c
              ..factory = true
              ..name = 'fromJson'
              ..requiredParameters.add(_jsonParameter)
              ..lambda = true
              ..body = Code('_\$${name}FromJson(json)'),
          ),
        ])
        ..fields.addAll([
          for (final field in fields)
            cb.Field(
              (f) => f
                ..name = field.dartName
                ..modifier = FieldModifier.final$
                ..type = refer(field.dartType)
                ..docs.addAll(field.description.docComment(indent: 2))
                ..annotations.addAll([
                  if (overrides.contains(field.jsonKey)) override,
                  ?field.jsonKeyAnnotation,
                ])
                ..assignment = switch (field.constValue) {
                  null => null,
                  final String value => Code(dartString(value)),
                  final value => Code('$value'),
                },
            ),
        ])
        ..methods.addAll([
          Method(
            (m) => m
              ..name = 'toJson'
              ..returns = refer('Map<String, dynamic>')
              ..annotations.addAll([if (unions.isNotEmpty) override])
              ..lambda = true
              ..body = Code('_\$${name}ToJson(this)'),
          ),
          Method(
            (m) => m
              ..name = 'operator =='
              ..returns = refer('bool')
              ..annotations.add(override)
              ..requiredParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'other'
                    ..type = refer('Object'),
                ),
              )
              ..lambda = true
              ..body = Code(
                'identical(this, other) || other is $name'
                '${[for (final comparison in comparisons) ' && $comparison'].join()}',
              ),
          ),
          Method(
            (m) => m
              ..type = MethodType.getter
              ..name = 'hashCode'
              ..returns = refer('int')
              ..annotations.add(override)
              ..lambda = true
              ..body = Code('Object.hashAll([${hashes.join(', ')}])'),
          ),
        ]),
    );
  }
}

extension on Field {
  String get dartType => '${type.dartType}${isRequired ? '' : '?'}';

  /// The `@JsonKey` of this field, if it needs one: when its Dart name
  /// differs from its JSON key, and for a const field, which is written
  /// but not read, as `json_serializable` would otherwise skip it.
  Expression? get jsonKeyAnnotation {
    final arguments = {
      if (dartName != jsonKey) 'name': _string(jsonKey),
      if (isConst) ...{
        'includeFromJson': literalFalse,
        'includeToJson': literalTrue,
      },
    };
    if (arguments.isEmpty) return null;
    return refer('JsonKey', _jsonAnnotation).call([], arguments);
  }
}

final _jsonParameter = Parameter(
  (p) => p
    ..name = 'json'
    ..type = refer('Map<String, dynamic>'),
);

Expression _string(String value) => CodeExpression(Code(dartString(value)));

/// The private functions that `==` and `hashCode` compare lists with.
enum _Helper {
  equals(r'''
bool _equals(Object? a, Object? b) {
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_equals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
'''),
  hash(r'''
int _hash(Object? value) => value is List<Object?>
    ? Object.hashAll([for (final item in value) _hash(item)])
    : value.hashCode;
''');

  const _Helper(this.code);

  final String code;
}

extension on String? {
  /// This text as documentation comment lines for a declaration indented by
  /// [indent] columns, wrapped to fit 80 columns; none when there is no
  /// text.
  ///
  /// `[`, `]` and `<` are escaped, so that dartdoc shows them as written
  /// instead of reading a symbol reference (`[0]`) or an HTML tag.
  List<String> docComment({int indent = 0}) {
    final text = this?.trim() ?? '';
    if (text.isEmpty) return const [];
    final width = 80 - indent - '/// '.length;
    final lines = <String>[];
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    for (final (i, paragraph) in paragraphs.indexed) {
      if (i > 0) lines.add('///');
      var line = '';
      for (final word in paragraph.split(RegExp(r'\s+'))) {
        final escaped = word.replaceAllMapped(
          RegExp(r'[\[\]<]'),
          (match) => '\\${match[0]}',
        );
        if (line.isNotEmpty && line.length + 1 + escaped.length > width) {
          lines.add('/// $line');
          line = escaped;
        } else {
          line = line.isEmpty ? escaped : '$line $escaped';
        }
      }
      lines.add('/// $line');
    }
    return lines;
  }
}

extension on TypeRef {
  /// This type in Dart, e.g. `List<SRPoint>`.
  String get dartType => switch (this) {
    PrimitiveType(primitive: Primitive.integer) => 'int',
    PrimitiveType(primitive: Primitive.number) => 'double',
    PrimitiveType(primitive: Primitive.string) => 'String',
    PrimitiveType(primitive: Primitive.boolean) => 'bool',
    ListType(:final item) => 'List<${item.dartType}>',
    NamedType(:final definition) => definition.name,
  };
}

/// A Dart single-quoted string literal with the value [value].
String dartString(String value) {
  final escaped = StringBuffer();
  for (final rune in value.runes) {
    escaped.write(switch (rune) {
      0x5C => r'\\', // backslash
      0x27 => r"\'", // single quote
      0x24 => r'\$', // dollar, which would start an interpolation
      0x0A => r'\n',
      0x0D => r'\r',
      0x09 => r'\t',
      < 0x20 || 0x7F => '\\u{${rune.toRadixString(16)}}',
      _ => String.fromCharCode(rune),
    });
  }
  return "'$escaped'";
}
