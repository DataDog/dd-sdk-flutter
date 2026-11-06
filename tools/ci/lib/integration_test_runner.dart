// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ci_helpers/integration_test_platform.dart';
import 'package:path/path.dart' as path;

/// Why a single `flutter test` attempt ended.
enum AttemptOutcome {
  passed,

  /// The tests ran and at least one failed. Never retried.
  testFailure,

  /// The process exited non-zero before any test started (app launch or
  /// VM-service connection failed).
  launchFailure,

  /// No test started before the startup timeout.
  startupTimeout,

  /// Tests started but the file did not finish before the hard cap.
  hardTimeout;

  /// Whether a retry might recover from this outcome.
  bool get isRetryable => this == launchFailure || this == startupTimeout;
}

/// Reads the `flutter test --machine` event stream line by line.
class TestEventTracker {
  final _testNames = <int, String>{};

  /// True once a non-loading test has started.
  bool started = false;

  /// Console-ready descriptions of errors and failed tests seen so far.
  final failures = <String>[];

  /// Feeds one line of `flutter test --machine` output. Returns a message to
  /// print for error and failed-test events, otherwise `null`.
  String? handleLine(String line) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      return null;
    }
    // `--machine` output is a stream of objects, with an array in the first line.
    if (decoded is! Map<String, dynamic>) return null;

    switch (decoded['type']) {
      case 'testStart':
        final test = decoded['test'];
        if (test is Map<String, dynamic>) {
          final name = test['name'];
          final id = test['id'];
          if (name is String && id is int) {
            _testNames[id] = name;
            if (!name.startsWith('loading ')) started = true;
          }
        }
      case 'error':
        final name = _testNames[decoded['testID']] ?? 'unknown test';
        final message =
            '[error] $name: ${decoded['error']}\n'
            '${decoded['stackTrace'] ?? ''}';
        failures.add(message);
        return message;
      case 'testDone':
        if (decoded['hidden'] == true || decoded['result'] == 'success') {
          return null;
        }
        final name = _testNames[decoded['testID']] ?? 'unknown test';
        final message = '[${decoded['result']}] $name';
        failures.add(message);
        return message;
    }
    return null;
  }
}

/// Runs integration test files one at a time, with a watchdog on app launch.
///
/// `flutter test` can hang with no output while installing or launching the app
/// on a simulator or emulator. A file whose first test hasn't started within
/// [startupTimeout] (or that exits non-zero before it does) is retried once
/// after [recoverDevice]. Real test failures are not retried.
class IntegrationTestRunner {
  IntegrationTestRunner({
    required this.platform,
    required this.packageName,
    this.outputDir,
    this.dartDefines = const [],
    this.extraArgs = const [],
    this.startupTimeout = const Duration(minutes: 5),
    this.hardTimeout = const Duration(minutes: 15),
  });

  final TestPlatform platform;
  final String packageName;

  /// Directory for the per-file junit XML and raw JSON event logs.
  final String? outputDir;
  final List<String> dartDefines;

  /// Extra arguments for `flutter test`.
  final List<String> extraArgs;
  final Duration startupTimeout;
  final Duration hardTimeout;

  /// Runs [testFile] and returns the final outcome.
  Future<AttemptOutcome> runFile(String testFile, String testName) async {
    // Only platforms that can recover their device are retried.
    final recoverDevice = platform.recoverDevice;
    final maxAttempts = recoverDevice == null ? 1 : 2;
    var outcome = AttemptOutcome.passed;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      outcome = await _runAttempt(testFile, testName, attempt);
      if (!outcome.isRetryable || attempt == maxAttempts) break;

      print(
        '[${_timestamp()}] $testName: ${outcome.name}; recovering device and '
        'retrying (attempt ${attempt + 1} of $maxAttempts)',
      );
      try {
        await recoverDevice!().timeout(_recoveryTimeout);
      } catch (e) {
        print('[${_timestamp()}] Device recovery failed: $e');
      }
    }
    return outcome;
  }

  Future<AttemptOutcome> _runAttempt(
    String testFile,
    String testName,
    int attempt,
  ) async {
    platform.beforeEachFile?.call();
    final args = [
      'test',
      testFile,
      '--machine',
      '-d',
      platform.device,
      ...extraArgs,
      for (final define in dartDefines) ...['--dart-define', define],
    ];
    print('[${_timestamp()}] flutter ${args.join(' ')} (attempt $attempt)');

    final baseName = '${packageName}_${platform.name}_integration_$testName';
    IOSink? jsonLog;
    Process? tojunit;
    if (outputDir case final dir?) {
      Directory(dir).createSync(recursive: true);
      jsonLog = File(
        path.join(dir, '$baseName.attempt$attempt.jsonl'),
      ).openWrite();
      tojunit = await Process.start('tojunit', [
        '--output',
        path.join(dir, '$baseName.xml'),
      ], runInShell: Platform.isWindows);
      tojunit.stdin.done.ignore();
      tojunit.stdout.drain<void>();
      tojunit.stderr.drain<void>();
    }

    final process = await Process.start(
      'flutter',
      args,
      runInShell: Platform.isWindows,
    );
    final tracker = TestEventTracker();
    final started = Completer<void>();

    // Lines from the tool's stdout go to the raw log, tojunit, and the tracker.
    // Writing to tojunit after it exits throws, so ignore its errors; they must
    // never mask the test result.
    final stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          jsonLog?.writeln(line);
          tojunit?.stdin.writeln(line);
          if (tracker.handleLine(line) case final message?) print(message);
          if (tracker.started && !started.isCompleted) started.complete();
        });
    final stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => print('[${_timestamp()}] $line'));
    final stdoutDone = stdoutSub.asFuture<void>();
    final stderrDone = stderrSub.asFuture<void>();

    final stopwatch = Stopwatch()..start();
    // Buffered stdout is handled before an exit is classified, so a test that
    // started and failed quickly isn't mistaken for a launch failure. Child
    // processes can hold the pipe open after flutter exits, so the wait is
    // bounded.
    final exited = process.exitCode.then((_) async {
      await stdoutDone.timeout(_drainTimeout, onTimeout: () {});
      return _Event.exited;
    });
    final first = await Future.any([
      exited,
      started.future.then((_) => _Event.started),
    ]).timeout(startupTimeout, onTimeout: () => _Event.timedOut);

    AttemptOutcome outcome;
    switch (first) {
      case _Event.timedOut:
        print(
          '[${_timestamp()}] $testName: no test started within '
          '${startupTimeout.inSeconds}s; killing flutter',
        );
        await _killProcessTree(process);
        outcome = AttemptOutcome.startupTimeout;
      case _Event.started:
        final second = await exited.timeout(
          hardTimeout - stopwatch.elapsed,
          onTimeout: () => _Event.timedOut,
        );
        if (second == _Event.timedOut) {
          print(
            '[${_timestamp()}] $testName: still running after '
            '${hardTimeout.inSeconds}s; killing flutter',
          );
          await _killProcessTree(process);
          outcome = AttemptOutcome.hardTimeout;
        } else {
          outcome = await _outcomeForExit(process, tracker);
        }
      case _Event.exited:
        outcome = await _outcomeForExit(process, tracker);
    }

    await Future.wait([
      stdoutDone,
      stderrDone,
    ]).timeout(_drainTimeout, onTimeout: () => []);
    // Stop listening so a child process holding a pipe open can't keep this
    // process alive.
    await Future.wait([stdoutSub.cancel(), stderrSub.cancel()]);
    await jsonLog?.close();
    if (tojunit != null) {
      await tojunit.stdin.close().catchError((_) {});
      final tojunitExit = await tojunit.exitCode;
      if (tojunitExit != 0) {
        print('[${_timestamp()}] tojunit exited with code $tojunitExit');
      }
    }

    print(
      '[${_timestamp()}] $testName attempt $attempt: ${outcome.name} after '
      '${stopwatch.elapsed.inSeconds}s',
    );
    return outcome;
  }

  Future<AttemptOutcome> _outcomeForExit(
    Process process,
    TestEventTracker tracker,
  ) async {
    final code = await process.exitCode;
    if (code == 0 && tracker.failures.isEmpty) return AttemptOutcome.passed;
    return tracker.started
        ? AttemptOutcome.testFailure
        : AttemptOutcome.launchFailure;
  }
}

enum _Event { exited, started, timedOut }

const _drainTimeout = Duration(seconds: 10);
const _recoveryTimeout = Duration(minutes: 10);

String _timestamp() => DateTime.now().toIso8601String();

/// Kills [process] and every descendant, since `flutter test` leaves
/// `xcodebuild`, `dart` and `adb` children that keep the pipes open.
Future<void> _killProcessTree(Process process) async {
  if (Platform.isWindows) {
    await Process.run('taskkill', ['/T', '/F', '/PID', '${process.pid}']);
    await process.exitCode;
    return;
  }
  final pids = await _descendants(process.pid);
  for (final pid in [...pids.reversed, process.pid]) {
    Process.killPid(pid, ProcessSignal.sigkill);
  }
  await process.exitCode;
}

Future<List<int>> _descendants(int pid) async {
  final result = await Process.run('pgrep', ['-P', '$pid']);
  final children = [
    for (final line in LineSplitter.split(result.stdout as String))
      ?int.tryParse(line.trim()),
  ];
  return [
    for (final child in children) ...[child, ...await _descendants(child)],
  ];
}
