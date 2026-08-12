// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:test/test.dart';

import 'package:releaser/release_plan.dart';
import 'support/fixture_repo.dart';

void main() {
  late FixtureRepo fixture;

  setUp(() async {
    fixture = await FixtureRepo.create();
  });

  tearDown(() => fixture.delete());

  test(
    'mainline with no requestedPackages returns every discovered package',
    () async {
      final plan = await computeReleasePlan(
        RunContext(
          repoRoot: fixture.root.path,
          trigger: TriggerContext.mainline,
          currentBranch: 'develop',
        ),
      );

      final names = plan.packages.map((p) => p.package.name);
      expect(
        names,
        containsAll([
          'datadog_dio',
          'datadog_flutter_plugin',
          'datadog_flutter_plugin_ios',
          'lonely_ios',
        ]),
      );
      expect(names, isNot(contains('datadog_common_test')));
    },
  );

  test('mainline with requestedPackages filters to just those', () async {
    final plan = await computeReleasePlan(
      RunContext(
        repoRoot: fixture.root.path,
        trigger: TriggerContext.mainline,
        currentBranch: 'develop',
        requestedPackages: ['datadog_dio', 'datadog_flutter_plugin_ios'],
      ),
    );

    expect(
      plan.packages.map((p) => p.package.name),
      unorderedEquals(['datadog_dio', 'datadog_flutter_plugin_ios']),
    );
  });

  test(
    'patch branch resolves the single named package with no grouping',
    () async {
      final plan = await computeReleasePlan(
        RunContext(
          repoRoot: fixture.root.path,
          trigger: TriggerContext.patch,
          currentBranch: 'release/datadog_dio/v1.1.x',
        ),
      );

      expect(plan.packages, hasLength(1));
      expect(plan.packages.single.package.name, 'datadog_dio');
    },
  );

  test(
    'patch branch on a federated member still selects only that one package',
    () async {
      final plan = await computeReleasePlan(
        RunContext(
          repoRoot: fixture.root.path,
          trigger: TriggerContext.patch,
          currentBranch: 'release/datadog_flutter_plugin_ios/v1.0.x',
        ),
      );

      expect(plan.packages, hasLength(1));
      expect(plan.packages.single.package.name, 'datadog_flutter_plugin_ios');
    },
  );

  test('patch branch with a malformed name throws', () async {
    await expectLater(
      computeReleasePlan(
        RunContext(
          repoRoot: fixture.root.path,
          trigger: TriggerContext.patch,
          currentBranch: 'not-a-patch-branch',
        ),
      ),
      throwsStateError,
    );
  });

  test('patch branch naming an unknown package throws', () async {
    await expectLater(
      computeReleasePlan(
        RunContext(
          repoRoot: fixture.root.path,
          trigger: TriggerContext.patch,
          currentBranch: 'release/does_not_exist/v1.0.x',
        ),
      ),
      throwsStateError,
    );
  });
}
