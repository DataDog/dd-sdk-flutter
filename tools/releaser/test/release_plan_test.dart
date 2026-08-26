// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:path/path.dart' as p;
import 'package:releaser/native_sdk.dart';
import 'package:releaser/release_plan.dart';
import 'package:test/test.dart';

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

  Future<ReleasePlan> plan(
    RunContext ctx, {
    Future<String> Function(String repoSlug)? fetchLatestNativeSdkVersion,
    Future<String> Function(String repoSlug, String ref)? resolveCommitSha,
    Future<bool> Function(String repoSlug, String version)? releaseExists,
  }) async => computeReleasePlan(
    ctx,
    gitDir: await fixture.gitDir,
    nativeSdkGateways: NativeSdkGateways(
      fetchLatest:
          fetchLatestNativeSdkVersion ??
          (repoSlug) => throw StateError('fetchLatest not stubbed'),
      resolveCommitSha:
          resolveCommitSha ??
          (repoSlug, ref) => throw StateError('resolveCommitSha not stubbed'),
      // Real releaseExists calls `gh`, which isn't available/desired in
      // tests -- default to "yes" unless a test specifically cares.
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

  group('mainline, package selection', () {
    test('--all excludes packages with no qualifying commits', () async {
      fixture.writeFile('packages/datadog_dio/CHANGES', 'a real feature');
      await fixture.commit('feat: add a real feature to dio');

      final result = await plan(mainlineCtx());
      final names = result.packages.map((p) => p.package.name);

      expect(names, contains('datadog_dio'));
      // Nothing but the fixture's own initial chore commit ever touched
      // this -- excluded from an --all run.
      expect(names, isNot(contains('lonely_ios')));
    });

    test(
      'explicitly requesting a package includes it even with nothing new',
      () async {
        final result = await plan(
          mainlineCtx(requestedPackages: ['lonely_ios']),
        );

        expect(result.packages, hasLength(1));
        expect(result.packages.single.package.name, 'lonely_ios');
      },
    );

    test(
      'a native SDK override alone is enough to include a package in --all',
      () async {
        fixture.writeFile(
          'packages/datadog_flutter_plugin/datadog_flutter_plugin_ios/ios/'
          'datadog_flutter_plugin_ios.podspec',
          _iosPodspecWithDatadogDependency,
        );
        await fixture.commit('chore: add podspec fixture');

        final result = await plan(mainlineCtx(iosSdkVersionOverride: '3.12.0'));
        final names = result.packages.map((p) => p.package.name);

        expect(names, contains('datadog_flutter_plugin_ios'));
      },
    );

    test('a native SDK override does not sweep in a package that ships no '
        'manifest for that SDK', () async {
      fixture.writeFile(
        'packages/datadog_flutter_plugin/datadog_flutter_plugin_ios/ios/'
        'datadog_flutter_plugin_ios.podspec',
        _iosPodspecWithDatadogDependency,
      );
      await fixture.commit('chore: add podspec fixture');

      final result = await plan(mainlineCtx(iosSdkVersionOverride: '3.12.0'));
      final names = result.packages.map((p) => p.package.name);

      // Pure-Dart: an IOS_SDK_VERSION has nothing to do with it.
      expect(names, isNot(contains('lonely_ios')));
      expect(names, isNot(contains('datadog_dio')));
    });

    test("an override for one SDK doesn't sweep in a package that only depends "
        'on another', () async {
      fixture.writeFile(
        'packages/datadog_flutter_plugin/datadog_flutter_plugin_ios/ios/'
        'datadog_flutter_plugin_ios.podspec',
        _iosPodspecWithDatadogDependency,
      );
      fixture.writeFile(
        'packages/datadog_flutter_plugin/datadog_flutter_plugin_desktop/'
        'windows/CMakeLists.txt',
        _windowsCMakeListsWithGitTag,
      );
      await fixture.commit('chore: add native dependency fixtures');

      final result = await plan(
        mainlineCtx(cppVersionOverride: 'v1.4.0'),
        resolveCommitSha: (repoSlug, ref) async =>
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
      );
      final names = result.packages.map((p) => p.package.name);

      expect(names, contains('datadog_flutter_plugin_desktop'));
      expect(names, isNot(contains('datadog_flutter_plugin_ios')));
    });

    test('BUMP_TYPE alone does not sweep an otherwise-unqualifying package '
        'into --all', () async {
      // No qualifying commits, no native SDK change, not explicitly
      // requested -- BUMP_TYPE must not be the thing that grants
      // eligibility here, or a targeted override would release every
      // discovered package.
      final result = await plan(mainlineCtx(bumpTypeOverride: 'major'));
      final names = result.packages.map((p) => p.package.name);

      expect(names, isNot(contains('lonely_ios')));
    });
  });

  group('mainline, version computation', () {
    test('mainline with an unknown requested package throws', () async {
      await expectLater(
        computeReleasePlan(
          RunContext(
            repoRoot: fixture.root.path,
            trigger: TriggerContext.mainline,
            currentBranch: 'develop',
            requestedPackages: ['datadog_dio', 'does_not_exist'],
          ),
        ),
        throwsStateError,
      );
    });

    test(
      'a package with no prior tag ships its declared version as-is',
      () async {
        fixture.writeFile('packages/datadog_dio/CHANGES', 'a feature');
        await fixture.commit('feat: add a feature');

        final result = await plan(
          mainlineCtx(requestedPackages: ['datadog_dio']),
        );
        final dio = result.packages.single;

        expect(dio.bumpLevel, VersionBumpType.minor);
        expect(dio.newVersion, '2.3.0'); // unchanged -- first release
      },
    );

    test('a package with a prior tag increments from that tag, not from '
        'whatever pubspec currently says', () async {
      await fixture.tag('datadog_dio/v2.0.0');
      // pubspec still says 2.3.0 (set up by the fixture), simulating
      // drift between the last real tag and an already-bumped pubspec.
      fixture.writeFile('packages/datadog_dio/CHANGES', 'a fix');
      await fixture.commit('fix: correct a bug');

      final result = await plan(
        mainlineCtx(requestedPackages: ['datadog_dio']),
      );
      final dio = result.packages.single;

      expect(dio.bumpLevel, VersionBumpType.patch);
      expect(dio.newVersion, '2.0.1');
    });

    test(
      'BUMP_TYPE override wins over conventional-commit detection',
      () async {
        await fixture.tag('datadog_dio/v2.0.0');
        fixture.writeFile('packages/datadog_dio/CHANGES', 'a fix');
        await fixture.commit('fix: correct a bug');

        final result = await plan(
          mainlineCtx(
            requestedPackages: ['datadog_dio'],
            bumpTypeOverride: 'major',
          ),
        );

        expect(result.packages.single.newVersion, '3.0.0');
      },
    );

    test(
      'an invalid BUMP_TYPE fails loudly rather than defaulting to patch',
      () async {
        await expectLater(
          plan(
            mainlineCtx(
              requestedPackages: ['datadog_dio'],
              bumpTypeOverride: 'oops',
            ),
          ),
          throwsStateError,
        );
      },
    );

    test('BUMP_TYPE=prerelease is rejected on mainline', () async {
      await expectLater(
        plan(
          mainlineCtx(
            requestedPackages: ['datadog_dio'],
            bumpTypeOverride: 'prerelease',
          ),
        ),
        throwsStateError,
      );
    });

    test('explicitly requested with nothing qualifying and a prior tag '
        'still gets a maintenance patch bump', () async {
      await fixture.tag('lonely_ios/v1.1.0');

      final result = await plan(mainlineCtx(requestedPackages: ['lonely_ios']));

      expect(result.packages.single.bumpLevel, VersionBumpType.patch);
      expect(result.packages.single.newVersion, '1.1.1');
    });

    test(
      "a pre-release line's tags are not mainline's baseline -- the last "
      'stable release is, and the merged line\'s own commits carry the bump',
      () async {
        // A long-lived `v4` line ships betas, then merges back into mainline.
        await fixture.tag('datadog_flutter_plugin/v3.5.0');
        fixture.writeFile(
          'packages/datadog_flutter_plugin/datadog_flutter_plugin/CHANGES',
          'the v4 work',
        );
        await fixture.commit('feat!: the federation rework');
        await fixture.tag('datadog_flutter_plugin/v4.0.0-beta.3');

        final result = await plan(
          mainlineCtx(requestedPackages: ['datadog_flutter_plugin']),
        );

        // 3.5.0 + the breaking commit, not 4.0.0-beta.3 + a patch bump.
        expect(result.packages.single.newVersion, '4.0.0');
        expect(result.packages.single.bumpLevel, VersionBumpType.major);
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

    test('an override is used directly, without calling fetchLatest', () async {
      final result = await plan(
        mainlineCtx(
          requestedPackages: ['datadog_flutter_plugin_ios'],
          iosSdkVersionOverride: '3.12.0',
        ),
        fetchLatestNativeSdkVersion: (_) =>
            throw StateError('should not be called when overridden'),
      );

      final delta = result.packages.single.nativeSdkDeltas.single;
      expect(delta.sdk, NativeSdk.ios);
      expect(delta.targetVersion, '3.12.0');
    });

    test('with no override, resolves via fetchLatest', () async {
      final result = await plan(
        mainlineCtx(requestedPackages: ['datadog_flutter_plugin_ios']),
        fetchLatestNativeSdkVersion: (repoSlug) async {
          expect(repoSlug, 'DataDog/dd-sdk-ios');
          return 'v3.13.0';
        },
      );

      final delta = result.packages.single.nativeSdkDeltas.single;
      expect(delta.targetVersion, 'v3.13.0');
    });

    test('a package with no native dependency files has no deltas', () async {
      final result = await plan(
        mainlineCtx(requestedPackages: ['datadog_dio']),
      );
      expect(result.packages.single.nativeSdkDeltas, isEmpty);
    });

    test(
      'a Package.swift alongside the podspec is picked up for rewriting',
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

        final delta = result.packages.single.nativeSdkDeltas.single;
        expect(delta.targetVersion, '3.12.0');
        expect(delta.files.map((f) => p.basename(f.path)), [
          'datadog_flutter_plugin_ios.podspec',
          'Package.swift',
        ]);
      },
    );
  });

  group('mainline, C++ native SDK delta (CMake GIT_TAG + SHA)', () {
    setUp(() async {
      fixture.writeFile(
        'packages/datadog_flutter_plugin/datadog_flutter_plugin_desktop/'
        'windows/CMakeLists.txt',
        _windowsCMakeListsWithGitTag,
      );
      await fixture.commit('chore: add CMakeLists fixture');
    });

    test('resolves the target tag to a commit SHA', () async {
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

    test(
      'does not resolve a SHA when there is no target (patch, no override)',
      () async {
        final result = await plan(
          RunContext(
            repoRoot: fixture.root.path,
            trigger: TriggerContext.patch,
            currentBranch: 'release/datadog_flutter_plugin_desktop/v1.0.x',
          ),
          resolveCommitSha: (repoSlug, ref) =>
              throw StateError('should not be called with no target'),
        );

        final delta = result.packages.single.nativeSdkDeltas.single;
        expect(delta.targetVersion, isNull);
        expect(delta.targetSha, isNull);
      },
    );

    test('every platform CMakeLists is carried for rewriting, not just the '
        'first', () async {
      fixture.writeFile(
        'packages/datadog_flutter_plugin/datadog_flutter_plugin_desktop/'
        'linux/CMakeLists.txt',
        _windowsCMakeListsWithGitTag,
      );
      await fixture.commit('chore: add the linux CMakeLists fixture');

      final result = await plan(
        mainlineCtx(
          requestedPackages: ['datadog_flutter_plugin_desktop'],
          cppVersionOverride: 'v1.4.0',
        ),
        resolveCommitSha: (repoSlug, ref) async =>
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
      );

      final delta = result.packages.single.nativeSdkDeltas.single;
      expect(delta.files.map((f) => p.basename(p.dirname(f.path))), [
        'windows',
        'linux',
      ]);
    });
  });

  group('patch branch', () {
    RunContext patchCtx(String branch) => RunContext(
      repoRoot: fixture.root.path,
      trigger: TriggerContext.patch,
      currentBranch: branch,
    );

    test('resolves the single named package with no grouping', () async {
      final result = await plan(patchCtx('release/datadog_dio/v1.1.x'));
      expect(result.packages, hasLength(1));
      expect(result.packages.single.package.name, 'datadog_dio');
    });

    test('on a federated member still selects only that one package', () async {
      final result = await plan(
        patchCtx('release/datadog_flutter_plugin_ios/v1.0.x'),
      );
      expect(result.packages, hasLength(1));
      expect(result.packages.single.package.name, 'datadog_flutter_plugin_ios');
    });

    test('a malformed branch name throws', () async {
      await expectLater(plan(patchCtx('not-a-patch-branch')), throwsStateError);
    });

    test('naming an unknown package throws', () async {
      await expectLater(
        plan(patchCtx('release/does_not_exist/v1.0.x')),
        throwsStateError,
      );
    });

    test('forces a patch bump, incrementing from the last tag', () async {
      await fixture.tag('datadog_dio/v2.0.0');
      fixture.writeFile('packages/datadog_dio/CHANGES', 'a fix');
      await fixture.commit('fix: a cherry-picked fix');

      final result = await plan(patchCtx('release/datadog_dio/v2.0.x'));

      expect(result.packages, hasLength(1));
      expect(result.packages.single.bumpLevel, VersionBumpType.patch);
      expect(result.packages.single.newVersion, '2.0.1');
    });

    test('fails loudly if a feat commit snuck onto the patch branch', () async {
      await fixture.tag('datadog_dio/v2.0.0');
      fixture.writeFile('packages/datadog_dio/CHANGES', 'oops');
      await fixture.commit('feat: this should not be on a patch branch');

      await expectLater(
        plan(patchCtx('release/datadog_dio/v2.0.x')),
        throwsStateError,
      );
    });

    test('fails loudly on a breaking change too', () async {
      await fixture.tag('datadog_dio/v2.0.0');
      fixture.writeFile('packages/datadog_dio/CHANGES', 'oops');
      await fixture.commit('fix!: this breaks things');

      await expectLater(
        plan(patchCtx('release/datadog_dio/v2.0.x')),
        throwsStateError,
      );
    });

    test(
      'ignores a newer tag from a line mainline has already moved past',
      () async {
        await fixture.tag('datadog_dio/v2.0.0');
        // Mainline has since released a new major -- not an ancestor of
        // the 2.0.x patch branch, and must not be picked up as "the last
        // release" for it. (Tagged directly, rather than via a feat!/major
        // commit, so this test isolates tag selection from the separate
        // "no major/minor commits on a patch branch" check.)
        fixture.writeFile('packages/datadog_dio/CHANGES', 'v3.0.0 work');
        await fixture.commit('fix: something for 3.0.0');
        await fixture.tag('datadog_dio/v3.0.0');

        fixture.writeFile('packages/datadog_dio/CHANGES', 'a cherry-pick');
        await fixture.commit('fix: a cherry-picked fix');

        final result = await plan(patchCtx('release/datadog_dio/v2.0.x'));

        expect(result.packages.single.newVersion, '2.0.1');
      },
    );
  });

  group('pre-release branch', () {
    RunContext preReleaseCtx({String? prereleaseLabel}) => RunContext(
      repoRoot: fixture.root.path,
      trigger: TriggerContext.preRelease,
      currentBranch: 'v4',
      requestedPackages: ['datadog_flutter_plugin'],
      prereleaseLabel: prereleaseLabel,
    );

    test('the first prerelease for a base version requires a label', () async {
      await expectLater(plan(preReleaseCtx()), throwsStateError);
    });

    test('starts a new label at .1', () async {
      final result = await plan(preReleaseCtx(prereleaseLabel: 'beta'));
      expect(result.packages.single.newVersion, '4.0.0-beta.1');
      expect(result.packages.single.bumpLevel, VersionBumpType.prerelease);
    });

    test('increments the counter for an already-used label', () async {
      await fixture.tag('datadog_flutter_plugin/v4.0.0-beta.1');

      final result = await plan(preReleaseCtx(prereleaseLabel: 'beta'));

      expect(result.packages.single.newVersion, '4.0.0-beta.2');
    });

    test(
      'omitting the label continues whatever label is already tagged',
      () async {
        await fixture.tag('datadog_flutter_plugin/v4.0.0-beta.1');

        final result = await plan(preReleaseCtx());

        expect(result.packages.single.newVersion, '4.0.0-beta.2');
      },
    );

    test('switching to a new label restarts the counter at .1', () async {
      await fixture.tag('datadog_flutter_plugin/v4.0.0-beta.3');

      final result = await plan(preReleaseCtx(prereleaseLabel: 'rc'));

      expect(result.packages.single.newVersion, '4.0.0-rc.1');
    });

    test('bases a new prerelease line on the declared target version, not a '
        'stale prior stable tag', () async {
      // pubspec.version is already 4.0.0 (a new major, not yet released),
      // but the last real tag is the old 3.x stable line.
      await fixture.tag('datadog_flutter_plugin/v3.2.0');

      final result = await plan(preReleaseCtx(prereleaseLabel: 'beta'));

      expect(result.packages.single.newVersion, '4.0.0-beta.1');
    });

    test('rejects starting a new pre-release once the target version has '
        'already been released stably', () async {
      // pubspec.version is 4.0.0, and it's already been released stably
      // as such -- a new "4.0.0-beta.1" would sort below that release.
      await fixture.tag('datadog_flutter_plugin/v4.0.0');

      await expectLater(
        plan(preReleaseCtx(prereleaseLabel: 'beta')),
        throwsStateError,
      );
    });
  });

  test('patch branch ignores an inherited requestedPackages filter', () async {
    final plan = await computeReleasePlan(
      RunContext(
        repoRoot: fixture.root.path,
        trigger: TriggerContext.patch,
        currentBranch: 'release/datadog_dio/v1.1.x',
        // Simulates a stale/inherited PACKAGES env var that doesn't name
        // this branch's package -- it must not empty out the plan.
        requestedPackages: ['some_other_package'],
      ),
    );

    expect(plan.packages, hasLength(1));
    expect(plan.packages.single.package.name, 'datadog_dio');
  });
}
