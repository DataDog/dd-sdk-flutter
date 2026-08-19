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

// Must match the `service` configured in lib/main.dart and
// lib/integration_scenarios/scenario_runner.dart.
const _dataStorageService = 'com.datadoghq.flutter.integration';

const _appExecutableName = 'datadog_integration_test_app';

// Mirrors DesktopPlatform._storagePath in datadog_flutter_plugin_desktop.
Directory _dataStorageDirectory() {
  if (Platform.isWindows) {
    final base = Platform.environment['LOCALAPPDATA'] ?? '.';
    return Directory('$base\\Datadog\\$_dataStorageService');
  }
  final home = Platform.environment['HOME'] ?? '.';
  return Directory('$home/.local/share/datadog/$_dataStorageService');
}

// The C SDK's on-disk storage persists across app runs so it can recover
// from an abandoned process. That means a previous test file's session/batch
// data can otherwise leak into the next test file's run.
void _deleteStaleDatadogData() {
  final dir = _dataStorageDirectory();
  if (!dir.existsSync()) {
    return;
  }
  try {
    dir.deleteSync(recursive: true);
  } catch (e) {
    // If a previous test's process hasn't fully released its file handles
    // yet, this delete can fail. It could mean the previous process outlived
    // `flutter test`, so surface it loudly instead of silently retrying or
    // swallowing it.
    print('[${_timestamp()}] WARNING: failed to delete $dir: $e');
    rethrow;
  }
}

String _timestamp() => DateTime.now().toIso8601String();

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'output',
      abbr: 'o',
      help:
          'Directory to write a junit XML report per test file to. If '
          'omitted, test output is streamed to the console instead.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      help: 'Enable verbose output from flutter test',
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
      if (!baseName.endsWith('_test.dart')) {
        continue;
      }
      if (fileExclude.contains(baseName)) {
        continue;
      }
      final testName = path.basenameWithoutExtension(baseName);

      // Desktop `flutter test` occasionally fails with a "did not complete"
      // / "No tests were found" combo caused by a Flutter/Dart test-harness
      // race (the local package:test harness channel closing while the app
      // is still alive and healthy, so retry once before treating it as a
      // real failure.
      const maxAttempts = 2;
      var exitCode = 1;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        if (attempt > 1) {
          await Future.delayed(Duration(seconds: 2));
          print(
            '[${_timestamp()}] retrying $testName in 2 seconds (attempt $attempt/$maxAttempts) '
            'after a possible test-harness flake',
          );
        }

        _deleteStaleDatadogData();

        final args = ['test', 'integration_test/$baseName', '-d', device];
        // Opt-in: captures the flutter tool's own VM-service/test-harness
        // logs, which is what we need to confirm whether "did not complete"
        // failures are a lost connection to a still-alive app versus a real
        // app-side failure. Off by default since it's very noisy.
        if (results['verbose'] == true) {
          args.add('--verbose');
        }
        final clientToken = Platform.environment['DD_CLIENT_TOKEN'];
        if (clientToken != null) {
          args.addAll(['--dart-define', 'DD_CLIENT_TOKEN=$clientToken']);
        }
        final applicationId = Platform.environment['DD_APPLICATION_ID'];
        if (applicationId != null) {
          args.addAll(['--dart-define', 'DD_APPLICATION_ID=$applicationId']);
        }

        final startTime = DateTime.now();
        if (outputDir != null) {
          final outputFile = path.join(
            outputDir,
            '${packageName}_${device}_integration_$testName.xml',
          );
          exitCode = await _runTestWithJunit(
            [...args, '--machine'],
            outputFile,
            testName,
          );
        } else {
          exitCode = await _runTest(args, testName);
        }
        final elapsed = DateTime.now().difference(startTime);
        print(
          '[${_timestamp()}] $testName attempt $attempt finished with exit '
          'code $exitCode after ${elapsed.inMilliseconds}ms',
        );

        if (exitCode == 0) break;
      }

      if (exitCode != 0) {
        print('Command failed');
        exit(exitCode);
      }
    }
  }
}

Future<int> _runTest(List<String> args, String testName) async {
  print('[${_timestamp()}] flutter ${args.join(' ')}');
  final process = await Process.start(
    'flutter',
    args,
    runInShell: Platform.isWindows,
  );
  process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) => print('[${_timestamp()}] $line'));
  process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) => print('[${_timestamp()}] $line'));

  final exitCode = await process.exitCode;

  return exitCode;
}

Future<int> _runTestWithJunit(
  List<String> args,
  String outputFile,
  String testName,
) async {
  print(
    '[${_timestamp()}] flutter ${args.join(' ')} | tojunit --output $outputFile',
  );
  final testProcess = await Process.start(
    'flutter',
    args,
    runInShell: Platform.isWindows,
  );
  final tojunitProcess = await Process.start('tojunit', [
    '--output',
    outputFile,
  ], runInShell: Platform.isWindows);

  testProcess.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) => print('[${_timestamp()}] $line'));

  // If tojunit exits early (e.g. it can't parse the test output) it closes its
  // stdin, and writing to it after that throws - swallow that here so a tojunit
  // failure can never mask the real flutter test exit code below.
  final pipeDone = testProcess.stdout
      .pipe(tojunitProcess.stdin)
      .catchError((_) {});
  final testExitCode = await testProcess.exitCode;
  await pipeDone;
  final tojunitExitCode = await tojunitProcess.exitCode;
  if (tojunitExitCode != 0) {
    print(
      '[${_timestamp()}] tojunit failed with exit code $tojunitExitCode for $outputFile',
    );
  }

  return testExitCode;
}
