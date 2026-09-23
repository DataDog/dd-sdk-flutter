// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:releaser/llm/prompts/grouped_prs_prompt.dart';
import 'package:releaser/package_discovery.dart';
import 'package:releaser/release_plan.dart';
import 'package:releaser/release_pr.dart';
import 'package:test/test.dart';

PackagePlan _plan(
  String name, {
  String relativePath = '',
  String currentVersion = '1.0.0',
  String newVersion = '1.1.0',
  VersionBumpType? bumpLevel = VersionBumpType.minor,
}) => PackagePlan(
  package: DiscoveredPackage(
    name: name,
    version: currentVersion,
    relativePath: relativePath.isEmpty ? 'packages/$name' : relativePath,
    role: PackageRole.appFacing,
    groupKey: name,
  ),
  currentVersion: currentVersion,
  newVersion: newVersion,
  bumpLevel: bumpLevel,
);

void main() {
  group('prTitle', () {
    test('uses a real conventional-commit type for a single package', () {
      expect(
        prTitle([_plan('datadog_dio', newVersion: '2.1.0')]),
        'chore(release): datadog_dio 2.1.0',
      );
    });

    test('summarizes a multi-package run', () {
      expect(
        prTitle([_plan('datadog_dio'), _plan('datadog_gql_link')]),
        'chore(release): 2 packages',
      );
    });
  });

  group('versionSummary', () {
    test('lists each package with its bump level', () {
      final summary = versionSummary([
        _plan(
          'datadog_dio',
          currentVersion: '2.0.0',
          newVersion: '2.1.0',
          bumpLevel: VersionBumpType.minor,
        ),
      ]);

      expect(summary, '- datadog_dio: 2.0.0 -> 2.1.0 (minor)');
    });

    test('calls out a first release with no bump level', () {
      final summary = versionSummary([
        _plan(
          'datadog_dio',
          currentVersion: '1.0.0',
          newVersion: '1.0.0',
          bumpLevel: null,
        ),
      ]);

      expect(summary, contains('(first release)'));
    });
  });

  group('prBody', () {
    test('adds a heading and PR-group summary per package, linking its '
        'CHANGELOG.md on the release branch', () {
      final body = prBody(
        [_plan('datadog_grpc_interceptor', newVersion: '2.1.0')],
        const [],
        publishValidationSkipped: false,
        repoSlug: 'DataDog/dd-sdk-flutter',
        changelogBranch: 'release-prep/20260921-4210b',
        groupsByPackage: {
          'datadog_grpc_interceptor': [
            const PrGroup(
              label: 'Dependency version constraint updates',
              prs: [GroupedPr(number: 1150, title: 'feat: Support grpc 5.x.')],
            ),
          ],
        },
      );

      expect(body, contains('## `datadog_grpc_interceptor` 1.0.0 → 2.1.0'));
      expect(
        body,
        contains(
          'https://github.com/DataDog/dd-sdk-flutter/blob/'
          'release-prep/20260921-4210b/packages/datadog_grpc_interceptor/'
          'CHANGELOG.md',
        ),
      );
      expect(body, contains('#### Dependency version constraint updates'));
      expect(body, contains('- #1150'));
    });

    test('renders a package heading with no group summary underneath it '
        'when nothing is known (e.g. a native-SDK-only release)', () {
      final body = prBody(
        [_plan('datadog_dio')],
        const [],
        publishValidationSkipped: false,
        repoSlug: 'DataDog/dd-sdk-flutter',
        changelogBranch: 'release-prep/20260921-4210b',
        groupsByPackage: const {},
      );

      expect(body, contains('## `datadog_dio`'));
      expect(body, isNot(contains('####')));
    });

    test('still renders the versions table and publish-validation line', () {
      final body = prBody(
        [_plan('datadog_dio', currentVersion: '2.0.0', newVersion: '2.1.0')],
        const [],
        publishValidationSkipped: true,
        repoSlug: 'DataDog/dd-sdk-flutter',
        changelogBranch: 'release-prep/20260921-4210b',
        groupsByPackage: const {},
      );

      expect(body, contains('| datadog_dio | 2.0.0 | 2.1.0 | minor |'));
      expect(body, contains('--skip-publish-validation'));
    });
  });
}
