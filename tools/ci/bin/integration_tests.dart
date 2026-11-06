// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/args.dart';
import 'package:ci_helpers/integration_test_platform.dart';
import 'package:ci_helpers/integration_test_runner.dart';
import 'package:path/path.dart' as path;

// Runs each integration test file with its own `flutter test` process, so
// desktop platforms (see https://github.com/flutter/flutter/issues/135673) and
// mobile devices start from a clean app. On mobile, a file whose app fails to
// launch is retried once after the device is rebooted.
//
// Run from the directory containing `integration_test`. Web uses
// `web_integration_tests.dart`, which drives tests with `flutter drive`.
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'platform',
      abbr: 'p',
      allowed: TestPlatform.values.map((p) => p.name),
      help: 'Platform to run on. Defaults to the host desktop platform.',
    )
    ..addOption(
      'output',
      abbr: 'o',
      help:
          'Directory to write a junit XML report and raw JSON event log per '
          'test file to.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      help: 'Enable verbose output from flutter test',
    )
    ..addOption(
      'startup-timeout-minutes',
      defaultsTo: '5',
      help:
          'Treat the app launch as hung when no test has started after this long.',
    );
  final results = parser.parse(arguments);
  final platform = switch (results['platform']) {
    final String name => TestPlatform.values.byName(name),
    _ => TestPlatform.host,
  };

  final testDirectory = Directory('integration_test');
  if (!testDirectory.existsSync()) {
    print(
      'Could not find the "integration_test" directory. Make sure you are '
      'running this from the package root.',
    );
    exit(1);
  }

  final runner = IntegrationTestRunner(
    platform: platform,
    packageName: Platform.environment['MELOS_PACKAGE_NAME'] ?? platform.name,
    outputDir: results['output'] as String?,
    dartDefines: [
      for (final name in ['DD_CLIENT_TOKEN', 'DD_APPLICATION_ID'])
        if (Platform.environment[name] case final value?) '$name=$value',
    ],
    extraArgs: [if (results['verbose'] == true) '--verbose'],
    startupTimeout: Duration(
      minutes: int.parse(results['startup-timeout-minutes'] as String),
    ),
  );

  final files = [
    for (final entity in testDirectory.listSync(recursive: true))
      if (entity is File &&
          entity.path.endsWith('_test.dart') &&
          !platform.excludedFiles.contains(path.basename(entity.path)))
        entity.path,
  ]..sort();

  for (final file in files) {
    final testName = path
        .withoutExtension(path.relative(file, from: testDirectory.path))
        .replaceAll(path.separator, '_');
    final outcome = await runner.runFile(file, testName);
    if (outcome != AttemptOutcome.passed) {
      print('$file failed: ${outcome.name}');
      exit(1);
    }
  }
}
