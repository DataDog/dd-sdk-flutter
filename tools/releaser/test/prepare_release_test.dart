// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// End-to-end coverage of the commit-A/commit-B split: runs
// `prepareRelease` for real against a `FixtureRepo`, with
// `dryRun: true` (stops short of push/PR -- no real remote or `gh` in
// this environment) and `skipPublishValidation: true` (no real Flutter
// toolchain here). The package under test is requested explicitly with
// zero qualifying commits, so the changelog pipeline's PR-resolution path
// is never exercised (no `gh` calls) -- see `_applyContentChanges`.

import 'package:releaser/github_cmd_wrapper.dart';
import 'package:releaser/llm/ai_gateway.dart';
import 'package:releaser/manifest.dart';
import 'package:releaser/native_sdk.dart';
import 'package:releaser/release_plan.dart';
import 'package:test/test.dart';

import '../bin/prepare_release.dart';
import 'support/fixture_repo.dart';

class _NeverCalledAiGatewayClient implements AiGatewayClient {
  @override
  Future<StructuredResponse> createStructuredMessage({
    required String prompt,
    required Map<String, dynamic> schema,
    String model = defaultModel,
    int maxTokens = 4096,
  }) => throw StateError(
    'AiGatewayClient should not be called -- no PRs or native SDK deltas '
    'to summarize for this package.',
  );
}

void main() {
  late FixtureRepo fixture;

  setUp(() async {
    fixture = await FixtureRepo.create();
    // prependChangelogSection requires the file to already exist.
    fixture.writeFile('packages/datadog_dio/CHANGELOG.md', '');
    await fixture.commit('chore: seed CHANGELOG.md');
  });

  tearDown(() => fixture.delete());

  test(
    'splits output into a content commit and a publish-prep commit',
    () async {
      final gitDir = await fixture.gitDir;
      final beforeSha = (await gitDir.runCommand([
        'rev-parse',
        'HEAD',
      ])).stdout.toString().trim();

      await prepareRelease(
        RunContext(
          repoRoot: fixture.root.path,
          trigger: TriggerContext.mainline,
          currentBranch: 'develop',
          // Never published + zero qualifying commits would normally exclude
          // this package -- explicit request overrides that (see
          // release_plan.dart's isExplicitlyRequested).
          requestedPackages: ['datadog_dio'],
        ),
        gitDir: gitDir,
        github: GithubCommandWrapper(fixture.root.path),
        aiGatewayClient: _NeverCalledAiGatewayClient(),
        dryRun: true,
        skipPublishValidation: true,
      );

      final log = await gitDir.runCommand([
        'log',
        '--format=%H %s',
        '$beforeSha..HEAD',
      ]);
      final commitLines = (log.stdout as String)
          .trim()
          .split('\n')
          .where((l) => l.isNotEmpty)
          .toList();

      // Oldest-first in `git log`'s default order is newest-first; commit A
      // is the *older* of the two (it lands before commit B).
      expect(commitLines, hasLength(2));
      final contentCommitLine = commitLines[1];
      final publishPrepCommitLine = commitLines[0];
      expect(contentCommitLine, contains('changelog'));
      expect(publishPrepCommitLine, contains('publish-prep'));

      final contentSha = contentCommitLine.split(' ').first;

      // Commit A's diff must never touch dependency_overrides, native
      // pinning, or the manifest -- that's what makes a cherry-pick of it
      // safe to backport (Phase 2 step 6).
      final contentDiff = await gitDir.runCommand([
        'show',
        '--stat',
        '--format=',
        contentSha,
      ]);
      expect(
        contentDiff.stdout as String,
        isNot(contains('.release/manifest.json')),
      );

      final manifest = await readManifest(fixture.root.path);
      expect(manifest.contentCommit, contentSha);
      expect(manifest.packages, hasLength(1));
      expect(manifest.packages.single.package, 'datadog_dio');

      final changelogFile = await gitDir.runCommand([
        'show',
        'HEAD~1:packages/datadog_dio/CHANGELOG.md',
      ]);
      expect(
        changelogFile.stdout as String,
        contains('Maintenance release; no significant changes.'),
      );
    },
  );

  test(
    'never creates or pushes a branch on a --dry-run mainline run past local commits',
    () async {
      final gitDir = await fixture.gitDir;
      final branchBefore = (await gitDir.currentBranch()).branchName;

      await prepareRelease(
        RunContext(
          repoRoot: fixture.root.path,
          trigger: TriggerContext.mainline,
          currentBranch: 'develop',
          requestedPackages: ['datadog_dio'],
        ),
        gitDir: gitDir,
        github: GithubCommandWrapper(fixture.root.path),
        aiGatewayClient: _NeverCalledAiGatewayClient(),
        dryRun: true,
        skipPublishValidation: true,
      );

      final branchAfter = (await gitDir.currentBranch()).branchName;
      expect(branchAfter, isNot(branchBefore));
      expect(branchAfter, startsWith('release-prep/'));
    },
  );

  test(
    'fails loudly if the releasing package has a committed dependency_overrides block',
    () async {
      fixture.writeFile('packages/datadog_dio/pubspec.yaml', '''
name: datadog_dio
version: 2.3.0
environment:
  sdk: '>=3.0.0 <4.0.0'

dependency_overrides:
  datadog_flutter_plugin:
    path: ../datadog_flutter_plugin/datadog_flutter_plugin
''');
      await fixture.commit('chore: accidentally commit an override');

      final gitDir = await fixture.gitDir;

      expect(
        () => prepareRelease(
          RunContext(
            repoRoot: fixture.root.path,
            trigger: TriggerContext.mainline,
            currentBranch: 'develop',
            requestedPackages: ['datadog_dio'],
          ),
          gitDir: gitDir,
          github: GithubCommandWrapper(fixture.root.path),
          aiGatewayClient: _NeverCalledAiGatewayClient(),
          dryRun: true,
          skipPublishValidation: true,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('dependency_overrides'),
          ),
        ),
      );
    },
  );

  group('firstOrNullResolvedVersion', () {
    // The NATIVE_SDK_VERSIONS.md row this run's package/SDK combination
    // should be recorded with -- exercises the fallback that fixes a
    // patch (or any run where a native SDK isn't moving) from either
    // getting skipped entirely or showing a misleading "-" for an SDK it
    // genuinely ships, just unchanged this cycle.

    test('prefers the target when this run is pinning to one', () {
      final deltas = [
        NativeSdkDelta(
          sdk: NativeSdk.ios,
          targetVersion: '3.16.0',
          currentDeclaration: '~> 3.15.0',
        ),
      ];

      expect(
        deltas
            .where((d) => d.sdk == NativeSdk.ios)
            .firstOrNullResolvedVersion(),
        '3.16.0',
      );
    });

    test('falls back to a normalized current declaration with no target '
        '(e.g. a patch with no override)', () {
      final deltas = [
        NativeSdkDelta(
          sdk: NativeSdk.ios,
          targetVersion: null,
          currentDeclaration: '~> 3.15.0',
        ),
      ];

      expect(
        deltas
            .where((d) => d.sdk == NativeSdk.ios)
            .firstOrNullResolvedVersion(),
        '3.15.0',
      );
    });

    test('is null when this package has no delta for that SDK at all', () {
      final deltas = [
        NativeSdkDelta(sdk: NativeSdk.android, targetVersion: '3.12.1'),
      ];

      expect(
        deltas
            .where((d) => d.sdk == NativeSdk.ios)
            .firstOrNullResolvedVersion(),
        isNull,
      );
    });
  });
}
