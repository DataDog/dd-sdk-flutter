// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:path/path.dart' as p;
import 'package:releaser/native_sdk.dart';
import 'package:releaser/release_plan.dart';
import 'package:test/test.dart';
import 'package:version/version.dart';

import 'support/fixture_repo.dart';

const _iosPodspecWithDatadogDependency = '''
Pod::Spec.new do |s|
  s.dependency 'DatadogCore', '~> 3'
end
''';

const _windowsCMakeListsWithGitTag = '''
FetchContent_Declare(dd-sdk-cpp
  GIT_REPOSITORY https://github.com/DataDog/dd-sdk-cpp.git
  GIT_TAG        develop)
''';

const _packageSwiftWithDatadogDependency = '''
let package = Package(
    dependencies: [
        .package(url: "https://github.com/Datadog/dd-sdk-ios.git", from: "3.0.0")
    ]
)
''';

void main() {
  late FixtureRepo fixture;

  setUp(() async {
    fixture = await FixtureRepo.create();
  });

  tearDown(() => fixture.delete());

  /// Stands in for pub.dev. Anything not named here has never been published,
  /// which is the fixture's default and the federated sub-packages' real
  /// state.
  PublishedVersionsGateway publishedAs(Map<String, List<String>> byPackage) =>
      (name) async => PublishedVersions(
        (byPackage[name] ?? const []).map(Version.parse).toList(),
      );

  Future<ReleasePlan> plan(
    RunContext ctx, {
    Map<String, List<String>> published = const {},
    Future<String> Function(String repoSlug)? fetchLatestNativeSdkVersion,
    Future<String> Function(String repoSlug, String ref)? resolveCommitSha,
    Future<bool> Function(String repoSlug, String version)? releaseExists,
  }) async => computeReleasePlan(
    ctx,
    gitDir: await fixture.gitDir,
    publishedVersions: publishedAs(published),
    nativeSdkGateways: NativeSdkGateways(
      fetchLatest:
          fetchLatestNativeSdkVersion ??
          (repoSlug) => throw StateError('fetchLatest not stubbed'),
      resolveCommitSha:
          resolveCommitSha ??
          (repoSlug, ref) => throw StateError('resolveCommitSha not stubbed'),
      releaseExists: releaseExists ?? (repoSlug, version) async => true,
    ),
  );

  RunContext mainlineCtx({
    List<String> requestedPackages = const [],
    String? bumpTypeOverride,
    String? iosSdkVersionOverride,
    String? cppVersionOverride,
  }) => RunContext(
    repoRoot: fixture.root.path,
    trigger: TriggerContext.mainline,
    currentBranch: 'develop',
    requestedPackages: requestedPackages,
    bumpTypeOverride: bumpTypeOverride,
    iosSdkVersionOverride: iosSdkVersionOverride,
    cppVersionOverride: cppVersionOverride,
  );

  group('mainline, version computation', () {
    test('bumps from the published version, not from pubspec', () async {
      // The heart of the rework. pubspec says 2.3.0; every release ends by
      // bumping pubspec to a "next potential" version, so it routinely names
      // something that was never shipped. pub.dev says 2.2.0 shipped last.
      await fixture.tag('datadog_dio/v2.2.0');
      fixture.writeFile('packages/datadog_dio/CHANGES', 'work');
      await fixture.commit('feat: something new');

      final result = await plan(
        mainlineCtx(),
        published: {
          'datadog_dio': ['2.1.0', '2.2.0'],
        },
      );

      final dio = result.packages.singleWhere(
        (e) => e.package.name == 'datadog_dio',
      );
      expect(dio.currentVersion, '2.2.0');
      expect(dio.newVersion, '2.3.0');
      expect(dio.bumpLevel, VersionBumpType.minor);
    });

    test('a never-published package takes its version from pubspec', () async {
      fixture.writeFile('packages/datadog_dio/CHANGES', 'work');
      await fixture.commit('feat: the first release');

      final result = await plan(
        mainlineCtx(requestedPackages: ['datadog_dio']),
      );

      expect(result.packages.single.newVersion, '2.3.0');
      expect(result.packages.single.currentVersion, '2.3.0');
    });

    test(
      'a package with only pre-releases published reports no bump level',
      () async {
        // datadog_session_replay's real shape: 14 previews, never a stable
        // release. The version comes from pubspec untouched, so reporting the
        // commits' `major` aggregate would misdescribe what happened.
        fixture.writeFile('packages/datadog_dio/CHANGES', 'work');
        await fixture.commit('feat!: breaking work');

        final result = await plan(
          mainlineCtx(requestedPackages: ['datadog_dio']),
          published: {
            'datadog_dio': ['1.0.0-preview.1', '1.0.0-preview.2'],
          },
        );

        expect(result.packages.single.newVersion, '2.3.0'); // pubspec
        expect(result.packages.single.currentVersion, '1.0.0-preview.2');
        expect(result.packages.single.bumpLevel, isNull);
      },
    );

    test('a published pre-release is not mainline\'s baseline', () async {
      // A v4 line published betas, then merged back. Mainline computes from
      // the last stable release; the line's own breaking commits carry it to
      // the major it was leading up to. No promotion special case needed.
      await fixture.tag('datadog_flutter_plugin/v3.5.0');
      fixture.writeFile(
        'packages/datadog_flutter_plugin/datadog_flutter_plugin/CHANGES',
        'the v4 work',
      );
      await fixture.commit('feat!: the federation rework');

      final result = await plan(
        mainlineCtx(requestedPackages: ['datadog_flutter_plugin']),
        published: {
          'datadog_flutter_plugin': ['3.5.0', '4.0.0-beta.1', '4.0.0-beta.2'],
        },
      );

      expect(result.packages.single.newVersion, '4.0.0');
      expect(result.packages.single.bumpLevel, VersionBumpType.major);
    });
  });

  group('mainline, package selection', () {
    test('--all excludes packages with no qualifying commits', () async {
      await fixture.tag('datadog_dio/v2.2.0');
      fixture.writeFile('packages/datadog_dio/CHANGES', 'a real feature');
      await fixture.commit('feat: add a real feature to dio');

      final result = await plan(
        mainlineCtx(),
        published: {
          'datadog_dio': ['2.2.0'],
        },
      );
      final names = result.packages.map((e) => e.package.name);

      expect(names, contains('datadog_dio'));
      expect(names, isNot(contains('lonely_ios')));
    });

    test('BUMP_TYPE without an explicit PACKAGES list is rejected', () async {
      await expectLater(
        plan(mainlineCtx(bumpTypeOverride: 'major')),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('requires an explicit PACKAGES list'),
          ),
        ),
      );
    });

    test(
      'a native SDK override includes only packages shipping that SDK',
      () async {
        fixture.writeFile(
          'packages/datadog_flutter_plugin/datadog_flutter_plugin_ios/ios/'
          'datadog_flutter_plugin_ios.podspec',
          _iosPodspecWithDatadogDependency,
        );
        await fixture.commit('chore: add podspec fixture');

        final result = await plan(mainlineCtx(iosSdkVersionOverride: '3.12.0'));
        final names = result.packages.map((e) => e.package.name);

        expect(names, contains('datadog_flutter_plugin_ios'));
        expect(names, isNot(contains('lonely_ios')));
        expect(names, isNot(contains('datadog_dio')));
      },
    );
  });

  group('mainline, native SDK deltas', () {
    setUp(() async {
      fixture.writeFile(
        'packages/datadog_flutter_plugin/datadog_flutter_plugin_ios/ios/'
        'datadog_flutter_plugin_ios.podspec',
        _iosPodspecWithDatadogDependency,
      );
      await fixture.commit('chore: add podspec fixture');
    });

    test(
      'resolves a target, with no comparison against the current pin',
      () async {
        final result = await plan(
          mainlineCtx(requestedPackages: ['datadog_flutter_plugin_ios']),
          fetchLatestNativeSdkVersion: (repoSlug) async {
            expect(repoSlug, 'DataDog/dd-sdk-ios');
            return '3.13.0';
          },
        );

        final delta = result.packages.single.nativeSdkDeltas.single;
        expect(delta.sdk, NativeSdk.ios);
        expect(delta.targetVersion, '3.13.0');
      },
    );

    test(
      'a Package.swift alongside the podspec is carried for rewriting',
      () async {
        fixture.writeFile(
          'packages/datadog_flutter_plugin/datadog_flutter_plugin_ios/ios/'
          'datadog_flutter_plugin_ios/Package.swift',
          _packageSwiftWithDatadogDependency,
        );
        await fixture.commit('chore: add Package.swift fixture');

        final result = await plan(
          mainlineCtx(
            requestedPackages: ['datadog_flutter_plugin_ios'],
            iosSdkVersionOverride: '3.12.0',
          ),
        );

        expect(
          result.packages.single.nativeSdkDeltas.single.files.map(
            (f) => p.basename(f.path),
          ),
          ['datadog_flutter_plugin_ios.podspec', 'Package.swift'],
        );
      },
    );

    test('C++ resolves the target tag to a commit SHA', () async {
      fixture.writeFile(
        'packages/datadog_flutter_plugin/datadog_flutter_plugin_desktop/'
        'windows/CMakeLists.txt',
        _windowsCMakeListsWithGitTag,
      );
      await fixture.commit('chore: add CMakeLists fixture');

      final result = await plan(
        mainlineCtx(
          requestedPackages: ['datadog_flutter_plugin_desktop'],
          cppVersionOverride: 'v1.4.0',
        ),
        resolveCommitSha: (repoSlug, ref) async {
          expect(repoSlug, 'DataDog/dd-sdk-cpp');
          expect(ref, 'v1.4.0');
          return 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
        },
      );

      final delta = result.packages.single.nativeSdkDeltas.single;
      expect(delta.targetVersion, 'v1.4.0');
      expect(delta.targetSha, 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2');
    });
  });

  group('missing tag for a published version', () {
    test(
      'falls back to the newest version that is tagged, and says so',
      () async {
        // pub.dev knows 2.2.0 but no tag was ever pushed for it -- two of
        // datadog_flutter_plugin's 65 published versions are in that state.
        await fixture.tag('datadog_dio/v2.1.0');
        fixture.writeFile('packages/datadog_dio/CHANGES', 'work');
        await fixture.commit('fix: something');

        final result = await plan(
          mainlineCtx(requestedPackages: ['datadog_dio']),
          published: {
            'datadog_dio': ['2.1.0', '2.2.0'],
          },
        );

        expect(result.packages.single.newVersion, '2.2.1');
        expect(
          result.packages.single.warnings.single,
          allOf(
            contains('2.2.0 is published but has no tag'),
            contains('falls back to v2.1.0'),
          ),
        );
      },
    );

    test('no warning when the baseline resolves cleanly', () async {
      await fixture.tag('datadog_dio/v2.2.0');
      fixture.writeFile('packages/datadog_dio/CHANGES', 'work');
      await fixture.commit('fix: something');

      final result = await plan(
        mainlineCtx(requestedPackages: ['datadog_dio']),
        published: {
          'datadog_dio': ['2.2.0'],
        },
      );

      expect(result.packages.single.warnings, isEmpty);
    });
  });

  group('patch branch', () {
    RunContext patchCtx(String branch) => RunContext(
      repoRoot: fixture.root.path,
      trigger: TriggerContext.patch,
      currentBranch: branch,
    );

    test('increments the patch level of its own release line', () async {
      await fixture.tag('datadog_dio/v2.1.2');
      fixture.writeFile('packages/datadog_dio/CHANGES', 'a fix');
      await fixture.commit('fix: a cherry-picked fix');

      final result = await plan(
        patchCtx('release/datadog_dio/v2.1.x'),
        // Mainline has since cut 2.2.0 and a 3.0 line; neither may be picked.
        published: {
          'datadog_dio': ['2.1.0', '2.1.2', '2.2.0', '3.0.0'],
        },
      );

      expect(result.packages.single.newVersion, '2.1.3');
      expect(result.packages.single.bumpLevel, VersionBumpType.patch);
    });

    test(
      'fails when nothing has been published on the branch\'s line',
      () async {
        // release/datadog_dio/v2.1.x with only 2.2.0 published. Falling back to
        // pubspec here produced a version outside the branch's own line.
        await expectLater(
          plan(
            patchCtx('release/datadog_dio/v2.1.x'),
            published: {
              'datadog_dio': ['2.2.0'],
            },
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('no 2.1 release'),
                contains('nothing here to patch'),
              ),
            ),
          ),
        );
      },
    );

    test('fails loudly if a feat commit snuck onto the patch branch', () async {
      await fixture.tag('datadog_dio/v2.1.2');
      fixture.writeFile('packages/datadog_dio/CHANGES', 'a feature');
      await fixture.commit('feat: does not belong here');

      await expectLater(
        plan(
          patchCtx('release/datadog_dio/v2.1.x'),
          published: {
            'datadog_dio': ['2.1.2'],
          },
        ),
        throwsStateError,
      );
    });

    test('BUMP_TYPE is rejected rather than silently ignored', () async {
      await expectLater(
        plan(
          RunContext(
            repoRoot: fixture.root.path,
            trigger: TriggerContext.patch,
            currentBranch: 'release/datadog_dio/v2.1.x',
            bumpTypeOverride: 'major',
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('does not apply on a patch branch'),
          ),
        ),
      );
    });

    test('a malformed branch name throws', () async {
      await expectLater(plan(patchCtx('release/whatever')), throwsStateError);
    });
  });

  group('pre-release branch', () {
    RunContext preReleaseCtx({
      String? prereleaseLabel,
      List<String> requestedPackages = const ['datadog_flutter_plugin'],
    }) => RunContext(
      repoRoot: fixture.root.path,
      trigger: TriggerContext.preRelease,
      currentBranch: 'v4',
      requestedPackages: requestedPackages,
      prereleaseLabel: prereleaseLabel,
    );

    /// The v4 shape: a stable 3.5.0 behind us, breaking work on the branch.
    Future<void> breakingWorkSince3_5_0() async {
      await fixture.tag('datadog_flutter_plugin/v3.5.0');
      fixture.writeFile(
        'packages/datadog_flutter_plugin/datadog_flutter_plugin/CHANGES',
        'the v4 work',
      );
      await fixture.commit('feat!: the federation rework');
    }

    test('computes the target from the last stable release', () async {
      // 3.5.0 + a breaking commit -> 4.0.0, then the label starts the counter.
      // pubspec is never consulted for the target.
      await breakingWorkSince3_5_0();

      final result = await plan(
        preReleaseCtx(prereleaseLabel: 'beta'),
        published: {
          'datadog_flutter_plugin': ['3.5.0'],
        },
      );

      expect(result.packages.single.newVersion, '4.0.0-beta.1');
      expect(result.packages.single.bumpLevel, VersionBumpType.prerelease);
    });

    test('continues an existing counter', () async {
      await breakingWorkSince3_5_0();
      await fixture.tag('datadog_flutter_plugin/v4.0.0-beta.1');
      fixture.writeFile(
        'packages/datadog_flutter_plugin/datadog_flutter_plugin/CHANGES',
        'more',
      );
      await fixture.commit('fix: more v4 work');

      final result = await plan(
        preReleaseCtx(),
        published: {
          'datadog_flutter_plugin': ['3.5.0', '4.0.0-beta.1'],
        },
      );

      expect(result.packages.single.newVersion, '4.0.0-beta.2');
    });

    test('a concurrent pre-release line does not derail this one', () async {
      // A `v5` effort publishing 5.0.0-alpha.1 while `v4` is still shipping
      // betas. It is the newest release overall, but says nothing about
      // whether 4.0.0-beta.2 moves *this* line forward -- scoping the
      // monotonicity check globally rejected it and blocked v4 entirely.
      await breakingWorkSince3_5_0();
      await fixture.tag('datadog_flutter_plugin/v4.0.0-beta.1');

      final result = await plan(
        preReleaseCtx(prereleaseLabel: 'beta'),
        published: {
          'datadog_flutter_plugin': ['3.5.0', '4.0.0-beta.1', '5.0.0-alpha.1'],
        },
      );

      expect(result.packages.single.newVersion, '4.0.0-beta.2');
    });

    test(
      'a concurrent line is not used as the commit-range baseline',
      () async {
        // Same shape, but the v5 tag exists and this line has new work since
        // its own last beta. Measuring "what's new" from the v5 tag would
        // report the wrong commits into the changelog.
        await breakingWorkSince3_5_0();
        await fixture.tag('datadog_flutter_plugin/v4.0.0-beta.1');
        await fixture.tag('datadog_flutter_plugin/v5.0.0-alpha.1');
        fixture.writeFile(
          'packages/datadog_flutter_plugin/datadog_flutter_plugin/CHANGES',
          'more v4 work',
        );
        await fixture.commit('fix: one more v4 fix');

        final result = await plan(
          preReleaseCtx(),
          published: {
            'datadog_flutter_plugin': [
              '3.5.0',
              '4.0.0-beta.1',
              '5.0.0-alpha.1',
            ],
          },
        );

        expect(result.packages.single.newVersion, '4.0.0-beta.2');
        // Only the work since this line's own beta, not since the v5 tag.
        expect(result.packages.single.contributingCommits, hasLength(1));
      },
    );

    test('a label that would move the version backward is rejected', () async {
      await breakingWorkSince3_5_0();

      await expectLater(
        plan(
          preReleaseCtx(prereleaseLabel: 'beta'),
          published: {
            'datadog_flutter_plugin': ['3.5.0', '4.0.0-beta.1', '4.0.0-rc.1'],
          },
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('would not move forward'),
          ),
        ),
      );
    });

    test('the first pre-release against a target requires a label', () async {
      await breakingWorkSince3_5_0();

      await expectLater(
        plan(
          preReleaseCtx(),
          published: {
            'datadog_flutter_plugin': ['3.5.0'],
          },
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('PRERELEASE_LABEL is required'),
          ),
        ),
      );
    });

    test('--all excludes packages with nothing to ship', () async {
      await breakingWorkSince3_5_0();

      final result = await plan(
        preReleaseCtx(prereleaseLabel: 'beta', requestedPackages: const []),
        published: {
          'datadog_flutter_plugin': ['3.5.0'],
        },
      );
      final names = result.packages.map((e) => e.package.name);

      expect(names, contains('datadog_flutter_plugin'));
      // Untouched -- handing it a beta would publish a release nobody asked
      // for, and without a label it would abort the whole plan.
      expect(names, isNot(contains('lonely_ios')));
    });

    test("--all without a label doesn't abort on a package that was never part "
        'of the pre-release line', () async {
      // Omitting the label to continue an existing counter is a documented
      // workflow, so an untouched package with no tag at the target must not
      // abort the whole plan.
      await breakingWorkSince3_5_0();
      await fixture.tag('datadog_flutter_plugin/v4.0.0-beta.1');

      final result = await plan(
        preReleaseCtx(requestedPackages: const []),
        published: {
          'datadog_flutter_plugin': ['3.5.0', '4.0.0-beta.1'],
        },
      );

      expect(
        result.packages.map((e) => e.package.name),
        isNot(contains('lonely_ios')),
      );
    });

    test('BUMP_TYPE is rejected rather than silently ignored', () async {
      await expectLater(
        plan(
          RunContext(
            repoRoot: fixture.root.path,
            trigger: TriggerContext.preRelease,
            currentBranch: 'v4',
            prereleaseLabel: 'beta',
            bumpTypeOverride: 'minor',
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('does not apply on a pre-release branch'),
          ),
        ),
      );
    });
  });
}
