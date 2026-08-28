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

/// Matches a podspec's `s.dependency 'Datadog...', '<constraint>'` lines.
///
/// Private, like every pattern in this file. Nothing in this module rewrites
/// these files -- discovery only needs to recognise one -- and sharing a
/// pattern with the legacy CLI's pin-rewriting commands would couple a
/// *matcher* to a *rewriter*, which want different things from it: a matcher
/// wants to be permissive, a rewriter has to reproduce exactly what it
/// matched.
final _iosPodspecDependencyPattern = RegExp(
  r"s\.dependency\s+'Datadog\w*'\s*,\s*'[^']+'",
);

/// Matches a `build.gradle`'s `ext.datadog_version = "..."` assignment.
final _androidGradleVersionPattern = RegExp(
  r'ext\.datadog_version\s*=\s*"[^"]+"',
);

/// Matches a `Package.swift`'s dd-sdk-ios dependency line, e.g.
/// `.package(url: "https://github.com/Datadog/dd-sdk-ios.git", from: "3.0.0")`.
/// Matched case-insensitively on the URL: both `Datadog` and `DataDog`
/// spellings appear across this repo's manifests.
final _iosSpmDependencyPattern = RegExp(
  r'\.package\(url:\s*"[^"]*dd-sdk-ios[^"]*",\s*[^)]+\)',
  caseSensitive: false,
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
          _iosPodspecDependencyPattern.hasMatch(entity.readAsStringSync())) {
        iosPodspec = entity;
      } else if (entity is Directory) {
        // The real layout is `ios/<package_name>/Package.swift` -- a
        // manifest for building the plugin's iOS code via SPM instead of
        // CocoaPods.
        final packageSwift = File(p.join(entity.path, 'Package.swift'));
        if (packageSwift.existsSync() &&
            _iosSpmDependencyPattern.hasMatch(
              packageSwift.readAsStringSync(),
            )) {
          iosSpmManifest = packageSwift;
        }
      }
    }
  }

  File? androidGradle;
  final gradleFile = File(p.join(packageRoot, 'android', 'build.gradle'));
  if (gradleFile.existsSync() &&
      _androidGradleVersionPattern.hasMatch(gradleFile.readAsStringSync())) {
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
