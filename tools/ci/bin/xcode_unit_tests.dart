// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;

// Runs the example app's Xcode unit tests for the current melos package.
//
// Writes an xcresult bundle to `.build/xcresult` and a junit report to
// `.build/test-results`, both named after the package and platform. Parallel
// testing is off and per-test timeouts are on, so a hung test fails by name
// instead of hanging the job.
//
// Run through `melos exec`, which provides `MELOS_ROOT_PATH` and
// `MELOS_PACKAGE_NAME`.
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'platform',
      abbr: 'p',
      mandatory: true,
      allowed: ['ios', 'macos'],
      help: 'Platform of the example app to test.',
    )
    ..addOption(
      'destination',
      abbr: 'd',
      mandatory: true,
      help: 'The xcodebuild -destination to run the tests on.',
    );
  final results = parser.parse(arguments);
  final platform = results['platform'] as String;

  final rootPath = Platform.environment['MELOS_ROOT_PATH'];
  final packageName = Platform.environment['MELOS_PACKAGE_NAME'];
  if (rootPath == null || packageName == null) {
    print('MELOS_ROOT_PATH and MELOS_PACKAGE_NAME must be set; run this '
        'through `melos exec`.');
    exit(64);
  }

  final xcresultDir = Directory(path.join(rootPath, '.build', 'xcresult'))
    ..createSync(recursive: true);
  final junitDir = Directory(path.join(rootPath, '.build', 'test-results'))
    ..createSync(recursive: true);
  final resultBundle = Directory(
    path.join(xcresultDir.path, '$packageName-$platform.xcresult'),
  );
  // xcodebuild refuses to overwrite an existing result bundle.
  if (resultBundle.existsSync()) resultBundle.deleteSync(recursive: true);

  final xcodebuild = await Process.start('xcodebuild', [
    'test',
    '-workspace',
    'example/$platform/Runner.xcworkspace',
    '-scheme',
    'Runner',
    '-destination',
    results['destination'] as String,
    '-parallel-testing-enabled',
    'NO',
    '-test-timeouts-enabled',
    'YES',
    '-default-test-execution-time-allowance',
    '60',
    '-maximum-test-execution-time-allowance',
    '300',
    '-resultBundlePath',
    resultBundle.path,
  ]);
  final xcbeautify = await Process.start('xcbeautify', [
    '--report',
    'junit',
    '--report-path',
    junitDir.path,
    '--junit-report-filename',
    '${packageName}_${platform}_xcode.xml',
  ]);

  final done = Future.wait([
    xcodebuild.stdout.pipe(xcbeautify.stdin),
    xcodebuild.stderr.forEach(stderr.add),
    xcbeautify.stdout.forEach(stdout.add),
    xcbeautify.stderr.forEach(stderr.add),
  ]);
  final exitCode = await xcodebuild.exitCode;
  await done;
  await xcbeautify.exitCode;
  exit(exitCode);
}
