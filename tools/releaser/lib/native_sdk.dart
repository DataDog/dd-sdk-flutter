// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:path/path.dart' as p;

import 'trigger_context.dart';

/// A native SDK a Flutter package can depend on.
enum NativeSdk {
  ios(repoSlug: 'DataDog/dd-sdk-ios'),
  android(repoSlug: 'DataDog/dd-sdk-android'),
  cpp(repoSlug: 'DataDog/dd-sdk-cpp');

  final String repoSlug;

  const NativeSdk({required this.repoSlug});
}

/// Matches a podspec's `s.dependency 'Datadog...', '<constraint>'` lines --
/// public so `cocoapod_util.dart`'s pin-rewriting step uses the exact same
/// pattern this file reads the current pin with, instead of a second,
/// separately-maintained regex for the same line shape.
final iosPodspecDependencyPattern = RegExp(
  r"s\.dependency\s+'(?<dependency>Datadog\w*)'\s*,\s*'(?<constraint>[^']+)'",
);

/// The `ext.datadog_version = "..."` line prefix in a `build.gradle`, and
/// the pattern built from it -- both public so `gradle_util.dart`'s
/// pin-rewriting step shares this file's exact definition of the line
/// rather than maintaining its own copy.
const androidGradleVersionPrefix = 'ext.datadog_version';
final androidGradleVersionPattern = RegExp(
  '$androidGradleVersionPrefix\\s*=\\s*"(?<version>[^"]+)"',
);
final _cmakeGitTagPattern = RegExp(
  r'^\s*GIT_TAG\s+(?<ref>[\w./-]+).*?(?:#\s*(?<comment>\S+))?$',
  multiLine: true,
);

/// The current iOS pin from a podspec's `s.dependency 'Datadog...'` lines
/// (they all share one constraint), or null if it has none.
String? readIosPodspecPin(String podspecContent) => iosPodspecDependencyPattern
    .firstMatch(podspecContent)
    ?.namedGroup('constraint');

/// The current Android pin from a `build.gradle`'s `ext.datadog_version`,
/// or null if it has none.
String? readAndroidGradlePin(String buildGradleContent) =>
    androidGradleVersionPattern
        .firstMatch(buildGradleContent)
        ?.namedGroup('version');

/// The current C++ pin from a CMakeLists.txt's dd-sdk-cpp `GIT_TAG` line, or
/// null if it has none. Once pinned by this tooling, `GIT_TAG` holds a
/// commit SHA with the human-meaningful tag kept as a trailing `# <tag>`
/// comment (see [pinCppVersion] in cmake_util.dart) -- that comment is
/// preferred here so the *tag* is what gets compared run-over-run, not an
/// opaque SHA that would never equal a freshly-resolved target tag.
String? readCppCMakePin(String cmakeListsContent) {
  for (final line in cmakeListsContent.split('\n')) {
    final match = _cmakeGitTagPattern.firstMatch(line);
    if (match != null) {
      return match.namedGroup('comment') ?? match.namedGroup('ref');
    }
  }
  return null;
}

/// The native-dependency files found in a package's own directory --
/// resolved by checking what's actually there, not assumed from the
/// package's name or role.
class NativeDependencyFiles {
  final File? iosPodspec;
  final File? androidGradle;
  final List<File> cppCMakeLists;

  NativeDependencyFiles({
    this.iosPodspec,
    this.androidGradle,
    this.cppCMakeLists = const [],
  });

  bool get isEmpty =>
      iosPodspec == null && androidGradle == null && cppCMakeLists.isEmpty;
}

/// Walks [packageRoot] (a package's own directory, not its example/test
/// apps) for the native-dependency files this tooling knows how to read and
/// pin: an iOS podspec with a Datadog pod dependency, an Android
/// `build.gradle` with a `datadog_version`, and/or a `windows/`/`linux/`
/// `CMakeLists.txt` with a dd-sdk-cpp `GIT_TAG`.
NativeDependencyFiles resolveNativeDependencyFiles(String packageRoot) {
  File? iosPodspec;
  final iosDir = Directory(p.join(packageRoot, 'ios'));
  if (iosDir.existsSync()) {
    for (final entity in iosDir.listSync()) {
      if (entity is File &&
          entity.path.endsWith('.podspec') &&
          iosPodspecDependencyPattern.hasMatch(entity.readAsStringSync())) {
        iosPodspec = entity;
        break;
      }
    }
  }

  File? androidGradle;
  final gradleFile = File(p.join(packageRoot, 'android', 'build.gradle'));
  if (gradleFile.existsSync() &&
      androidGradleVersionPattern.hasMatch(gradleFile.readAsStringSync())) {
    androidGradle = gradleFile;
  }

  final cppCMakeLists = <File>[];
  for (final platformDir in ['windows', 'linux']) {
    final cmakeFile = File(p.join(packageRoot, platformDir, 'CMakeLists.txt'));
    if (cmakeFile.existsSync() &&
        _cmakeGitTagPattern.hasMatch(cmakeFile.readAsStringSync())) {
      cppCMakeLists.add(cmakeFile);
    }
  }

  return NativeDependencyFiles(
    iosPodspec: iosPodspec,
    androidGradle: androidGradle,
    cppCMakeLists: cppCMakeLists,
  );
}

/// What's changing (if anything) for one native SDK dependency of a
/// package. [targetVersion] is null when nothing should change -- the
/// patch-branch default, absent an explicit override.
///
/// [targetSha] is only meaningful for [NativeSdk.cpp]: CMake's
/// `FetchContent_Declare` has no field for pinning a tag *and* verifying
/// its commit, so the resolved SHA is what actually gets written to
/// `GIT_TAG` (see cmake_util.dart's `pinCppVersion`) -- a full commit SHA
/// is immutable, unlike a tag, which can be moved.
class NativeSdkDelta {
  final NativeSdk sdk;
  final String? currentPin;
  final String? targetVersion;
  final String? targetSha;

  NativeSdkDelta({
    required this.sdk,
    required this.currentPin,
    required this.targetVersion,
    this.targetSha,
  });

  bool get isChange => targetVersion != null && targetVersion != currentPin;

  @override
  String toString() => isChange
      ? '${sdk.name}: $currentPin -> $targetVersion'
      : '${sdk.name}: $currentPin (no change)';
}

/// The network calls native SDK resolution needs -- bundled so callers
/// (`release_plan.dart`) don't thread three separate function parameters
/// through every layer between `computeReleasePlan` and
/// [resolveNativeSdkTarget]. All three are keyed by a GitHub repo slug
/// (e.g. `DataDog/dd-sdk-ios`) so one instance covers all three SDKs.
class NativeSdkGateways {
  final Future<String> Function(String repoSlug) fetchLatest;
  final Future<String> Function(String repoSlug, String ref) resolveCommitSha;
  final Future<bool> Function(String repoSlug, String version) releaseExists;

  const NativeSdkGateways({
    required this.fetchLatest,
    required this.resolveCommitSha,
    required this.releaseExists,
  });
}

/// Resolves what a native SDK's pin should become this run:
/// - an explicit [override] wins, but only once [releaseExists] confirms
///   it's a real release -- this is the check `release_validator.dart`'s
///   `_validateReleaseVersion` already did for iOS/Android before this file
///   existed; skipping it would let a typo'd `IOS_SDK_VERSION`/
///   `ANDROID_SDK_VERSION` sail through undetected until a much later,
///   harder-to-diagnose build failure;
/// - on a patch branch (default: no change) the pin is left alone, since
///   auto-jumping to the latest native SDK defeats the point of an
///   isolated patch;
/// - otherwise (mainline or pre-release), it defaults to the latest
///   published release, resolved via [fetchLatest].
Future<String?> resolveNativeSdkTarget({
  required TriggerContext trigger,
  required String? override,
  required Future<String> Function() fetchLatest,
  required Future<bool> Function(String version) releaseExists,
}) async {
  if (override != null) {
    if (!await releaseExists(override)) {
      throw StateError('Release "$override" was not found.');
    }
    return override;
  }
  if (trigger == TriggerContext.patch) return null;
  return await fetchLatest();
}
