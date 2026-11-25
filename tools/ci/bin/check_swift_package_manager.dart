// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:args/args.dart';
import 'package:ci_helpers/swift_package_manager.dart';
import 'package:path/path.dart' as path;

// Exits non-zero unless Flutter's Swift Package Manager support is enabled for
// each app. Each positional argument is a package directory; `--app-subdir`
// names the app inside it (e.g. `example`).
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'app-subdir',
      help: 'App directory inside each package directory.',
    );
  final results = parser.parse(arguments);
  final subdir = results['app-subdir'] as String?;

  await requireSwiftPackageManager([
    for (final package in results.rest)
      subdir == null ? package : path.join(package, subdir),
  ]);
}
