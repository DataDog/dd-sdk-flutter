// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// The `prepare-release` GitLab job's entry point -- computes the release
// plan (via `release_plan.dart`, shared with `preview_release.dart`),
// generates the AI changelog, applies every change, and opens the release
// PR. See `_ReleaseTarget.forTrigger` for where each trigger's PR targets.

// Release-prep output is deliberately split into two commits, so that a
// later cherry-pick back onto a dev-line branch (`develop`, or a
// pre-release branch like `v4`) can take one without the other:
//   - Commit A ("content"): changelog, version bumps, dependent
//     constraints, NATIVE_SDK_VERSIONS.md. Safe to eventually land on a
//     dev-line branch -- that branch still needs its own changelog/version
//     history, just not what's below.
//   - Commit B ("publish-prep"): dependency_overrides checks, native SDK
//     pinning, dry-run validation, `.release/manifest.json`. Must never
//     reach a dev-line branch -- it pins things a dev line needs to keep
//     floating (native SDKs on `develop`, for example) and its manifest is
//     meaningless there.
// Patch is the exception: it doesn't split, since nothing else ever
// develops on a patch branch, so there's no dev-line commit B could leak
// into. `manifest.contentCommit` is `null` on patch for exactly this
// reason -- see its doc comment in `manifest.dart`.

import 'dart:io';

import 'package:args/args.dart';
import 'package:git/git.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:releaser/changelog_writer.dart';
import 'package:releaser/cmake_util.dart';
import 'package:releaser/cocoapod_util.dart';
import 'package:releaser/dependency_constraints.dart';
import 'package:releaser/git/git_dir.dart';
import 'package:releaser/git/release_git.dart';
import 'package:releaser/github_cmd_wrapper.dart';
import 'package:releaser/gradle_util.dart';
import 'package:releaser/llm/ai_gateway.dart';
import 'package:releaser/llm/changelog.dart';
import 'package:releaser/llm/costs.dart';
import 'package:releaser/manifest.dart';
import 'package:releaser/native_sdk.dart';
import 'package:releaser/package_discovery.dart';
import 'package:releaser/release_plan.dart';
import 'package:releaser/release_validator.dart';
import 'package:releaser/spm_util.dart';
import 'package:releaser/version_updater.dart';
import 'package:releaser/yaml_util.dart';

final _log = Logger('prepare_release');

Future<void> main(List<String> arguments) async {
  Logger.root.onRecord.listen((record) {
    if (record.level >= Level.WARNING) {
      stderr.writeln(record.message);
    } else {
      print(record.message);
    }
  });

  final argParser = ArgParser()
    ..addOption(
      'packages',
      help:
          'Comma-separated package names. Omit for --all behaviour: every '
          'package with pending commits. Not accepted on a patch branch.',
    )
    ..addFlag(
      'include-federated',
      defaultsTo: false,
      help: 'See preview_release.dart -- same meaning here.',
    )
    ..addOption('bump-type', help: 'Override the computed bump.')
    ..addOption('ios-sdk-version')
    ..addOption('android-sdk-version')
    ..addOption('cpp-version')
    ..addOption('prerelease-label')
    ..addOption(
      'trigger',
      allowed: ['auto', 'mainline', 'patch', 'prerelease'],
      defaultsTo: 'auto',
    )
    ..addOption(
      'repo-root',
      help: 'Repo root to run against. Defaults to the current directory.',
    )
    ..addFlag(
      'dry-run',
      defaultsTo: false,
      help:
          'Apply every change and create both commits locally, but stop '
          'before pushing or opening a PR -- for local/CI verification '
          'without side effects visible outside this checkout.',
    )
    ..addFlag(
      'skip-publish-validation',
      defaultsTo: false,
      help: 'Skip "flutter pub publish --dry-run" validation.',
    )
    ..addFlag('help', abbr: 'h', negatable: false);

  final ArgResults args;
  try {
    args = argParser.parse(arguments);
  } on FormatException catch (e) {
    _log.shout('❌ ${e.message}\n\n${argParser.usage}');
    exitCode = 1;
    return;
  }

  if (args['help'] as bool) {
    print(argParser.usage);
    return;
  }

  Logger.root.level = Level.FINE;

  final gitDir = await getGitDir(args['repo-root'] as String?);
  if (gitDir == null) {
    exitCode = 1;
    return;
  }

  final currentBranch = (await gitDir.currentBranch()).branchName;
  final trigger =
      TriggerContext.parse(args['trigger'] as String) ??
      resolveTriggerContext(currentBranch);

  final requestedPackages =
      (args['packages'] as String?)
          ?.split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList() ??
      const <String>[];

  final ctx = RunContext(
    repoRoot: gitDir.path,
    trigger: trigger,
    currentBranch: currentBranch,
    requestedPackages: requestedPackages,
    includeFederated: args['include-federated'] as bool,
    bumpTypeOverride: args['bump-type'] as String?,
    prereleaseLabel: args['prerelease-label'] as String?,
    iosSdkVersionOverride: args['ios-sdk-version'] as String?,
    androidSdkVersionOverride: args['android-sdk-version'] as String?,
    cppVersionOverride: args['cpp-version'] as String?,
  );

  final aiGatewayClient = HttpAiGatewayClient.fromEnvironment();
  try {
    await prepareRelease(
      ctx,
      gitDir: gitDir,
      github: GithubCommandWrapper(gitDir.path),
      aiGatewayClient: aiGatewayClient,
      dryRun: args['dry-run'] as bool,
      skipPublishValidation: args['skip-publish-validation'] as bool,
    );
  } catch (e) {
    _log.shout(e is StateError ? '❌ ${e.message}' : '❌ $e');
    exitCode = 1;
    return;
  } finally {
    aiGatewayClient.close();
  }
}

/// Where a trigger's release-prep output lands -- both which branch to
/// build it on and which branch its PR (if any) targets.
class _ReleaseTarget {
  /// Branch to check out and build both commits on. For mainline/
  /// pre-release this is a brand new `release-prep/*` branch off
  /// [ctxCurrentBranch]; for patch it's the patch branch itself -- nothing
  /// else ever develops there, so there's no need for a separate branch.
  final String workingBranch;

  /// The branch to PR into, or null when this trigger pushes directly
  /// with no PR (patch's primary path).
  final String? prBase;

  final bool createsNewBranch;

  /// Tag to push at commit A's SHA, or null on patch (no commit A exists to
  /// protect -- patch never splits). This repo auto-deletes a PR's head
  /// branch on merge and allows squash/rebase, either of which would
  /// otherwise strand commit A's original commit object once
  /// `release-prep/*` is gone; the tag keeps it fetchable by SHA regardless
  /// of which merge strategy lands the release-prep PR, so Phase 2's
  /// backport can still `git merge` that exact commit into the dev-line
  /// branch afterwards. See `.plans/new-release-process.md` step 1g.
  final String? contentTagName;

  _ReleaseTarget({
    required this.workingBranch,
    required this.prBase,
    required this.createsNewBranch,
    required this.contentTagName,
  });

  factory _ReleaseTarget.forTrigger(RunContext ctx) {
    switch (ctx.trigger) {
      case TriggerContext.mainline:
        final id = _dateId();
        return _ReleaseTarget(
          workingBranch: 'release-prep/$id',
          prBase: 'main',
          createsNewBranch: true,
          contentTagName: 'release-content/$id',
        );
      case TriggerContext.preRelease:
        final id = _dateId();
        return _ReleaseTarget(
          workingBranch: 'release-prep/$id',
          // Every whitelisted pre-release branch is paired with its own
          // disposable `{branch}-main` -- release-prep never commits or
          // PRs onto the pre-release branch itself.
          prBase: '${ctx.currentBranch}-main',
          createsNewBranch: true,
          contentTagName: 'release-content/$id',
        );
      case TriggerContext.patch:
        return _ReleaseTarget(
          workingBranch: ctx.currentBranch,
          prBase: null,
          createsNewBranch: false,
          contentTagName: null,
        );
    }
  }

  static String _dateId() {
    final now = DateTime.now().toUtc();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final shortId = (now.microsecondsSinceEpoch % 0xFFFFFF).toRadixString(16);
    return '$date-$shortId';
  }
}

/// Whether [pkg] depends on another package in this workspace -- `melos
/// bootstrap` always writes such a dependency a local-path override, so
/// this is what determines whether [pkg] should have one at all.
bool _dependsOnWorkspacePackage(
  DiscoveredPackage pkg,
  String repoRoot,
  Set<String> workspaceNames,
) {
  final pubspecFile = File(p.join(pkg.absolutePath(repoRoot), 'pubspec.yaml'));
  return pubspecFile.readAsLinesSync().any(
    (line) => workspaceNames.any(
      (name) => name != pkg.name && line.trim().startsWith('$name:'),
    ),
  );
}

/// Whether `melos bootstrap` has written [pkg] a `pubspec_overrides.yaml`.
bool _melosBootstrapped(DiscoveredPackage pkg, String repoRoot) => File(
  p.join(pkg.absolutePath(repoRoot), 'pubspec_overrides.yaml'),
).existsSync();

/// The full apply/commit/(push/PR) run.
Future<void> prepareRelease(
  RunContext ctx, {
  required GitDir gitDir,
  required GithubCommandWrapper github,
  required AiGatewayClient aiGatewayClient,
  bool dryRun = false,
  bool skipPublishValidation = false,
  PublishedVersionsGateway? publishedVersions,
}) async {
  if (!await isWorkingTreeClean(gitDir, _log)) {
    throw StateError(
      'Working tree at ${gitDir.path} has uncommitted changes -- '
      'prepare-release stages everything with `git add .`, so it would '
      'sweep them into a release commit. Commit, stash, or discard them '
      'first.',
    );
  }

  final plan = await computeReleasePlan(
    ctx,
    gitDir: gitDir,
    nativeSdkGateways: GithubSdkGateways(github, logger: _log),
    publishedVersions: publishedVersions,
  );
  if (plan.packages.isEmpty) {
    _log.info('No packages would release from this run. Nothing to do.');
    return;
  }

  final allGroups = await discoverPackages(ctx.repoRoot);

  // Cheap, purely-local checks run before anything is mutated -- a branch
  // created or a commit made here can't be cleanly undone once
  // `_applyPublishPrep` (which used to run this same check) has already
  // produced commit A, leaving a half-prepared `release-prep/*` branch
  // behind on failure.
  final workspaceNames = allGroups
      .expand((g) => g.members)
      .map((m) => m.name)
      .toSet();
  for (final packagePlan in plan.packages) {
    final pkg = packagePlan.package;
    final pubspecFile = File(
      p.join(pkg.absolutePath(ctx.repoRoot), 'pubspec.yaml'),
    );
    if (pubspecHasDependencyOverrides(pubspecFile)) {
      throw StateError(
        '${pubspecFile.path} has a committed dependency_overrides block. '
        'pub.dev will refuse to publish this package -- remove it before '
        're-running.',
      );
    }

    if (_dependsOnWorkspacePackage(pkg, ctx.repoRoot, workspaceNames) &&
        !_melosBootstrapped(pkg, ctx.repoRoot)) {
      throw StateError(
        '${pkg.name} depends on another package in this workspace but has '
        'no pubspec_overrides.yaml -- run `melos bootstrap` first.',
      );
    }
  }

  final target = _ReleaseTarget.forTrigger(ctx);

  if (target.createsNewBranch) {
    await createAndCheckoutBranch(gitDir, target.workingBranch, _log);
  }

  final costTracker = LlmCostTracker();
  final staleConsumerWarnings = <StaleConsumerWarning>[];

  // -- Commit A: content -- see the file-level comment above.
  for (final packagePlan in plan.packages) {
    await _applyContentChanges(
      packagePlan,
      ctx,
      allGroups,
      github: github,
      aiGatewayClient: aiGatewayClient,
      costTracker: costTracker,
      staleConsumerWarnings: staleConsumerWarnings,
    );
  }

  final versionSummary = _versionSummary(plan.packages);

  // `null` for patch -- see the file-level comment above.
  final String? contentCommit = ctx.trigger == TriggerContext.patch
      ? null
      : await commitAll(
          gitDir,
          'chore(release): update changelog and bump versions',
          _log,
          body: versionSummary,
        );

  // -- Commit B: publish-prep -- see the file-level comment above.
  //
  // Podfile overrides and snapshot maven repositories are stripped from
  // every workspace package's example apps, not just the ones releasing
  // this run: an override floats a Pod on dd-sdk-ios's `develop` branch,
  // and a snapshots repo lets Gradle silently resolve a newer, unreleased
  // dd-sdk-android build -- a release-prep branch needs the whole workspace
  // to build in a stable, reproducible state, whether or not a given
  // package is part of this release.
  for (final pkg in allGroups.expand((g) => g.members)) {
    final packageRoot = pkg.absolutePath(ctx.repoRoot);
    for (final exampleDir in const [
      'example',
      'integration_test_app',
      'e2e_test_app',
    ]) {
      final podfile = File(p.join(packageRoot, exampleDir, 'ios', 'Podfile'));
      if (podfile.existsSync()) {
        await removePodfileOverrides(podfile, _log, false);
      }

      final exampleGradle = File(
        p.join(packageRoot, exampleDir, 'android', 'build.gradle'),
      );
      if (exampleGradle.existsSync()) {
        await removeSnapshotsMavenRepository(exampleGradle, _log, false);
      }
    }
  }

  final manifestEntries = <ManifestPackageEntry>[];
  for (final packagePlan in plan.packages) {
    await _applyPublishPrep(packagePlan, ctx, manifestEntries: manifestEntries);
  }

  await writeManifest(
    ctx.repoRoot,
    ReleaseManifest(contentCommit: contentCommit, packages: manifestEntries),
  );

  final finalCommit = await commitAll(
    gitDir,
    ctx.trigger == TriggerContext.patch
        ? 'chore(release): prepare patch release'
        : 'chore(release): publish-prep',
    _log,
    body: versionSummary,
  );
  _log.info('✅ Prepared release on ${target.workingBranch} ($finalCommit)');

  // Validated only now, against the committed tree above -- running this
  // before Commit B existed meant `flutter pub publish --dry-run` always
  // saw the native SDK pin it's about to check as an uncommitted, "modified
  // in git" change and failed on that alone, regardless of whether the
  // package was actually publishable.
  if (!skipPublishValidation) {
    for (final packagePlan in plan.packages) {
      final pkg = packagePlan.package;
      final ok = await runPublishDryRun(pkg.absolutePath(ctx.repoRoot), _log);
      if (!ok) {
        throw StateError(
          'flutter pub publish --dry-run failed for ${pkg.name}. Fix the '
          'reported errors before re-running.',
        );
      }
    }
  }

  costTracker.printSummary(_log);
  for (final warning in staleConsumerWarnings) {
    _log.warning('⚠️ $warning');
  }

  if (dryRun) {
    _log.info(
      'ℹ️ --dry-run: stopping before push/PR. Inspect the commits on '
      '${target.workingBranch} directly.',
    );
    return;
  }

  await pushBranch(gitDir, target.workingBranch, _log);

  final contentTagName = target.contentTagName;
  if (contentTagName != null && contentCommit != null) {
    await pushTag(gitDir, contentTagName, contentCommit, _log);
  }

  final prBase = target.prBase;
  if (prBase == null) {
    _log.info('✅ Pushed ${target.workingBranch}.');
    return;
  }

  final title = _prTitle(plan.packages);
  final body = _prBody(
    plan.packages,
    staleConsumerWarnings,
    publishValidationSkipped: skipPublishValidation,
  );
  final prUrl = await github.createPullRequest(
    _log,
    base: prBase,
    head: target.workingBranch,
    title: title,
    body: body,
  );
  _log.info('✅ Opened release PR: $prUrl');
}

Future<void> _applyContentChanges(
  PackagePlan packagePlan,
  RunContext ctx,
  List<PackageGroup> allGroups, {
  required GithubCommandWrapper github,
  required AiGatewayClient aiGatewayClient,
  required LlmCostTracker costTracker,
  required List<StaleConsumerWarning> staleConsumerWarnings,
}) async {
  final pkg = packagePlan.package;
  final packageRoot = pkg.absolutePath(ctx.repoRoot);

  final entries = await generateChangelogForPackage(
    aiGatewayClient,
    packagePlan,
    github: github,
    logger: _log,
    costTracker: costTracker,
  );
  await prependChangelogSection(
    File(p.join(packageRoot, 'CHANGELOG.md')),
    packagePlan.newVersion,
    renderChangelogSection(entries),
    _log,
    false,
  );

  final updatedVersions = await updateVersions(
    packageRoot,
    packagePlan.newVersion,
    _log,
    false,
  );
  if (!updatedVersions) {
    throw StateError(
      'Failed to update version for ${pkg.name} at $packageRoot',
    );
  }

  // Raise the app-facing package's lower bound on this package, if it's a
  // releasing federated sibling. Not applicable on patch branches (patch
  // versions stay within existing caret ranges) or to a group's own
  // app-facing package (nothing depends on itself).
  if (ctx.trigger != TriggerContext.patch &&
      pkg.role != PackageRole.appFacing) {
    final group = allGroups.firstWhere((g) => g.key == pkg.groupKey);
    final appFacing = group.members.firstWhere(
      (m) => m.role == PackageRole.appFacing,
    );
    await bumpDependentConstraint(
      File(p.join(appFacing.absolutePath(ctx.repoRoot), 'pubspec.yaml')),
      pkg.name,
      packagePlan.newVersion,
      _log,
      false,
    );
  }

  if (ctx.trigger != TriggerContext.patch) {
    staleConsumerWarnings.addAll(
      await findStaleConsumerWarnings(
        allGroups: allGroups,
        repoRoot: ctx.repoRoot,
        releasingPackage: pkg,
        newVersion: packagePlan.newVersion,
      ),
    );
  }

  final iosVersion = packagePlan.nativeSdkDeltas
      .where((d) => d.sdk == NativeSdk.ios)
      .firstOrNullResolvedVersion();
  final androidVersion = packagePlan.nativeSdkDeltas
      .where((d) => d.sdk == NativeSdk.android)
      .firstOrNullResolvedVersion();
  final cppVersion = packagePlan.nativeSdkDeltas
      .where((d) => d.sdk == NativeSdk.cpp)
      .firstOrNullResolvedVersion();
  if (iosVersion != null || androidVersion != null || cppVersion != null) {
    await updateNativeSdkVersionsMd(
      File(p.join(packageRoot, 'NATIVE_SDK_VERSIONS.md')),
      packagePlan.newVersion,
      _log,
      false,
      iosVersion: iosVersion,
      androidVersion: androidVersion,
      cppVersion: cppVersion,
    );
    await updateReadmeSdkTable(
      File(p.join(packageRoot, 'README.md')),
      _log,
      false,
      iosVersion: iosVersion,
      androidVersion: androidVersion,
      cppVersion: cppVersion,
    );
  }
}

extension NativeSdkDeltaResolution on Iterable<NativeSdkDelta> {
  /// The version to record in NATIVE_SDK_VERSIONS.md: the first delta's
  /// target, or its current declaration if this run isn't pinning one
  /// (e.g. a patch with no override). Null if there's no delta for this
  /// SDK at all, or no declaration to fall back to.
  String? firstOrNullResolvedVersion() {
    for (final delta in this) {
      // currentDeclaration is a raw constraint (CocoaPods' `~> 3.5.0`,
      // SPM's `from: "3.0.0"`, ...), not a bare version -- normalize it
      // the same way a real target already is.
      return delta.targetVersion ?? normalizeVersion(delta.currentDeclaration);
    }
    return null;
  }
}

Future<void> _applyPublishPrep(
  PackagePlan packagePlan,
  RunContext ctx, {
  required List<ManifestPackageEntry> manifestEntries,
}) async {
  final pkg = packagePlan.package;

  for (final delta in packagePlan.nativeSdkDeltas) {
    final targetVersion = delta.targetVersion;
    if (targetVersion == null) continue;

    for (final file in delta.files) {
      switch (delta.sdk) {
        case NativeSdk.ios:
          if (file.path.endsWith('.podspec')) {
            await pinIosPodspecVersion(file, targetVersion, _log, false);
          } else {
            await pinIosSpmVersion(file, targetVersion, _log, false);
          }
          break;
        case NativeSdk.android:
          await pinAndroidGradleVersion(file, targetVersion, _log, false);
          // The package's own build.gradle can inject a snapshots repo into
          // every consuming app's build via `rootProject.allprojects` --
          // fine for day-to-day development against an unreleased
          // dd-sdk-android build, but a release must not ship pinned to an
          // exact version while still willing to resolve a newer snapshot.
          await removeSnapshotsMavenRepository(file, _log, false);
          break;
        case NativeSdk.cpp:
          final targetSha = delta.targetSha;
          if (targetSha == null) continue;
          await pinCppVersion(file, targetVersion, targetSha, _log, false);
          break;
      }
    }
  }

  manifestEntries.add(
    ManifestPackageEntry(
      package: pkg.name,
      fromVersion: packagePlan.currentVersion,
      toVersion: packagePlan.newVersion,
      sourceBranch: ctx.currentBranch,
      prerelease: packagePlan.bumpLevel == VersionBumpType.prerelease,
    ),
  );
}

String _prTitle(List<PackagePlan> packages) {
  if (packages.length == 1) {
    final p = packages.single;
    return 'release: ${p.package.name} ${p.newVersion}';
  }
  return 'release: ${packages.length} packages';
}

/// Plain-text "what's shipping" list shared by both Commit A and Commit
/// B's commit messages, so `git log` on either one shows the packages and
/// versions it belongs to without needing the other commit for context.
String _versionSummary(List<PackagePlan> packages) => packages
    .map((p) {
      final bump = p.bumpLevel?.name ?? 'first release';
      return '- ${p.package.name}: ${p.currentVersion} -> ${p.newVersion} '
          '($bump)';
    })
    .join('\n');

String _prBody(
  List<PackagePlan> packages,
  List<StaleConsumerWarning> staleConsumerWarnings, {
  required bool publishValidationSkipped,
}) {
  final buffer = StringBuffer();

  buffer.writeln('## Versions');
  buffer.writeln();
  buffer.writeln('| Package | Current | New | Bump |');
  buffer.writeln('|---|---|---|---|');
  for (final p in packages) {
    final bump = p.bumpLevel?.name ?? 'first release';
    buffer.writeln(
      '| ${p.package.name} | ${p.currentVersion} | ${p.newVersion} | $bump |',
    );
  }

  final nativeDeltas = packages.expand(
    (p) => p.nativeSdkDeltas.where((d) => d.targetVersion != null),
  );
  if (nativeDeltas.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('## Native SDK deltas');
    buffer.writeln();
    for (final delta in nativeDeltas) {
      buffer.writeln('- $delta');
    }
  }

  if (staleConsumerWarnings.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('## ⚠️ Stale consumer constraints');
    buffer.writeln();
    for (final warning in staleConsumerWarnings) {
      buffer.writeln('- $warning');
    }
  }

  final allWarnings = packages.expand((p) => p.warnings);
  if (allWarnings.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('## ⚠️ Warnings');
    buffer.writeln();
    for (final warning in allWarnings) {
      buffer.writeln('- $warning');
    }
  }

  buffer.writeln();
  buffer.writeln(
    publishValidationSkipped
        ? '⚠️ `flutter pub publish --dry-run` was skipped '
              '(--skip-publish-validation) -- not verified for any package '
              'above.'
        : '`flutter pub publish --dry-run` passed for every package above.',
  );

  return buffer.toString();
}
