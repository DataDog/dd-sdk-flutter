// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

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
    fixture = Directory.systemTemp.createTempSync('flags-version-check-');
    File(path.join(fixture.path, 'pubspec.yaml')).writeAsStringSync(
      'name: datadog_flags\nversion: 1.2.0\n',
    );
    File(path.join(fixture.path, 'lib/src/version.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync("const ddPackageVersion = '1.2.0';\n");
  });
  tearDown(() => fixture.deleteSync(recursive: true));

  test('checked-in Flags version matches its package', () {
    expect(
        validateFlagsVersion('../../packages/datadog_flags', logger), isTrue);
  });

  test('missing, stale, and duplicate constants fail validation', () {
    final file = File(path.join(fixture.path, 'lib/src/version.dart'));
    file.deleteSync();
    expect(validateFlagsVersion(fixture.path, logger), isFalse);
    file.writeAsStringSync("const ddPackageVersion = '1.1.0';\n");
    expect(validateFlagsVersion(fixture.path, logger), isFalse);
    file.writeAsStringSync(
      "const ddPackageVersion = '1.2.0';\nconst ddPackageVersion = '1.2.0';\n",
    );
    expect(validateFlagsVersion(fixture.path, logger), isFalse);
  });

  test('existing updater keeps stable and prerelease versions in sync',
      () async {
    for (final version in ['2.3.4', '3.0.0-beta.1+build.7']) {
      expect(
          await updateVersions(fixture.path, version, logger, false), isTrue);
      expect(validateFlagsVersion(fixture.path, logger), isTrue);
      expect(
          File(path.join(fixture.path, 'lib/src/version.dart'))
              .readAsStringSync(),
          contains("'$version'"));
    }
  });

  test('other packages do not require a reporting constant', () {
    File(path.join(fixture.path, 'pubspec.yaml')).writeAsStringSync(
      'name: datadog_flags_flutter\nversion: 1.2.0\n',
    );
    File(path.join(fixture.path, 'lib/src/version.dart')).deleteSync();
    expect(validateFlagsVersion(fixture.path, logger), isTrue);
  });
}
