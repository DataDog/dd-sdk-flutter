// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:meta/meta.dart';

import 'model.dart';

/// Prints the [Definition]s of the resolver as one Dart library.
///
/// The output compiles but is not formatted; it is meant to go through
/// `dart format`.
@immutable
final class DartPrinter {
  const DartPrinter({this.header = const []});

  /// Comment lines at the top of the library, without the leading `//`.
  final List<String> header;

  String printLibrary(Iterable<Definition> definitions) {
    final library = _Library();
    final declarations = [
      for (final definition in definitions)
        switch (definition) {
          EnumDefinition() => definition.toDart(),
          ClassDefinition() => library.classToDart(definition),
          UnionDefinition() => definition.toDart(),
        },
    ];

    final out = StringBuffer();
    for (final line in header) {
      out.writeln(line.isEmpty ? '//' : '// $line');
    }
    if (definitions.any((d) => d is ClassDefinition || d is UnionDefinition)) {
      out
        ..writeln()
        ..writeln("import 'package:meta/meta.dart';");
    }
    for (final declaration in [...declarations, ...library.helpers()]) {
      out
        ..writeln()
        ..write(declaration);
    }
    return out.toString();
  }
}

extension on UnionDefinition {
  /// A sealed class that the variants implement, with a `fromJson` that
  /// picks the variant from the discriminator, and the fields every variant
  /// shares.
  String toDart() {
    final key = dartString(discriminatorKey);
    final cases = [
      for (final MapEntry(key: tag, value: variant) in variants.entries)
        '    ${tag is String ? dartString(tag) : '$tag'} => '
            '${variant.name}.fromJson(json),',
    ];
    final getters = [
      for (final field in sharedFields)
        '${field.description.docComment(indent: '  ')}'
            '  ${field.type.dartType}${field.isRequired ? '' : '?'} '
            'get ${field.dartName};',
    ];
    return '''
${description.docComment()}@immutable
sealed class $name {
  factory $name.fromJson(Map<String, Object?> json) => switch (json[$key]) {
${cases.join('\n')}
    final other => throw FormatException(
      ${dartString('Unknown $name $discriminatorKey: ')} '\$other',
    ),
  };

${getters.join('\n')}

  Map<String, Object?> toJson();
}
''';
  }
}

extension on EnumDefinition {
  /// An enhanced enum whose cases hold their JSON value.
  String toDart() {
    final cases = [
      for (final MapEntry(key: value, value: caseName) in values.entries)
        '  $caseName(${dartString(value)})',
    ];
    return '''
${description.docComment()}enum $name {
${cases.join(',\n')};

  const $name(this.value);

  /// The case whose [value] is [json].
  factory $name.fromJson(String json) => values.firstWhere(
    (e) => e.value == json,
    orElse: () => throw FormatException('Unknown $name value: \$json'),
  );

  /// This case in JSON.
  final String value;

  String toJson() => value;
}
''';
  }
}

/// Prints the classes of one library, and remembers which decoding helpers
/// they use, so that the library only declares those.
final class _Library {
  final _used = <_Helper>{};

  /// The declarations of the helpers the printed classes use, in a fixed
  /// order.
  List<String> helpers() => [
    for (final helper in _Helper.values)
      if (_used.contains(helper) ||
          (helper == _Helper.invalid && _used.any((h) => h.decodes)))
        helper.code,
  ];

  /// An immutable class with a `fromJson` factory and a `toJson` method.
  String classToDart(ClassDefinition c) {
    // The fields this class implements for the unions it belongs to.
    final overrides = {
      for (final union in c.unions)
        for (final field in union.sharedFields) field.jsonKey,
    };
    final override = [
      for (final field in c.fields) overrides.contains(field.jsonKey),
    ];
    final parameters = <String>[];
    final arguments = <String>[];
    final members = <String>[];
    final entries = <String>[];
    // Const fields are the same in every instance, so == ignores them.
    final comparisons = <String>[];
    final hashes = <String>[];
    for (final (i, field) in c.fields.indexed) {
      final type = field.type.dartType;
      final annotation =
          '${field.description.docComment(indent: '  ')}'
          '${override[i] ? '  @override\n' : ''}';
      if (!field.isConst) {
        parameters.add(
          '${field.isRequired ? 'required ' : ''}this.${field.dartName}',
        );
        arguments.add('    ${field.dartName}: ${_decodeField(c, field)},');
        members.add(
          '$annotation  final $type${field.isRequired ? '' : '?'} '
          '${field.dartName};',
        );
        if (field.type is ListType) {
          // List == compares identity; lists are compared item by item.
          _used.addAll([_Helper.equals, _Helper.hash]);
          comparisons.add(
            '_equals(other.${field.dartName}, this.${field.dartName})',
          );
          hashes.add('_hash(${field.dartName})');
        } else {
          // `this.`, for a field named `other`.
          comparisons.add('other.${field.dartName} == this.${field.dartName}');
          hashes.add(field.dartName);
        }
      } else {
        // A const field is a getter: neither a parameter nor decoded.
        final value = switch (field.constValue) {
          final String value => dartString(value),
          final value => '$value',
        };
        members.add('$annotation  $type get ${field.dartName} => $value;');
      }
      entries.add('    ${_encodeField(field)},');
    }

    final constructor = parameters.isEmpty
        ? '  const ${c.name}();'
        : '  const ${c.name}({${parameters.join(', ')}});';
    final factory = arguments.isEmpty
        ? '  factory ${c.name}.fromJson(Map<String, Object?> json) => '
              'const ${c.name}();'
        : '  factory ${c.name}.fromJson(Map<String, Object?> json) => '
              '${c.name}(\n${arguments.join('\n')}\n  );';

    return '''
${c.description.docComment()}@immutable
final class ${c.name}${c.unions.isEmpty ? '' : ' implements ${[for (final union in c.unions) union.name].join(', ')}'} {
$constructor

$factory
${members.isEmpty ? '' : '\n${members.join('\n')}\n'}
${c.unions.isEmpty ? '' : '  @override\n'}  Map<String, Object?> toJson() => {
${entries.join('\n')}
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ${c.name}${[for (final comparison in comparisons) ' && $comparison'].join()};

  @override
  int get hashCode => Object.hashAll([${hashes.join(', ')}]);
}
''';
  }

  /// The argument decoding [field] of [c] from `json`.
  String _decodeField(ClassDefinition c, Field field) {
    final where = dartString('${c.name}.${field.jsonKey}');
    final json = 'json[${dartString(field.jsonKey)}]';
    if (field.isRequired) return _decode(field.type, json, where);
    return 'switch ($json) { null => null, '
        'final value => ${_decode(field.type, 'value', where)} }';
  }

  /// An expression decoding the JSON value [json] as [type]; [where] is the
  /// Dart expression of its location, for error messages.
  String _decode(TypeRef type, String json, String where, [int depth = 0]) {
    switch (type) {
      case PrimitiveType(:final primitive):
        final helper = _Helper.of(primitive);
        _used.add(helper);
        return '${helper.function}($json, $where)';
      case ListType(item: PrimitiveType(:final primitive)):
        _used.addAll([_Helper.list, _Helper.of(primitive)]);
        return '_list($json, $where, ${_Helper.of(primitive).function})';
      case ListType(:final item):
        _used.add(_Helper.list);
        final (value, at) = ('v$depth', 'at$depth');
        return '_list($json, $where, ($value, $at) => '
            '${_decode(item, value, at, depth + 1)})';
      case NamedType(definition: EnumDefinition(:final name)):
        _used.add(_Helper.string);
        return '$name.fromJson(_string($json, $where))';
      case NamedType(definition: ClassDefinition(:final name)) ||
          NamedType(definition: UnionDefinition(:final name)):
        _used.add(_Helper.object);
        return '$name.fromJson(_object($json, $where))';
    }
  }

  /// The `toJson` map entry of [field]: left out when the field is `null`.
  String _encodeField(Field field) {
    final key = dartString(field.jsonKey);
    final name = field.dartName;
    if (field.isRequired) return '$key: ${_encode(field.type, name)}';
    return switch (field.type) {
      PrimitiveType() => '$key: ?$name',
      ListType() when field.type.isJson => '$key: ?$name',
      NamedType() => '$key: ?$name?.toJson()',
      ListType() =>
        'if ($name case final $name?) $key: ${_encode(field.type, name)}',
    };
  }

  /// An expression encoding the value [value] of type [type] to JSON.
  String _encode(TypeRef type, String value, [int depth = 0]) => switch (type) {
    PrimitiveType() => value,
    ListType() when type.isJson => value,
    NamedType() => '$value.toJson()',
    ListType(:final item) =>
      '[for (final v$depth in $value) ${_encode(item, 'v$depth', depth + 1)}]',
  };
}

/// The private functions generated classes decode JSON values with. Each
/// checks the type of the value and fails with its location.
enum _Helper {
  integer('_int', r'''
int _int(Object? json, String where) => switch (json) {
  final int value => value,
  final double value when value == value.truncateToDouble() => value.toInt(),
  _ => throw _invalid(json, where),
};
'''),
  number('_double', r'''
double _double(Object? json, String where) => switch (json) {
  final num value => value.toDouble(),
  _ => throw _invalid(json, where),
};
'''),
  string('_string', r'''
String _string(Object? json, String where) => switch (json) {
  final String value => value,
  _ => throw _invalid(json, where),
};
'''),
  boolean('_bool', r'''
bool _bool(Object? json, String where) => switch (json) {
  final bool value => value,
  _ => throw _invalid(json, where),
};
'''),
  object('_object', r'''
Map<String, Object?> _object(Object? json, String where) => switch (json) {
  final Map<String, Object?> value => value,
  _ => throw _invalid(json, where),
};
'''),
  list('_list', r'''
List<T> _list<T>(
  Object? json,
  String where,
  T Function(Object? json, String where) item,
) => switch (json) {
  final List<Object?> items => [
    for (final (i, value) in items.indexed) item(value, '$where[$i]'),
  ],
  _ => throw _invalid(json, where),
};
'''),
  invalid('_invalid', r'''
FormatException _invalid(Object? json, String where) =>
    FormatException('Invalid $where: $json');
'''),
  equals('_equals', r'''
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
''', decodes: false),
  hash('_hash', r'''
int _hash(Object? value) => value is List<Object?>
    ? Object.hashAll([for (final item in value) _hash(item)])
    : value.hashCode;
''', decodes: false);

  const _Helper(this.function, this.code, {this.decodes = true});

  /// The helper decoding [primitive].
  factory _Helper.of(Primitive primitive) => switch (primitive) {
    Primitive.integer => integer,
    Primitive.number => number,
    Primitive.string => string,
    Primitive.boolean => boolean,
  };

  /// The name of the function.
  final String function;

  /// Its declaration.
  final String code;

  /// Whether it decodes JSON, and so reports errors with [invalid].
  final bool decodes;
}

extension on String? {
  /// This text as a documentation comment indented by [indent], wrapped to
  /// fit 80 columns; empty when there is no text.
  ///
  /// `[`, `]` and `<` are escaped, so that dartdoc shows them as written
  /// instead of reading a symbol reference (`[0]`) or an HTML tag.
  String docComment({String indent = ''}) {
    final text = this?.trim() ?? '';
    if (text.isEmpty) return '';
    final width = 80 - indent.length - '/// '.length;
    final out = StringBuffer();
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    for (final (i, paragraph) in paragraphs.indexed) {
      if (i > 0) out.writeln('$indent///');
      var line = '';
      for (final word in paragraph.split(RegExp(r'\s+'))) {
        final escaped = word.replaceAllMapped(
          RegExp(r'[\[\]<]'),
          (match) => '\\${match[0]}',
        );
        if (line.isNotEmpty && line.length + 1 + escaped.length > width) {
          out.writeln('$indent/// $line');
          line = escaped;
        } else {
          line = line.isEmpty ? escaped : '$line $escaped';
        }
      }
      out.writeln('$indent/// $line');
    }
    return out.toString();
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

  /// Whether values of this type are already JSON: primitives, and lists of
  /// them at any depth.
  bool get isJson => switch (this) {
    PrimitiveType() => true,
    ListType(:final item) => item.isJson,
    NamedType() => false,
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
