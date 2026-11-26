// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:isolate';

import 'package:path/path.dart' as p;

/// The root directory of the `sr_models_generator` package, wherever the
/// tests are run from.
Future<String> packageRoot() async {
  final library = await Isolate.resolvePackageUri(
    Uri.parse('package:sr_models_generator/sr_models_generator.dart'),
  );
  if (library == null) {
    throw StateError('Cannot find the sr_models_generator package');
  }
  // <root>/lib/sr_models_generator.dart
  return p.dirname(p.dirname(library.toFilePath()));
}
