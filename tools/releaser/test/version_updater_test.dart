// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:releaser/version_updater.dart';

void main() {
  late Directory root;
  final logger = Logger('version_updater_test');

  setUp(() async {
    root = await Directory.systemTemp.createTemp('version_updater_test_');
  });

  tearDown(() => root.delete(recursive: true));

  test('creates the file with a 4-column header when missing', () async {
    final file = File(p.join(root.path, 'NATIVE_SDK_VERSIONS.md'));

    await updateNativeSdkVersionsMd(
      file,
      '3.5.0',
      logger,
      false,
      iosVersion: '3.15.0',
      androidVersion: '3.12.1',
      cppVersion: '1.4.0',
    );

    expect(
      file.readAsStringSync(),
      '| Flutter | iOS SDK | Android SDK | C++ SDK |\n'
      '|---------|---------|-------------|---------|\n'
      '| 3.5.0 | 3.15.0 | 3.12.1 | 1.4.0 |\n',
    );
  });

  test('renders a dash for any SDK not provided', () async {
    final file = File(p.join(root.path, 'NATIVE_SDK_VERSIONS.md'));

    await updateNativeSdkVersionsMd(file, '1.0.0', logger, false);

    expect(file.readAsStringSync(), contains('| 1.0.0 | - | - | - |'));
  });

  test('inserts a new row newest-first, leaving existing rows alone', () async {
    final file = File(p.join(root.path, 'NATIVE_SDK_VERSIONS.md'))
      ..writeAsStringSync(
        '| Flutter | iOS SDK | Android SDK | C++ SDK |\n'
        '|---------|---------|-------------|---------|\n'
        '| 3.4.0 | 3.13.0 | 3.11.0 | - |\n',
      );

    await updateNativeSdkVersionsMd(
      file,
      '3.5.0',
      logger,
      false,
      iosVersion: '3.15.0',
      androidVersion: '3.12.1',
    );

    expect(
      file.readAsStringSync(),
      '| Flutter | iOS SDK | Android SDK | C++ SDK |\n'
      '|---------|---------|-------------|---------|\n'
      '| 3.5.0 | 3.15.0 | 3.12.1 | - |\n'
      '| 3.4.0 | 3.13.0 | 3.11.0 | - |\n',
    );
  });

  test('skips a version that already has a row', () async {
    const original =
        '| Flutter | iOS SDK | Android SDK | C++ SDK |\n'
        '|---------|---------|-------------|---------|\n'
        '| 3.5.0 | 3.15.0 | 3.12.1 | - |\n';
    final file = File(p.join(root.path, 'NATIVE_SDK_VERSIONS.md'))
      ..writeAsStringSync(original);

    await updateNativeSdkVersionsMd(
      file,
      '3.5.0',
      logger,
      false,
      iosVersion: '9.9.9',
    );

    expect(file.readAsStringSync(), original);
  });

  group('updateReadmeSdkTable', () {
    test(
      'rewrites the table between the markers, C++ column included',
      () async {
        final file = File(p.join(root.path, 'README.md'))
          ..writeAsStringSync('''
## Current Datadog SDK Versions

[//]: # (SDK Table)

| iOS SDK | Android SDK | Browser SDK |
| :-----: | :---------: | :---------: |
| 3.13.0 | 3.11.0 | 7.x.x |

[//]: # (End SDK Table)

### iOS
''');

        await updateReadmeSdkTable(
          file,
          logger,
          false,
          iosVersion: '3.15.0',
          androidVersion: '3.12.1',
          cppVersion: '1.4.0',
        );

        expect(file.readAsStringSync(), '''
## Current Datadog SDK Versions

[//]: # (SDK Table)

| iOS SDK | Android SDK | C++ SDK | Browser SDK |
| :-----: | :---------: | :-----: | :---------: |
| 3.15.0 | 3.12.1 | 1.4.0 | 7.x.x |

[//]: # (End SDK Table)

### iOS
''');
      },
    );

    test('renders a dash for any SDK not provided', () async {
      final file = File(p.join(root.path, 'README.md'))
        ..writeAsStringSync(
          '[//]: # (SDK Table)\n\nold\n\n[//]: # (End SDK Table)\n',
        );

      await updateReadmeSdkTable(file, logger, false, iosVersion: '3.15.0');

      expect(file.readAsStringSync(), contains('| 3.15.0 | - | - | 7.x.x |'));
    });

    test('is a no-op when the file has no SDK table markers', () async {
      const original = '# datadog_dio\n\nNo SDK table here.\n';
      final file = File(p.join(root.path, 'README.md'))
        ..writeAsStringSync(original);

      await updateReadmeSdkTable(file, logger, false, iosVersion: '3.15.0');

      expect(file.readAsStringSync(), original);
    });

    test('is a no-op when the file does not exist', () async {
      final file = File(p.join(root.path, 'does_not_exist.md'));

      await updateReadmeSdkTable(file, logger, false, iosVersion: '3.15.0');

      expect(file.existsSync(), isFalse);
    });
  });
}
