// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:releaser/native_sdk.dart';
import 'package:releaser/trigger_context.dart';

const _iosPodspec = '''
Pod::Spec.new do |s|
  s.name             = 'datadog_flutter_plugin_ios'
  s.dependency 'Flutter'
  s.dependency 'DatadogCore', '~> 3'
  s.dependency 'DatadogLogs', '~> 3'
end
''';

const _androidGradle = '''
buildscript {
    ext.kotlin_version = "2.2.20"
    ext.datadog_version = "3.11.0"
}
''';

const _windowsCMakeLists = '''
FetchContent_Declare(dd-sdk-cpp
  GIT_REPOSITORY https://github.com/DataDog/dd-sdk-cpp.git
  GIT_TAG        develop
  GIT_CONFIG     core.longpaths=true)
''';

const _linuxCMakeLists = '''
FetchContent_Declare(dd-sdk-cpp
  GIT_REPOSITORY https://github.com/DataDog/dd-sdk-cpp.git
  GIT_TAG        develop)
''';

const _packageSwift = '''
let package = Package(
    name: "datadog_session_replay",
    dependencies: [
        .package(url: "https://github.com/Datadog/dd-sdk-ios.git", from: "3.0.0")
    ]
)
''';

void main() {
  group('reading current pins', () {
    test('readIosPodspecPin finds the shared Datadog pod constraint', () {
      expect(readIosPodspecPin(_iosPodspec), '~> 3');
    });

    test('readIosPodspecPin returns null with no Datadog dependency', () {
      expect(readIosPodspecPin("s.dependency 'Flutter'"), isNull);
    });

    test('readAndroidGradlePin finds ext.datadog_version', () {
      expect(readAndroidGradlePin(_androidGradle), '3.11.0');
    });

    test('readAndroidGradlePin returns null with no datadog_version', () {
      expect(readAndroidGradlePin('ext.kotlin_version = "2.2.20"'), isNull);
    });

    test('readCppCMakePin finds GIT_TAG regardless of trailing syntax', () {
      expect(readCppCMakePin(_windowsCMakeLists), 'develop');
      expect(readCppCMakePin(_linuxCMakeLists), 'develop');
    });

    test(
      'readCppCMakePin prefers the trailing tag comment over a pinned SHA',
      () {
        const pinned = '''
FetchContent_Declare(dd-sdk-cpp
  GIT_REPOSITORY https://github.com/DataDog/dd-sdk-cpp.git
  GIT_TAG        a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2)  # v1.4.0
''';
        // The tag, not the opaque SHA -- that's what a freshly-resolved
        // target tag needs to compare against to detect "no change".
        expect(readCppCMakePin(pinned), 'v1.4.0');
      },
    );

    test('readCppCMakePin returns null with no GIT_TAG', () {
      expect(readCppCMakePin('FetchContent_Declare(something_else)'), isNull);
    });

    test('readCppCMakePin ignores a GIT_TAG belonging to another '
        'FetchContent_Declare that appears before dd-sdk-cpp', () {
      const content = '''
FetchContent_Declare(some_other_dep
  GIT_REPOSITORY https://github.com/example/some_other_dep.git
  GIT_TAG        v9.9.9)
FetchContent_MakeAvailable(some_other_dep)

FetchContent_Declare(dd-sdk-cpp
  GIT_REPOSITORY https://github.com/DataDog/dd-sdk-cpp.git
  GIT_TAG        develop)
''';
      expect(readCppCMakePin(content), 'develop');
    });

    test('readSpmPin finds the dd-sdk-ios dependency spec', () {
      expect(readSpmPin(_packageSwift), 'from: "3.0.0"');
    });

    test('readSpmPin returns null with no dd-sdk-ios dependency', () {
      expect(
        readSpmPin(
          '.package(url: "https://github.com/other/pkg.git", from: "1.0.0")',
        ),
        isNull,
      );
    });
  });

  group('resolveNativeDependencyFiles', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('native_sdk_test_');
    });

    tearDown(() => root.delete(recursive: true));

    void write(String relativePath, String contents) {
      final file = File(p.join(root.path, relativePath));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(contents);
    }

    test('finds all native dependency files when present', () {
      write('ios/datadog_flutter_plugin_ios.podspec', _iosPodspec);
      write('ios/datadog_flutter_plugin_ios/Package.swift', _packageSwift);
      write('android/build.gradle', _androidGradle);
      write('windows/CMakeLists.txt', _windowsCMakeLists);
      write('linux/CMakeLists.txt', _linuxCMakeLists);

      final files = resolveNativeDependencyFiles(root.path);

      expect(files.iosPodspec, isNotNull);
      expect(files.iosSpmManifest, isNotNull);
      expect(files.androidGradle, isNotNull);
      expect(files.cppCMakeLists, hasLength(2));
      expect(files.isEmpty, isFalse);
    });

    test(
      'finds a Package.swift even when there is no podspec alongside it',
      () {
        write('ios/datadog_flutter_plugin_ios/Package.swift', _packageSwift);

        final files = resolveNativeDependencyFiles(root.path);

        expect(files.iosPodspec, isNull);
        expect(files.iosSpmManifest, isNotNull);
      },
    );

    test('ignores a Package.swift with no dd-sdk-ios dependency', () {
      write(
        'ios/some_other_plugin/Package.swift',
        '.package(url: "https://github.com/other/pkg.git", from: "1.0.0")',
      );

      final files = resolveNativeDependencyFiles(root.path);

      expect(files.iosSpmManifest, isNull);
    });

    test('ignores a build.gradle with no Datadog dependency', () {
      write('android/build.gradle', 'ext.kotlin_version = "2.2.20"');

      final files = resolveNativeDependencyFiles(root.path);

      expect(files.androidGradle, isNull);
      expect(files.isEmpty, isTrue);
    });

    test('ignores a podspec with no Datadog dependency', () {
      write('ios/some_other_plugin.podspec', "s.dependency 'Flutter'");

      final files = resolveNativeDependencyFiles(root.path);

      expect(files.iosPodspec, isNull);
    });

    test(
      'a pure-Dart package with no ios/android/windows/linux dirs is empty',
      () {
        final files = resolveNativeDependencyFiles(root.path);
        expect(files.isEmpty, isTrue);
      },
    );
  });

  group('resolveNativeSdkTarget', () {
    test(
      'an explicit override wins once confirmed to be a real release',
      () async {
        final target = await resolveNativeSdkTarget(
          trigger: TriggerContext.mainline,
          override: '3.12.0',
          fetchLatest: () => Future.value('9.9.9'),
          releaseExists: (version) async => version == '3.12.0',
        );
        expect(target, '3.12.0');
      },
    );

    test('an override that is not a real release fails loudly', () async {
      await expectLater(
        resolveNativeSdkTarget(
          trigger: TriggerContext.mainline,
          override: 'not-a-real-version',
          fetchLatest: () => Future.value('9.9.9'),
          releaseExists: (version) async => false,
        ),
        throwsStateError,
      );
    });

    test('on a patch branch, no override means no change (and no '
        'releaseExists call)', () async {
      final target = await resolveNativeSdkTarget(
        trigger: TriggerContext.patch,
        override: null,
        fetchLatest: () => Future.value('9.9.9'),
        releaseExists: (version) =>
            throw StateError('should not be called with no override'),
      );
      expect(target, isNull);
    });

    test('a patch-branch override still applies', () async {
      final target = await resolveNativeSdkTarget(
        trigger: TriggerContext.patch,
        override: '3.12.1',
        fetchLatest: () => Future.value('9.9.9'),
        releaseExists: (version) async => true,
      );
      expect(target, '3.12.1');
    });

    test(
      'on develop, no override means latest (and no releaseExists call)',
      () async {
        final target = await resolveNativeSdkTarget(
          trigger: TriggerContext.mainline,
          override: null,
          fetchLatest: () => Future.value('3.13.0'),
          releaseExists: (version) =>
              throw StateError('should not be called with no override'),
        );
        expect(target, '3.13.0');
      },
    );

    test('on a pre-release branch, no override also means latest', () async {
      final target = await resolveNativeSdkTarget(
        trigger: TriggerContext.preRelease,
        override: null,
        fetchLatest: () => Future.value('3.13.0'),
        releaseExists: (version) =>
            throw StateError('should not be called with no override'),
      );
      expect(target, '3.13.0');
    });
  });

  group('NativeSdkDelta.isChange', () {
    test('is false when the target matches the current pin', () {
      final delta = NativeSdkDelta(
        sdk: NativeSdk.android,
        pins: [(source: 'build.gradle', value: '3.11.0')],
        targetVersion: '3.11.0',
      );
      expect(delta.isChange, isFalse);
    });

    test('is false when there is no target (no change)', () {
      final delta = NativeSdkDelta(
        sdk: NativeSdk.android,
        pins: [(source: 'build.gradle', value: '3.11.0')],
        targetVersion: null,
      );
      expect(delta.isChange, isFalse);
    });

    test('is true when the target differs from the current pin', () {
      final delta = NativeSdkDelta(
        sdk: NativeSdk.android,
        pins: [(source: 'build.gradle', value: '3.11.0')],
        targetVersion: '3.12.0',
      );
      expect(delta.isChange, isTrue);
    });

    test('is true when the podspec matches but the SPM pin lags behind -- '
        'both must track the same version', () {
      final delta = NativeSdkDelta(
        sdk: NativeSdk.ios,
        pins: [
          (source: 'podspec', value: '3.12.0'),
          (source: 'Package.swift', value: '3.0.0'),
        ],
        targetVersion: '3.12.0',
      );
      expect(delta.isChange, isTrue);
    });

    test('is true when the SPM pin matches but the podspec lags behind', () {
      final delta = NativeSdkDelta(
        sdk: NativeSdk.ios,
        pins: [
          (source: 'podspec', value: '~> 3'),
          (source: 'Package.swift', value: '3.12.0'),
        ],
        targetVersion: '3.12.0',
      );
      expect(delta.isChange, isTrue);
    });

    test('is false when both the podspec and SPM pin match the target', () {
      final delta = NativeSdkDelta(
        sdk: NativeSdk.ios,
        pins: [
          (source: 'podspec', value: '3.12.0'),
          (source: 'Package.swift', value: '3.12.0'),
        ],
        targetVersion: '3.12.0',
      );
      expect(delta.isChange, isFalse);
    });

    test('a branch-tracking SPM pin always counts as needing a change', () {
      final delta = NativeSdkDelta(
        sdk: NativeSdk.ios,
        pins: [
          (source: 'podspec', value: '3.12.0'),
          (source: 'Package.swift', value: 'branch: "develop"'),
        ],
        targetVersion: '3.12.0',
      );
      expect(delta.isChange, isTrue);
    });

    test('is true when the first pin matches but an additional pin '
        '(e.g. a second CMakeLists) lags behind', () {
      final delta = NativeSdkDelta(
        sdk: NativeSdk.cpp,
        pins: [
          (source: 'windows/CMakeLists.txt', value: 'v1.4.0'),
          (source: 'linux/CMakeLists.txt', value: 'develop'),
        ],
        targetVersion: 'v1.4.0',
      );
      expect(delta.isChange, isTrue);
    });

    test('is false when the first pin and every additional pin match', () {
      final delta = NativeSdkDelta(
        sdk: NativeSdk.cpp,
        pins: [
          (source: 'windows/CMakeLists.txt', value: 'v1.4.0'),
          (source: 'linux/CMakeLists.txt', value: 'v1.4.0'),
        ],
        targetVersion: 'v1.4.0',
      );
      expect(delta.isChange, isFalse);
    });
  });

  group('spmPinForComparison', () {
    test('extracts the bare version literal from a version-pinned spec', () {
      expect(spmPinForComparison('from: "3.0.0"'), '3.0.0');
      expect(spmPinForComparison('exact: "3.12.0"'), '3.12.0');
    });

    test('returns a branch-tracking spec unchanged', () {
      expect(spmPinForComparison('branch: "develop"'), 'branch: "develop"');
    });
  });
}
