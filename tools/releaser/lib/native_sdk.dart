// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:path/path.dart' as p;

import 'cmake_util.dart';
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
/// public so `cocoapod_util.dart`'s pin-rewriting step and this file's
/// discovery share one definition of the line shape instead of maintaining
/// two separate regexes for it.
/// [prefix] spans everything up to and including the constraint's opening
/// quote, so a rewrite can rebuild the line from the match instead of
/// reconstructing it -- see [pinIosPodspecDependencyLine].
final iosPodspecDependencyPattern = RegExp(
  r"(?<prefix>s\.dependency\s+'(?<dependency>Datadog\w*)'\s*,\s*')"
  r"(?<constraint>[^']+)'",
);

/// The `ext.datadog_version = "..."` line prefix in a `build.gradle`, and
/// the pattern built from it -- both public so `gradle_util.dart`'s
/// pin-rewriting step shares this file's exact definition of the line
/// rather than maintaining its own copy.
///
/// Discovery below uses the same pattern to decide whether a `build.gradle`
/// is an Android native-dependency file at all.
const androidGradleVersionPrefix = 'ext.datadog_version';

/// [prefix] spans everything up to and including the opening quote, so a
/// rewrite can rebuild the assignment from the match rather than from a
/// literal -- reproducing a literal `x = "y"` would silently fail to replace
/// a line the pattern happily matched with different spacing.
final androidGradleVersionPattern = RegExp(
  '(?<prefix>$androidGradleVersionPrefix\\s*=\\s*")(?<version>[^"]+)"',
);

/// Matches a `Package.swift`'s dd-sdk-ios dependency line (e.g.
/// `.package(url: "https://github.com/Datadog/dd-sdk-ios.git", from:
/// "3.0.0")`) -- public so `spm_util.dart`'s pin-rewriting step and this
/// file's discovery share one definition of it.
final iosSpmDependencyPattern = RegExp(
  r'\.package\(url:\s*"(?<url>[^"]*dd-sdk-ios[^"]*)",\s*(?<spec>[^)]+)\)',
);

/// The native-dependency files found in a package's own directory --
/// resolved by checking what's actually there, not assumed from the
/// package's name or role.
class NativeDependencyFiles {
  final File? iosPodspec;

  /// A `Package.swift` pinning dd-sdk-ios via SPM -- independent of
  /// [iosPodspec] since a package can ship both, each pinning the same
  /// dependency in its own file format.
  final File? iosSpmManifest;
  final File? androidGradle;
  final List<File> cppCMakeLists;

  NativeDependencyFiles({
    this.iosPodspec,
    this.iosSpmManifest,
    this.androidGradle,
    this.cppCMakeLists = const [],
  });

  bool get isEmpty =>
      iosPodspec == null &&
      iosSpmManifest == null &&
      androidGradle == null &&
      cppCMakeLists.isEmpty;
}

/// Walks [packageRoot] (a package's own directory, not its example/test
/// apps) for the native-dependency files this tooling knows how to read and
/// pin: an iOS podspec with a Datadog pod dependency, a `Package.swift`
/// pinning dd-sdk-ios via SPM, an Android `build.gradle` with a
/// `datadog_version`, and/or a `windows/`/`linux/` `CMakeLists.txt` with a
/// dd-sdk-cpp `GIT_TAG` inside its `FetchContent_Declare(dd-sdk-cpp ...)`
/// block (a `CMakeLists.txt` whose only `GIT_TAG` belongs to some other
/// vendored dependency doesn't count).
NativeDependencyFiles resolveNativeDependencyFiles(String packageRoot) {
  File? iosPodspec;
  File? iosSpmManifest;
  final iosDir = Directory(p.join(packageRoot, 'ios'));
  if (iosDir.existsSync()) {
    for (final entity in iosDir.listSync()) {
      if (entity is File &&
          entity.path.endsWith('.podspec') &&
          iosPodspecDependencyPattern.hasMatch(entity.readAsStringSync())) {
        iosPodspec = entity;
      } else if (entity is Directory) {
        // The real layout is `ios/<package_name>/Package.swift` -- a
        // manifest for building the plugin's iOS code via SPM instead of
        // CocoaPods.
        final packageSwift = File(p.join(entity.path, 'Package.swift'));
        if (packageSwift.existsSync() &&
            iosSpmDependencyPattern.hasMatch(packageSwift.readAsStringSync())) {
          iosSpmManifest = packageSwift;
        }
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
        hasDdSdkCppGitTag(cmakeFile.readAsStringSync())) {
      cppCMakeLists.add(cmakeFile);
    }
  }

  return NativeDependencyFiles(
    iosPodspec: iosPodspec,
    iosSpmManifest: iosSpmManifest,
    androidGradle: androidGradle,
    cppCMakeLists: cppCMakeLists,
  );
}

/// What one native SDK dependency of a package resolves to this run.
///
/// This is a *target*, not a diff: `develop` (and a long-lived pre-release
/// branch) deliberately keeps its manifests on floating constraints (`~> 3`,
/// `branch: "develop"`, `GIT_TAG develop`), and only the release-prep branch's
/// copy is ever pinned. So there's no meaningful "current pin" to subtract
/// from -- the plan just says what to pin to, and `prepare_release.dart`
/// rewrites [files] to match.
///
/// [targetVersion] is null when nothing should change -- the patch-branch
/// default, absent an explicit override.
///
/// [targetSha] is only meaningful for [NativeSdk.cpp]: CMake's
/// `FetchContent_Declare` has no field for pinning a tag *and* verifying
/// its commit, so the resolved SHA is what actually gets written to
/// `GIT_TAG` (see cmake_util.dart's `pinCppVersion`) -- a full commit SHA
/// is immutable, unlike a tag, which can be moved.
class NativeSdkDelta {
  final NativeSdk sdk;
  final String? targetVersion;
  final String? targetSha;

  /// Every file of this package that pins this dependency and therefore needs
  /// rewriting -- one for [NativeSdk.android] (`build.gradle`), up to two for
  /// [NativeSdk.ios] (podspec and/or `Package.swift`), and one per platform
  /// for [NativeSdk.cpp] (`windows/CMakeLists.txt`, `linux/CMakeLists.txt`).
  /// Carried on the plan so the apply step rewrites exactly what discovery
  /// found, rather than resolving the file set a second time.
  final List<File> files;

  NativeSdkDelta({
    required this.sdk,
    required this.targetVersion,
    this.targetSha,
    this.files = const [],
  });

  @override
  String toString() => targetVersion == null
      ? '${sdk.name}: no change'
      : '${sdk.name}: -> $targetVersion';
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
