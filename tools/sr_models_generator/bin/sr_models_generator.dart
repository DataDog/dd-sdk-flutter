// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:sr_models_generator/sr_models_generator.dart';

Future<void> main(List<String> arguments) async {
  final library = await Isolate.resolvePackageUri(
    Uri.parse('package:sr_models_generator/sr_models_generator.dart'),
  );
  if (library == null) {
    stderr.writeln('Cannot find the sr_models_generator package.');
    exitCode = 1;
    return;
  }
  // <root>/lib/sr_models_generator.dart
  final packageRoot = p.dirname(p.dirname(library.toFilePath()));
  exitCode = await runGenerator(arguments, packageRoot: packageRoot);
}
