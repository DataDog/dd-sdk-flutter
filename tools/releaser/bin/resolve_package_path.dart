// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// Tiny CLI `publish-package.yml` shells out to: given a package name (parsed
// from the `<package>/v<version>` tag that triggered it), prints that
// package's directory relative to the repo root, so the workflow can pass it
// as `working-directory` to `dart-lang/setup-dart`'s reusable publish
// workflow. Reuses `package_discovery.dart` rather than re-deriving the path
// from the name in bash/YAML, so there's exactly one place that knows how
// packages map to directories.

import 'dart:io';

import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:releaser/package_discovery.dart';

Future<void> main(List<String> arguments) async {
  final argParser = ArgParser()
    ..addOption('name', mandatory: true)
    ..addOption('repo-root', defaultsTo: '.');

  final args = argParser.parse(arguments);
  final name = args['name'] as String;
  final repoRoot = args['repo-root'] as String;

  final groups = await discoverPackages(repoRoot);
  final package = groups
      .expand((g) => g.members)
      .where((p) => p.name == name)
      .firstOrNull;

  if (package == null) {
    stderr.writeln('No package named "$name" found under $repoRoot/packages.');
    exitCode = 1;
    return;
  }

  print(package.relativePath);
}
