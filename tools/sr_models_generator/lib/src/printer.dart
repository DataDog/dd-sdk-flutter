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
    final out = StringBuffer();
    for (final line in header) {
      out.writeln(line.isEmpty ? '//' : '// $line');
    }
    for (final definition in definitions) {
      out
        ..writeln()
        ..write(switch (definition) {
          EnumDefinition() => definition.toDart(),
          ClassDefinition() || UnionDefinition() => throw UnsupportedError(
            'Printing ${definition.name} is not supported yet',
          ),
        });
    }
    return out.toString();
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
enum $name {
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
