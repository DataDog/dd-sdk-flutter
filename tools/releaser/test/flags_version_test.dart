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

  void writeVersion(String value) {
    final file = File(path.join(fixture.path, 'lib/src/version.dart'));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync("const ddPackageVersion = '$value';\n");
  }

  setUp(() {
    fixture = Directory.systemTemp.createTempSync('flags-version-check-');
    File(path.join(fixture.path, 'pubspec.yaml')).writeAsStringSync(
      'name: datadog_flags\nversion: 1.2.0\n',
    );
    writeVersion('1.2.0');
  });
  tearDown(() => fixture.deleteSync(recursive: true));

  test('matching versions pass', () {
    expect(validateFlagsVersion(fixture.path, logger), isTrue);
  });

  test('missing, outdated, and duplicate constants fail', () {
    final file = File(path.join(fixture.path, 'lib/src/version.dart'));
    file.deleteSync();
    expect(validateFlagsVersion(fixture.path, logger), isFalse);
    writeVersion('1.1.0');
    expect(validateFlagsVersion(fixture.path, logger), isFalse);
    file.writeAsStringSync(
      "const ddPackageVersion = '1.2.0';\n"
      "const ddPackageVersion = '1.2.0';\n",
    );
    expect(validateFlagsVersion(fixture.path, logger), isFalse);
  });

  test('release updater cannot silently skip a missing constant', () async {
    File(path.join(fixture.path, 'lib/src/version.dart')).deleteSync();
    expect(await updateVersions(fixture.path, '2.0.0', logger, false), isFalse);
  });

  test('invalid manifest versions fail', () {
    for (final value in ['invalid', 'null', '42']) {
      File(path.join(fixture.path, 'pubspec.yaml')).writeAsStringSync(
        'name: datadog_flags\nversion: $value\n',
      );
      expect(validateFlagsVersion(fixture.path, logger), isFalse);
    }
  });

  test('other packages do not require a reporting constant', () {
    File(path.join(fixture.path, 'pubspec.yaml')).writeAsStringSync(
      'name: datadog_flags_flutter\nversion: 1.2.0\n',
    );
    File(path.join(fixture.path, 'lib/src/version.dart')).deleteSync();
    expect(validateFlagsVersion(fixture.path, logger), isTrue);
  });

  test('dry-run does not change either version', () async {
    expect(await updateVersions(fixture.path, '2.0.0', logger, true), isTrue);
    expect(validateFlagsVersion(fixture.path, logger), isTrue);
    expect(File(path.join(fixture.path, 'pubspec.yaml')).readAsStringSync(),
        contains('version: 1.2.0'));
  });

  test('release updates reach the actual VM and JavaScript request serializer',
      () async {
    final flagsRoot = path.absolute('../../packages/datadog_flags');
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
    File(path.join(fixture.path, 'request.dart')).writeAsStringSync('''
import 'dart:convert';
import 'package:datadog_flags/src/datadog_flags_config.dart';
import 'package:datadog_flags/src/evaluation_context.dart';
import 'package:datadog_flags/src/precompute_request.dart';
void main() {
  print(jsonEncode(PrecomputeRequest.fromContext(
    datadogConfig: DatadogFlagsConfig(
      clientToken: 'test-token', env: 'test', site: DatadogFlagsSite.us1,
      version: '99.0.0-app', service: 'test',
    ),
    evaluationContext: FlagsEvaluationContext(
      targetingKey: 'subject', attributes: {'sdk_version': '88.0.0-attribute'},
    ),
  ).toJson()));
}
''');

    Future<String> run(String executable, List<String> arguments) async {
      final result = await Process.run(executable, arguments,
          workingDirectory: fixture.path);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      return result.stdout as String;
    }

    void checkRequest(String output, String version) {
      final source = jsonDecode(output)['data']['attributes']['source'];
      expect(source, {'sdk_name': 'dd-sdk-dart', 'sdk_version': version});
    }

    await run(Platform.resolvedExecutable, ['pub', 'get', '--offline']);
    for (final version in ['1.2.0', '2.3.4', '3.0.0-beta.1+build.7']) {
      expect(
          await updateVersions(fixture.path, version, logger, false), isTrue);
      expect(validateFlagsVersion(fixture.path, logger), isTrue);
      checkRequest(
          await run(Platform.resolvedExecutable, ['run', 'request.dart']),
          version);
    }
    await run(Platform.resolvedExecutable,
        ['compile', 'js', 'request.dart', '-o', 'request.js']);
    checkRequest(await run('node', ['request.js']), '3.0.0-beta.1+build.7');
  }, timeout: Timeout(Duration(minutes: 3)));
}
