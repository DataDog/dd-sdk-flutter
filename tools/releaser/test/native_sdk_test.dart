// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:releaser/native_sdk.dart';
import 'package:releaser/trigger_context.dart';
import 'package:releaser/version_bump.dart';

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

    test('ignores a CMakeLists.txt whose only GIT_TAG belongs to a different '
        'FetchContent_Declare', () {
      write('windows/CMakeLists.txt', '''
FetchContent_Declare(some_other_dep
  GIT_REPOSITORY https://github.com/example/some_other_dep.git
  GIT_TAG        v9.9.9)
''');

      final files = resolveNativeDependencyFiles(root.path);

      expect(files.cppCMakeLists, isEmpty);
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

  group('current*Declaration -- display strings, not resolvable versions', () {
    // Pure content-parsing functions -- no filesystem needed. The caller
    // (release_plan.dart) is responsible for sourcing that content from a
    // past release's git history, not the working tree; see
    // NativeSdkDelta.currentDeclaration.

    test('iOS prefers the podspec constraint over Package.swift', () {
      expect(
        currentIosDeclaration(
          podspecContent: _iosPodspec,
          spmContent: _packageSwift,
        ),
        '~> 3',
      );
    });

    test('iOS falls back to the Package.swift version arg with no podspec', () {
      expect(currentIosDeclaration(spmContent: _packageSwift), 'from: "3.0.0"');
    });

    test('iOS is null with neither content', () {
      expect(currentIosDeclaration(), isNull);
    });

    test('Android reads the current ext.datadog_version verbatim', () {
      expect(currentAndroidDeclaration(_androidGradle), '3.11.0');
    });

    test('Android is null with no content', () {
      expect(currentAndroidDeclaration(null), isNull);
    });

    test('C++ reads the floating GIT_TAG as-is, not resolved to a version', () {
      expect(currentCppDeclaration(_windowsCMakeLists), 'develop');
    });

    test('C++ is null with no content', () {
      expect(currentCppDeclaration(null), isNull);
    });
  });

  group('normalizeVersion', () {
    test('strips a CocoaPods constraint operator', () {
      expect(normalizeVersion('~> 3.5.0'), '3.5.0');
    });

    test('pulls the version out of an SPM version argument', () {
      expect(normalizeVersion('from: "3.0.0"'), '3.0.0');
    });

    test('is a no-op on an already-bare version', () {
      expect(normalizeVersion('3.5.0'), '3.5.0');
    });

    test('null in, null out', () {
      expect(normalizeVersion(null), isNull);
    });

    test('null when nothing semver-shaped is present', () {
      expect(normalizeVersion('develop'), isNull);
    });
  });

  group('NativeSdkDelta.getImpliedBump', () {
    NativeSdkDelta delta({String? currentDeclaration, String? targetVersion}) =>
        NativeSdkDelta(
          sdk: NativeSdk.ios,
          targetVersion: targetVersion,
          currentDeclaration: currentDeclaration,
        );

    test('a minor native SDK bump implies a minor bump', () {
      expect(
        delta(
          currentDeclaration: '3.10.0',
          targetVersion: '3.13.0',
        ).getImpliedBump(),
        VersionBumpType.minor,
      );
    });

    test('a major native SDK bump implies a major bump', () {
      expect(
        delta(
          currentDeclaration: '3.10.0',
          targetVersion: '4.0.0',
        ).getImpliedBump(),
        VersionBumpType.major,
      );
    });

    test('a patch-only native SDK bump implies a patch bump', () {
      expect(
        delta(
          currentDeclaration: '3.10.0',
          targetVersion: '3.10.5',
        ).getImpliedBump(),
        VersionBumpType.patch,
      );
    });

    test('null with no target (no change this run)', () {
      expect(delta(currentDeclaration: '3.10.0').getImpliedBump(), isNull);
    });

    test('null with no resolvable current version (never pinned before)', () {
      expect(delta(targetVersion: '3.13.0').getImpliedBump(), isNull);
    });

    test('null when the target is not actually newer', () {
      expect(
        delta(
          currentDeclaration: '3.13.0',
          targetVersion: '3.13.0',
        ).getImpliedBump(),
        isNull,
      );
    });
  });

  group('nativeSdkAggregateBump', () {
    test('the highest bump across multiple deltas wins', () {
      final deltas = [
        NativeSdkDelta(
          sdk: NativeSdk.ios,
          currentDeclaration: '3.10.0',
          targetVersion: '3.10.5', // patch
        ),
        NativeSdkDelta(
          sdk: NativeSdk.android,
          currentDeclaration: '3.10.0',
          targetVersion: '4.0.0', // major
        ),
      ];

      expect(nativeSdkAggregateBump(deltas), VersionBumpType.major);
    });

    test('null when nothing implies a bump', () {
      expect(nativeSdkAggregateBump(const []), isNull);
    });
  });

  group('resolveNativeSdkTarget', () {
    test(
      'an explicit override wins once confirmed to be a real release',
      () async {
        final target = await resolveNativeSdkTarget(
          trigger: TriggerContext.mainline,
          override: '3.12.0',
          workingTreeDeclaration: null,
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
          workingTreeDeclaration: null,
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
        workingTreeDeclaration: null,
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
        workingTreeDeclaration: null,
        fetchLatest: () => Future.value('9.9.9'),
        releaseExists: (version) async => true,
      );
      expect(target, '3.12.1');
    });

    test(
      'on a patch branch, an already-pinned working tree is the target, '
      'but does not trigger the "pinned" warning',
      () async {
        var onPinnedCalls = 0;
        final target = await resolveNativeSdkTarget(
          trigger: TriggerContext.patch,
          override: null,
          workingTreeDeclaration: '4.0.0',
          fetchLatest: () =>
              throw StateError('should not be called on a patch branch'),
          releaseExists: (version) =>
              throw StateError('should not be called with no override'),
          onPinned: (_) => onPinnedCalls++,
        );
        expect(target, '4.0.0');
        expect(onPinnedCalls, 0);
      },
    );

    test(
      'on develop, no override means latest (and no releaseExists call)',
      () async {
        final target = await resolveNativeSdkTarget(
          trigger: TriggerContext.mainline,
          override: null,
          workingTreeDeclaration: null,
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
        workingTreeDeclaration: null,
        fetchLatest: () => Future.value('3.13.0'),
        releaseExists: (version) =>
            throw StateError('should not be called with no override'),
      );
      expect(target, '3.13.0');
    });

    test('a floating declaration still tracks the latest release', () async {
      final target = await resolveNativeSdkTarget(
        trigger: TriggerContext.mainline,
        override: null,
        workingTreeDeclaration: '~> 3',
        fetchLatest: () => Future.value('3.13.0'),
        releaseExists: (version) =>
            throw StateError('should not be called with no override'),
      );
      expect(target, '3.13.0');
    });

    test(
      'a pinned declaration is honoured without asking what is newest',
      () async {
        String? pinned;
        final target = await resolveNativeSdkTarget(
          trigger: TriggerContext.mainline,
          override: null,
          workingTreeDeclaration: '3.13.1',
          fetchLatest: () => throw StateError(
            'should not look for a newer release when pinned',
          ),
          releaseExists: (version) =>
              throw StateError('should not be called with no override'),
          onPinned: (pin) => pinned = pin,
        );
        expect(target, '3.13.1');
        expect(pinned, '3.13.1', reason: 'the pin must be surfaced to a human');
      },
    );

    test('an override beats a pin', () async {
      String? pinned;
      final target = await resolveNativeSdkTarget(
        trigger: TriggerContext.mainline,
        override: '3.16.0',
        workingTreeDeclaration: '3.13.1',
        fetchLatest: () => Future.value('9.9.9'),
        releaseExists: (version) async => true,
        onPinned: (pin) => pinned = pin,
      );
      expect(target, '3.16.0');
      expect(pinned, isNull);
    });
  });

  group('isPinnedDeclaration', () {
    test('a complete version with no constraint operator is a pin', () {
      // Gradle, CocoaPods, and a C++ GIT_TAG annotation respectively.
      expect(isPinnedDeclaration('3.13.1'), isTrue);
      expect(isPinnedDeclaration("'3.15.0'"), isTrue);
      expect(isPinnedDeclaration('v1.4.0'), isTrue);
    });

    test('a full commit SHA is a pin', () {
      expect(isPinnedDeclaration('a' * 40), isTrue);
    });

    test('a range or a moving ref is not a pin', () {
      expect(isPinnedDeclaration('~> 3'), isFalse);
      expect(isPinnedDeclaration('~> 3.15'), isFalse);
      expect(isPinnedDeclaration('3+'), isFalse);
      expect(isPinnedDeclaration('from: "3.0.0"'), isFalse);
      expect(isPinnedDeclaration('branch: "develop"'), isFalse);
      expect(isPinnedDeclaration('develop'), isFalse);
      expect(isPinnedDeclaration('>= 3.0.0'), isFalse);
    });

    test('an incomplete version is a range, not a pin', () {
      expect(isPinnedDeclaration('3'), isFalse);
      expect(isPinnedDeclaration('3.15'), isFalse);
    });

    test('nothing declared is not a pin', () {
      expect(isPinnedDeclaration(null), isFalse);
      expect(isPinnedDeclaration('  '), isFalse);
    });
  });
}
