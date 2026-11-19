// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

/// The root directory of the `sr_models_generator` package, wherever the
/// tests are run from.
Future<String> packageRoot() async {
  try {
    final library = await Isolate.resolvePackageUri(
      Uri.parse('package:sr_models_generator/sr_models_generator.dart'),
    );
    if (library != null) {
      // <root>/lib/sr_models_generator.dart
      return p.dirname(p.dirname(library.toFilePath()));
    }
  } on UnsupportedError {
    // `flutter test`, which CI runs, does not resolve package URIs.
  }
  return _packageRootAbove(Directory.current.absolute.path);
}

/// The closest directory, from [start] up, with this package's pubspec.
String _packageRootAbove(String start) {
  var dir = start;
  while (true) {
    final pubspec = File(p.join(dir, 'pubspec.yaml'));
    if (pubspec.existsSync() &&
        pubspec.readAsLinesSync().contains('name: sr_models_generator')) {
      return dir;
    }
    final parent = p.dirname(dir);
    if (parent == dir) {
      throw StateError('Cannot find the sr_models_generator package');
    }
    dir = parent;
  }
}
