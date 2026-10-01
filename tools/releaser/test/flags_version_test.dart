// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:releaser/flags_version.dart';
import 'package:releaser/version_updater.dart';
import 'package:test/test.dart';

void main() {
  final logger = Logger('FlagsVersionTest');
  late Directory fixture;

  setUp(() {
    fixture = Directory.systemTemp.createTempSync('flags-version-');
    File(path.join(fixture.path, 'pubspec.yaml')).writeAsStringSync(
      'name: datadog_flags\nversion: 1.2.0\n',
    );
  });
  tearDown(() => fixture.deleteSync(recursive: true));

  test('missing and stale generated files block packaging', () {
    expect(syncFlagsVersion(fixture.path, logger, check: true), isFalse);
    expect(syncFlagsVersion(fixture.path, logger), isTrue);
    expect(syncFlagsVersion(fixture.path, logger, check: true), isTrue);
    File(path.join(fixture.path, 'pubspec.yaml')).writeAsStringSync(
      'name: datadog_flags\nversion: 1.3.0\n',
    );
    expect(syncFlagsVersion(fixture.path, logger, check: true), isFalse);
    expect(syncFlagsVersion(fixture.path, logger), isTrue);
    expect(syncFlagsVersion(fixture.path, logger, check: true), isTrue);
  });

  test('release update repairs missing metadata automatically', () async {
    expect(await updateVersions(fixture.path, '2.0.0', logger, false), isTrue);
    expect(syncFlagsVersion(fixture.path, logger, check: true), isTrue);
    expect(
        File(path.join(fixture.path, 'lib/src/version.dart'))
            .readAsStringSync(),
        contains("ddPackageVersion = '2.0.0'"));
  });

  test('dry-run does not create reporting metadata or change the manifest',
      () async {
    expect(await updateVersions(fixture.path, '2.0.0', logger, true), isTrue);
    expect(File(path.join(fixture.path, 'lib/src/version.dart')).existsSync(),
        isFalse);
    expect(File(path.join(fixture.path, 'pubspec.yaml')).readAsStringSync(),
        contains('version: 1.2.0'));
  });

  test('malformed or missing canonical versions fail', () {
    for (final version in ['invalid', 'null', '42']) {
      File(path.join(fixture.path, 'pubspec.yaml')).writeAsStringSync(
        'name: datadog_flags\nversion: $version\n',
      );
      expect(syncFlagsVersion(fixture.path, logger), isFalse);
    }
  });

  test('non-Flags packages do not need a generated version file', () {
    File(path.join(fixture.path, 'pubspec.yaml')).writeAsStringSync(
      'name: datadog_flags_flutter\nversion: 1.0.0\n',
    );
    expect(syncFlagsVersion(fixture.path, logger, check: true), isTrue);
  });

  test('release versions reach the actual Precompute serializer on VM and JS',
      () async {
    final flagsRoot =
        path.normalize(path.absolute('../../packages/datadog_flags'));
    for (final entry
        in Directory(path.join(flagsRoot, 'lib')).listSync(recursive: true)) {
      if (entry is File) {
        final output = File(path.join(
            fixture.path, path.relative(entry.path, from: flagsRoot)));
        output.parent.createSync(recursive: true);
        entry.copySync(output.path);
      }
    }
    File(path.join(flagsRoot, 'pubspec.yaml'))
        .copySync(path.join(fixture.path, 'pubspec.yaml'));
    File(path.join(fixture.path, 'request.dart'))
        .writeAsStringSync(_requestProgram);

    Future<ProcessResult> run(String executable, List<String> arguments) async {
      final result = await Process.run(executable, arguments,
          workingDirectory: fixture.path);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      return result;
    }

    await run(Platform.resolvedExecutable, ['pub', 'get']);
    void checkRequest(String output, String version) {
      final attributes = jsonDecode(output)['data']['attributes'];
      expect(attributes['source'],
          {'sdk_name': 'dd-sdk-dart', 'sdk_version': version});
      expect(attributes['subject']['targeting_key'], 'athlete-123');
      expect(attributes['env']['dd_env'], 'prod');
    }

    for (final version in ['1.2.0', '2.3.4', '3.0.0-beta.1+build.7']) {
      expect(
          await updateVersions(fixture.path, version, logger, false), isTrue);
      expect(syncFlagsVersion(fixture.path, logger, check: true), isTrue);
      final request =
          await run(Platform.resolvedExecutable, ['run', 'request.dart']);
      checkRequest(request.stdout as String, version);
    }

    // Dart web uses the same shipped source. No package or Git lookup occurs
    // when the compiled application constructs the request.
    await run(Platform.resolvedExecutable,
        ['compile', 'js', 'request.dart', '-o', 'request.js']);
    final webRequest = await run('node', ['request.js']);
    checkRequest(webRequest.stdout as String, '3.0.0-beta.1+build.7');
  }, timeout: Timeout(Duration(minutes: 3)));
}

const _requestProgram = '''
import 'dart:convert';
import 'package:datadog_flags/src/datadog_flags_config.dart';
import 'package:datadog_flags/src/evaluation_context.dart';
import 'package:datadog_flags/src/precompute_request.dart';

void main() {
  final request = PrecomputeRequest.fromContext(
    datadogConfig: DatadogFlagsConfig(
      clientToken: 'public-token', env: 'prod', site: DatadogFlagsSite.us1,
      version: '99.99.99-app', service: 'customer-service',
    ),
    evaluationContext: FlagsEvaluationContext(
      targetingKey: 'athlete-123',
      attributes: {'sdk_version': '88.88.88-attribute'},
    ),
  );
  print(jsonEncode(request.toJson()));
}
''';
