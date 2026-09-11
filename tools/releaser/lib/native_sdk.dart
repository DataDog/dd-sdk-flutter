// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:version/version.dart';

import 'cmake_util.dart';
import 'trigger_context.dart';
import 'version_bump.dart';

/// A native SDK a Flutter package can depend on.
enum NativeSdk {
  ios(repoSlug: 'DataDog/dd-sdk-ios', displayName: 'iOS'),
  android(repoSlug: 'DataDog/dd-sdk-android', displayName: 'Android'),
  cpp(repoSlug: 'DataDog/dd-sdk-cpp', displayName: 'C++');

  final String repoSlug;
  final String displayName;

  const NativeSdk({required this.repoSlug, required this.displayName});
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
  r"s\.dependency\s+'Datadog\w*'\s*,\s*'(?<constraint>[^']+)'",
);

/// Matches a `build.gradle`'s `ext.datadog_version = "..."` assignment.
final _androidGradleVersionPattern = RegExp(
  r'ext\.datadog_version\s*=\s*"(?<version>[^"]+)"',
);

/// Matches a `Package.swift`'s dd-sdk-ios dependency line, e.g.
/// `.package(url: "https://github.com/Datadog/dd-sdk-ios.git", from: "3.0.0")`.
/// Matched case-insensitively on the URL: both `Datadog` and `DataDog`
/// spellings appear across this repo's manifests.
final _iosSpmDependencyPattern = RegExp(
  r'\.package\(url:\s*"[^"]*dd-sdk-ios[^"]*",\s*(?<versionArg>[^)]+)\)',
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

/// The dd-sdk-ios constraint declared in [podspecContent] (e.g. `~> 3`), or,
/// absent that, [spmContent]'s version argument (e.g. `from: "3.0.0"`).
/// Null if neither matches. Takes content, not a [File] -- see
/// [NativeSdkDelta.currentDeclaration].
String? currentIosDeclaration({String? podspecContent, String? spmContent}) {
  if (podspecContent != null) {
    return _iosPodspecDependencyPattern
        .firstMatch(podspecContent)
        ?.namedGroup('constraint');
  }
  if (spmContent == null) return null;
  return _iosSpmDependencyPattern
      .firstMatch(spmContent)
      ?.namedGroup('versionArg')
      ?.trim();
}

/// The `ext.datadog_version` declared in [gradleContent], or null.
String? currentAndroidDeclaration(String? gradleContent) {
  if (gradleContent == null) return null;
  return _androidGradleVersionPattern
      .firstMatch(gradleContent)
      ?.namedGroup('version');
}

/// The dd-sdk-cpp version declared in [cmakeListsContent], or null. Reads
/// [currentGitTagVersion] rather than the raw ref, since a previously-pinned
/// package's `GIT_TAG` is a commit SHA whose version only survives in its
/// trailing `# <tag>` annotation -- see [currentGitTagVersion].
String? currentCppDeclaration(String? cmakeListsContent) {
  if (cmakeListsContent == null) return null;
  return currentGitTagVersion(cmakeListsContent);
}

/// The first bare semver found in [declaration], or null.
///
/// Handles every real shape a native SDK pin is declared in: a CocoaPods
/// constraint (`~> 3.5.0`), an SPM version argument (`from: "3.0.0"`), and
/// a bare version (Android's `ext.datadog_version`, C++'s resolved
/// `GIT_TAG`) -- all reduce to "pull out the semver", so one pattern
/// covers them instead of a stripper per format.
String? normalizeVersion(String? declaration) {
  if (declaration == null) return null;
  return RegExp(r'\d+\.\d+\.\d+').firstMatch(declaration)?.group(0);
}

/// A full 40-character commit SHA -- what `pinCppVersion` writes to `GIT_TAG`,
/// and the one non-semver shape that still names exactly one immutable thing.
final _fullShaPattern = RegExp(r'^[0-9a-f]{40}$');

/// Anything that makes a declaration name a *range* or a *moving ref* rather
/// than one immutable version: CocoaPods' `~>`, Gradle's `+` prefix-match,
/// SPM's `from:`/`branch:` forms, and a comparison operator in any of them.
const _floatingConstraintMarkers = ['~>', '+', '<', '>', 'from', 'branch'];

/// Whether [declaration] pins exactly one immutable version, as opposed to
/// naming a range or a moving ref.
bool isPinnedDeclaration(String? declaration) {
  if (declaration == null) return false;

  final value = declaration.trim();
  if (value.isEmpty) return false;
  if (_floatingConstraintMarkers.any(value.contains)) return false;
  if (_fullShaPattern.hasMatch(value)) return true;

  // A complete semver and nothing else -- `3.15.0`, `v1.4.0`, `'3.13.1'`.
  // A bare major (`3`) or major.minor (`3.15`) is a range, not a pin.
  return RegExp(r'^\D*\d+\.\d+\.\d+\D*$').hasMatch(value);
}

/// What one native SDK dependency of a package resolves to this run.
///
/// [targetVersion]/[targetSha] are a *target*, not a diff: `develop` (and a
/// long-lived pre-release branch) deliberately keeps its manifests on
/// floating constraints (`~> 3`, `branch: "develop"`, `GIT_TAG develop`), and
/// only the release-prep branch's copy is ever pinned. Eligibility never
/// compares against a "current" value for exactly that reason.
///
/// Bump *level* is the one planning decision that does compare
/// [currentDeclaration] against [targetVersion] -- see
/// [nativeSdkAggregateBump] -- since a native SDK's own minor/major bump
/// should carry through to the Flutter package wrapping it. The plan
/// otherwise just says what to pin to, and `prepare_release.dart` rewrites
/// [files] to match.
///
/// [currentDeclaration] is what this SDK was pinned to by the last release
/// *on the line being released*, and is what [NativeSdkDelta.getImpliedBump] compares
/// [targetVersion] against. Must be sourced from that release's git history
/// (`fileContentAtTag` in `git_history.dart`), not from [files] as they sit
/// in the working tree -- the working tree normally floats, so it isn't
/// evidence of what anything previously released with.
///
/// [targetSha] is only meaningful for [NativeSdk.cpp]: CMake's
/// `FetchContent_Declare` has no field for pinning a tag *and* verifying
/// its commit, so the resolved SHA is what actually gets written to
/// `GIT_TAG` (see cmake_util.dart's `pinCppVersion`) -- a full commit SHA
/// is immutable, unlike a tag, which can be moved.
class NativeSdkDelta {
  final NativeSdk sdk;
  final String? targetVersion;
  final String? currentDeclaration;
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
    this.currentDeclaration,
    this.targetSha,
    this.files = const [],
  });

  @override
  String toString() {
    if (targetVersion == null) return '${sdk.name}: no change';
    final from = currentDeclaration;
    return from == null
        ? '${sdk.name}: -> $targetVersion'
        : '${sdk.name}: $from -> $targetVersion';
  }

  /// The bump [delta] implies on its own -- e.g. dd-sdk-ios 3.15.0 -> 3.16.0
  /// implies at least a minor bump on the Flutter package wrapping it, with
  /// or without any qualifying commits of its own. Null when there's nothing
  /// to compare (no target, or no resolvable current version) or the target
  /// isn't actually newer.
  VersionBumpType? getImpliedBump() {
    if (targetVersion == null) return null;

    final fromRaw = normalizeVersion(currentDeclaration);
    if (fromRaw == null) return null;
    final toRaw = normalizeVersion(targetVersion);
    if (toRaw == null) return null;

    final from = Version.parse(fromRaw);
    final to = Version.parse(toRaw);
    if (to <= from) return null;
    if (to.major != from.major) return VersionBumpType.major;
    if (to.minor != from.minor) return VersionBumpType.minor;
    if (to.patch != from.patch) return VersionBumpType.patch;
    return null;
  }
}

/// The highest bump implied across [deltas] -- see [NativeSdkDelta.getImpliedBump].
VersionBumpType? nativeSdkAggregateBump(List<NativeSdkDelta> deltas) =>
    highestBump(deltas.map((e) => e.getImpliedBump()));

/// The network calls native SDK resolution needs -- bundled so callers
/// (`release_plan.dart`) don't thread three separate function parameters
/// through every layer between `computeReleasePlan` and
/// [resolveNativeSdkTarget]. All three are keyed by a GitHub repo slug
/// (e.g. `DataDog/dd-sdk-ios`) so one instance covers all three SDKs.
///
/// An interface rather than a record of closures, because an implementation
/// may need to remember things across calls -- the real one answers "what is
/// the latest dd-sdk-ios release" once per run rather than once per package.
/// State belongs in a field on a named class, not captured in a closure.
abstract class NativeSdkGateways {
  const NativeSdkGateways();

  /// The newest published release of [repoSlug], as a tag name.
  Future<String> fetchLatest(String repoSlug);

  /// [ref] (a tag or branch) resolved to the full commit SHA it points at.
  Future<String> resolveCommitSha(String repoSlug, String ref);

  /// Whether [version] names a real release of [repoSlug] -- what catches a
  /// typo'd `IOS_SDK_VERSION` before it reaches a build.
  Future<bool> releaseExists(String repoSlug, String version);
}

/// Resolves what a native SDK's pin should become this run:
/// - an explicit [override] wins, but only once [releaseExists] confirms
///   it's a real release -- this is the check `release_validator.dart`'s
///   `_validateReleaseVersion` already did for iOS/Android before this file
///   existed; skipping it would let a typo'd `IOS_SDK_VERSION`/
///   `ANDROID_SDK_VERSION` sail through undetected until a much later,
///   harder-to-diagnose build failure. An override beats a pin: passing one
///   on the run is a more specific instruction than a pin someone left in a
///   file earlier;
/// - on a patch branch (default: no change) the pin is left alone, since
///   auto-jumping to the latest native SDK defeats the point of an
///   isolated patch.
/// - when [workingTreeDeclaration] is already pinned to one immutable
///   version (see [isPinnedDeclaration]), that pin is the target and no
///   "what's newest" lookup happens at all. The dev line normally floats, so
///   an exact version sitting there is a deliberate hold -- typically while
///   working against a specific native SDK. It is still a *target*, so a pin
///   that differs from what the line last shipped remains a real version
///   change: it contributes its bump and gets its changelog section;
/// - otherwise (a floating declaration on mainline or pre-release), it
///   defaults to the latest published release, resolved via [fetchLatest].
///
/// [onPinned] is called with the honoured pin when that branch is taken, so
/// the caller can surface it -- silently declining to update a native SDK is
/// exactly the kind of thing a release reviewer needs told.
Future<String?> resolveNativeSdkTarget({
  required TriggerContext trigger,
  required String? override,
  required String? workingTreeDeclaration,
  required Future<String> Function() fetchLatest,
  required Future<bool> Function(String version) releaseExists,
  void Function(String pin)? onPinned,
}) async {
  if (override != null) {
    if (!await releaseExists(override)) {
      throw StateError('Release "$override" was not found.');
    }
    return override;
  }
  if (trigger == TriggerContext.patch) return null;

  if (isPinnedDeclaration(workingTreeDeclaration)) {
    final pin = workingTreeDeclaration!.trim();
    onPinned?.call(pin);
    return pin;
  }

  return await fetchLatest();
}
