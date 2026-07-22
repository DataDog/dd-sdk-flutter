// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;

// Desktop integration tests  must be run one file at a time with `flutter
// test`, rather than as a single `flutter drive` run over the whole directory.
//
// See issue https://github.com/flutter/flutter/issues/135673
const fileExclude = [
  // Not a test
  'common.dart',
  // Not supported on desktop currently
  'configuration_telemetry_test.dart',
];

String currentDevice() {
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  throw UnsupportedError(
    'Unsupported desktop platform: ${Platform.operatingSystem}',
  );
}

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'output',
      abbr: 'o',
      help:
          'Directory to write a junit XML report per test file to. If '
          'omitted, test output is streamed to the console instead.',
    );
  final results = parser.parse(arguments);
  final outputDir = results['output'] as String?;

  // Check path
  var testDirectory = Directory('integration_test');
  if (!testDirectory.existsSync()) {
    print(
      'Could not find the "integration_test" directory. Make sure you are running this from the integration_test_app root',
    );
    exit(1);
  }

  final device = currentDevice();
  final packageName = Platform.environment['MELOS_PACKAGE_NAME'] ?? 'desktop';

  if (outputDir != null) {
    Directory(outputDir).createSync(recursive: true);
  }

  for (final file in testDirectory.listSync()) {
    if (file is File) {
      final baseName = path.basename(file.path);
      if (fileExclude.contains(baseName)) {
        continue;
      }
      final testName = path.basenameWithoutExtension(baseName);

      final args = ['test', 'integration_test/$baseName', '-d', device];
      final clientToken = Platform.environment['DD_CLIENT_TOKEN'];
      if (clientToken != null) {
        args.addAll(['--dart-define', 'DD_CLIENT_TOKEN=$clientToken']);
      }
      final applicationId = Platform.environment['DD_APPLICATION_ID'];
      if (applicationId != null) {
        args.addAll(['--dart-define', 'DD_APPLICATION_ID=$applicationId']);
      }

      int exitCode;
      if (outputDir != null) {
        final outputFile = path.join(
          outputDir,
          '${packageName}_${device}_integration_$testName.xml',
        );
        exitCode = await _runTestWithJunit(
          [...args, '--machine'],
          outputFile,
        );
      } else {
        exitCode = await _runTest(args);
      }

      if (exitCode != 0) {
        print('Command failed');
        exit(exitCode);
      }
    }
  }
}

Future<int> _runTest(List<String> args) async {
  print('flutter ${args.join(' ')}');
  final process = await Process.start('flutter', args);
  process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(print);
  process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(print);

  return process.exitCode;
}

Future<int> _runTestWithJunit(List<String> args, String outputFile) async {
  print('flutter ${args.join(' ')} | tojunit --output $outputFile');
  final testProcess = await Process.start('flutter', args);
  final tojunitProcess = await Process.start('tojunit', [
    '--output',
    outputFile,
  ]);

  testProcess.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(print);

  final pipeDone = testProcess.stdout.pipe(tojunitProcess.stdin);
  final testExitCode = await testProcess.exitCode;
  await pipeDone;
  final tojunitExitCode = await tojunitProcess.exitCode;
  if (tojunitExitCode != 0) {
    print('tojunit failed with exit code $tojunitExitCode for $outputFile');
  }

  return testExitCode;
}
