// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:releaser/cmake_util.dart';

const _sha = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

void main() {
  late Directory root;
  final logger = Logger('cmake_util_test');

  setUp(() async {
    root = await Directory.systemTemp.createTemp('cmake_util_test_');
  });

  tearDown(() => root.delete(recursive: true));

  test('pins GIT_TAG to the SHA, keeping the tag as a trailing comment, '
      'preserving a trailing GIT_CONFIG line', () async {
    final file = File(p.join(root.path, 'CMakeLists.txt'));
    await file.writeAsString('''
FetchContent_Declare(dd-sdk-cpp
  GIT_REPOSITORY https://github.com/DataDog/dd-sdk-cpp.git
  GIT_TAG        develop
  GIT_CONFIG     core.longpaths=true)
''');

    await pinCppVersion(file, 'v1.4.0', _sha, logger, false);

    final contents = await file.readAsString();
    expect(contents, contains('GIT_TAG        $_sha  # v1.4.0'));
    expect(contents, contains('GIT_CONFIG     core.longpaths=true)'));
    expect(contents, isNot(contains('develop')));
  });

  test(
    'keeps the closing paren before the comment when it is on the same line',
    () async {
      final file = File(p.join(root.path, 'CMakeLists.txt'));
      await file.writeAsString('''
FetchContent_Declare(dd-sdk-cpp
  GIT_REPOSITORY https://github.com/DataDog/dd-sdk-cpp.git
  GIT_TAG        develop)
''');

      await pinCppVersion(file, 'v1.4.0', _sha, logger, false);

      final contents = await file.readAsString();
      // The `)` must stay *before* the comment -- moving it after would
      // comment out the closing paren and break FetchContent_Declare(...).
      expect(contents, contains('GIT_TAG        $_sha)  # v1.4.0'));
    },
  );

  test(
    're-pinning replaces both the old SHA and the old comment cleanly',
    () async {
      final file = File(p.join(root.path, 'CMakeLists.txt'));
      await file.writeAsString(
        'FetchContent_Declare(dd-sdk-cpp\n'
        '  GIT_TAG        oldsha1234567890oldsha1234567890oldsha1)  # v1.3.0\n',
      );

      await pinCppVersion(file, 'v1.4.0', _sha, logger, false);

      final contents = await file.readAsString();
      expect(contents, contains('  GIT_TAG        $_sha)  # v1.4.0'));
    },
  );

  test('dry run leaves the file untouched', () async {
    final file = File(p.join(root.path, 'CMakeLists.txt'));
    const original =
        'FetchContent_Declare(dd-sdk-cpp\n  GIT_TAG        develop)\n';
    await file.writeAsString(original);

    await pinCppVersion(file, 'v1.4.0', _sha, logger, true);

    expect(await file.readAsString(), original);
  });

  test('a second FetchContent_Declare for a different dependency keeps its '
      'own GIT_TAG untouched', () async {
    final file = File(p.join(root.path, 'CMakeLists.txt'));
    await file.writeAsString('''
FetchContent_Declare(dd-sdk-cpp
  GIT_REPOSITORY https://github.com/DataDog/dd-sdk-cpp.git
  GIT_TAG        develop)
FetchContent_MakeAvailable(dd-sdk-cpp)

FetchContent_Declare(some_other_dep
  GIT_REPOSITORY https://github.com/example/some_other_dep.git
  GIT_TAG        v9.9.9)
FetchContent_MakeAvailable(some_other_dep)
''');

    await pinCppVersion(file, 'v1.4.0', _sha, logger, false);

    final contents = await file.readAsString();
    expect(contents, contains('GIT_TAG        $_sha)  # v1.4.0'));
    expect(contents, contains('GIT_TAG        v9.9.9)'));
  });

  test('handles a declaration written on a single line', () async {
    final file = File(p.join(root.path, 'CMakeLists.txt'));
    await file.writeAsString(
      'FetchContent_Declare(dd-sdk-cpp '
      'GIT_REPOSITORY https://github.com/DataDog/dd-sdk-cpp.git '
      'GIT_TAG develop)\n',
    );

    await pinCppVersion(file, 'v1.4.0', _sha, logger, false);

    expect(
      (await file.readAsString()).trim(),
      'FetchContent_Declare(dd-sdk-cpp '
      'GIT_REPOSITORY https://github.com/DataDog/dd-sdk-cpp.git '
      'GIT_TAG $_sha)  # v1.4.0',
    );
  });

  test('re-pinning replaces the previous annotation rather than stacking '
      'another one', () async {
    final file = File(p.join(root.path, 'CMakeLists.txt'));
    await file.writeAsString(
      'FetchContent_Declare(dd-sdk-cpp\n  GIT_TAG        $_sha)  # v1.4.0\n',
    );

    await pinCppVersion(file, 'v1.5.0', _sha, logger, false);

    final contents = await file.readAsString();
    expect(contents, contains('GIT_TAG        $_sha)  # v1.5.0'));
    expect(contents, isNot(contains('v1.4.0')));
  });

  test('leaves everything else in the file untouched', () async {
    final file = File(p.join(root.path, 'CMakeLists.txt'));
    await file.writeAsString('''
cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "datadog_flutter_plugin_desktop")

FetchContent_Declare(dd-sdk-cpp
  GIT_REPOSITORY https://github.com/DataDog/dd-sdk-cpp.git
  GIT_TAG        develop)
FetchContent_MakeAvailable(dd-sdk-cpp)
''');

    await pinCppVersion(file, 'v1.4.0', _sha, logger, false);

    final contents = await file.readAsString();
    expect(contents, contains('cmake_minimum_required(VERSION 3.14)'));
    expect(contents, contains('FetchContent_MakeAvailable(dd-sdk-cpp)'));
  });

  group('currentGitTag', () {
    test('reads the floating ref as-is', () {
      expect(
        currentGitTag('''
FetchContent_Declare(dd-sdk-cpp
  GIT_REPOSITORY https://github.com/DataDog/dd-sdk-cpp.git
  GIT_TAG        develop)
'''),
        'develop',
      );
    });

    test('reads a previously-pinned SHA, ignoring its trailing comment', () {
      expect(
        currentGitTag('''
FetchContent_Declare(dd-sdk-cpp
  GIT_REPOSITORY https://github.com/DataDog/dd-sdk-cpp.git
  GIT_TAG        $_sha)  # v1.4.0
'''),
        _sha,
      );
    });

    test('is null with no dd-sdk-cpp declaration at all', () {
      expect(currentGitTag('cmake_minimum_required(VERSION 3.14)'), isNull);
    });

    test("ignores another dependency's GIT_TAG outside the block", () {
      expect(
        currentGitTag('''
FetchContent_Declare(some_other_dep
  GIT_TAG v9.9.9)
'''),
        isNull,
      );
    });
  });
}
