// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'package_root.dart';

/// A JSON value to decode with `<type>.fromJson`: an object for a class,
/// a string for an enum.
@immutable
final class RoundTripCase {
  const RoundTripCase(this.name, this.type, this.json);

  /// Identifies the case in the results.
  final String name;

  /// The Dart type that decodes [json], e.g. `SRSegment`.
  final String type;

  final Object? json;
}

/// What went wrong with one [RoundTripCase].
@immutable
final class RoundTripResult {
  const RoundTripResult(this.name, this.errors);

  final String name;

  /// Every difference found; empty when the case round-tripped unchanged.
  final List<String> errors;

  @override
  String toString() =>
      errors.isEmpty ? '$name: ok' : '$name: ${errors.join('; ')}';
}

/// Compiles [library] (generated models) and checks every case of [cases]:
/// * `fromJson` followed by `toJson` gives back the same JSON, reporting
///   each missing, unexpected or changed value with its path;
/// * decoding that JSON again gives a model `==` to the first one.
///
/// Each type of [cases] must have a `fromJson` factory taking the decoded
/// JSON value, and a `toJson()` method.
///
/// Throws a [StateError] with the compiler output when [library] does not
/// compile.
Future<List<RoundTripResult>> roundTrip(
  String library,
  List<RoundTripCase> cases,
) async {
  // Inside the package, so that `package:` imports of the generated code
  // (e.g. `package:meta`) resolve with the package's own configuration.
  final scratch = Directory(
    p.join(await packageRoot(), '.dart_tool'),
  ).createTempSync('round_trip_');
  try {
    File(p.join(scratch.path, 'models.dart')).writeAsStringSync(library);
    final input = File(p.join(scratch.path, 'cases.json'))
      ..writeAsStringSync(
        jsonEncode([
          for (final c in cases)
            {'name': c.name, 'type': c.type, 'json': c.json},
        ]),
      );
    final runner = File(p.join(scratch.path, 'main.dart'))
      ..writeAsStringSync(_runner({for (final c in cases) c.type}));

    final result = await Process.run('dart', ['run', runner.path, input.path]);
    if (result.exitCode != 0) {
      throw StateError(
        'The round trip runner failed (exit code ${result.exitCode}):\n'
        '${result.stdout}${result.stderr}',
      );
    }
    return [
      for (final line in LineSplitter.split(result.stdout.toString()))
        if (jsonDecode(line) case {
          'name': final String name,
          'errors': final List<Object?> errors,
        })
          RoundTripResult(name, [...errors.whereType<String>()]),
    ];
  } finally {
    scratch.deleteSync(recursive: true);
  }
}

/// A script that round-trips the cases of the JSON file given as argument
/// and prints one JSON line per case: `{"name": ..., "errors": [...]}`.
String _runner(Set<String> types) =>
    '''
import 'dart:convert';
import 'dart:io';

import 'models.dart';

final decoders = <String, Function>{
${[for (final type in types) "  '$type': $type.fromJson,"].join('\n')}
};

void diff(Object? expected, Object? actual, String path, List<String> errors) {
  if (expected is Map && actual is Map) {
    for (final key in {...expected.keys, ...actual.keys}) {
      if (!actual.containsKey(key)) {
        errors.add('\$path.\$key: missing');
      } else if (!expected.containsKey(key)) {
        errors.add('\$path.\$key: unexpected');
      } else {
        diff(expected[key], actual[key], '\$path.\$key', errors);
      }
    }
  } else if (expected is List && actual is List) {
    if (expected.length != actual.length) {
      errors.add(
        '\$path: \${expected.length} items expected, \${actual.length} found',
      );
    } else {
      for (var i = 0; i < expected.length; i++) {
        diff(expected[i], actual[i], '\$path[\$i]', errors);
      }
    }
  } else if (expected != actual) {
    errors.add('\$path: expected \$expected, found \$actual');
  }
}

void main(List<String> args) {
  final cases = jsonDecode(File(args.single).readAsStringSync()) as List<Object?>;
  for (final c in cases.cast<Map<String, Object?>>()) {
    final errors = <String>[];
    try {
      final decode = decoders[c['type']]!;
      final model = Function.apply(decode, [c['json']]);
      final encoded = jsonDecode(jsonEncode(model));
      diff(c['json'], encoded, r'\$', errors);
      if (Function.apply(decode, [encoded]) != model) {
        errors.add('decoding the encoded JSON gives a model that is not ==');
      }
    } catch (e) {
      errors.add('threw \$e');
    }
    stdout.writeln(jsonEncode({'name': c['name'], 'errors': errors}));
  }
}
''';
