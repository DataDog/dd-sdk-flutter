// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:test/test.dart';

import 'package:releaser/git_history.dart';
import 'support/fixture_repo.dart';

void main() {
  late FixtureRepo fixture;

  setUp(() async {
    fixture = await FixtureRepo.create();
  });

  tearDown(() => fixture.delete());

  test('finds the highest-versioned tag for a package', () async {
    fixture.writeFile('packages/datadog_dio/CHANGES', 'v2.2.0 work');
    await fixture.commit('fix: something for 2.2.0');
    await fixture.tag('datadog_dio/v2.2.0');

    fixture.writeFile('packages/datadog_dio/CHANGES', 'v2.3.0 work');
    await fixture.commit('feat: something for 2.3.0');
    await fixture.tag('datadog_dio/v2.3.0');

    final gitDir = await fixture.gitDir;
    final tag = await findLastReleaseTag(gitDir, 'datadog_dio');

    expect(tag, isNotNull);
    expect(tag!.tag, 'datadog_dio/v2.3.0');
  });

  test('returns null when a package has never been tagged', () async {
    final gitDir = await fixture.gitDir;
    final tag = await findLastReleaseTag(gitDir, 'datadog_flags');
    expect(tag, isNull);
  });

  test(
    'commitMessagesSince only returns commits after the given sha',
    () async {
      fixture.writeFile('packages/datadog_dio/CHANGES', 'released');
      await fixture.commit('fix: shipped in 2.3.0');
      await fixture.tag('datadog_dio/v2.3.0');
      final tagSha = (await findLastReleaseTag(
        await fixture.gitDir,
        'datadog_dio',
      ))!.objectSha;

      fixture.writeFile('packages/datadog_dio/CHANGES', 'unreleased');
      await fixture.commit('feat: not yet released');

      final commits = await commitMessagesSince(
        await fixture.gitDir,
        pathspec: 'packages/datadog_dio',
        sinceSha: tagSha,
      );

      expect(commits, hasLength(1));
      expect(commits.single, contains('feat: not yet released'));
    },
  );

  test(
    'commitMessagesSince walks full history when sinceSha is null',
    () async {
      fixture.writeFile('packages/datadog_flags/CHANGES', 'a');
      await fixture.commit('feat: first ever commit for datadog_flags');
      fixture.writeFile('packages/datadog_flags/CHANGES', 'b');
      await fixture.commit('fix: second commit for datadog_flags');

      final commits = await commitMessagesSince(
        await fixture.gitDir,
        pathspec: 'packages/datadog_flags',
        sinceSha: null,
      );

      expect(commits, hasLength(2));
    },
  );

  test(
    'commitMessagesSince excludes commits touching other packages',
    () async {
      // datadog_flags doesn't exist in the fixture layout, so unlike
      // datadog_dio (touched by the fixture's own initial commit) its
      // history starts clean here.
      fixture.writeFile('packages/datadog_flags/CHANGES', 'flags change 1');
      await fixture.commit('feat: change to flags only');
      fixture.writeFile('packages/datadog_dio/CHANGES', 'dio change');
      await fixture.commit('feat: change to dio only');
      fixture.writeFile('packages/datadog_flags/CHANGES', 'flags change 2');
      await fixture.commit('fix: another change to flags only');

      final commits = await commitMessagesSince(
        await fixture.gitDir,
        pathspec: 'packages/datadog_flags',
        sinceSha: null,
      );

      expect(commits, hasLength(2));
      expect(commits.every((c) => !c.contains('dio only')), isTrue);
    },
  );
}
