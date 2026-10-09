// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:releaser/publish_rules.dart';
import 'package:test/test.dart';

void main() {
  group('isSupportBranch', () {
    test('recognizes a standing patch-line support branch', () {
      expect(isSupportBranch('release/datadog_dio/v2.2.x'), isTrue);
    });

    test('rejects develop', () {
      expect(isSupportBranch('develop'), isFalse);
    });

    test('rejects a pre-release branch', () {
      expect(isSupportBranch('v4'), isFalse);
    });

    test('rejects a release-prep branch', () {
      expect(isSupportBranch('release-prep/20260101-abc123'), isFalse);
    });

    test('recognizes a major-line support branch', () {
      expect(isSupportBranch('release/datadog_dio/v3.x'), isTrue);
    });

    test('rejects a branch with no extractable package name', () {
      expect(isSupportBranch('release/a/b/v1.2.x'), isFalse);
    });
  });

  group('shouldMarkReleaseLatest', () {
    test('true for the main package on a mainline release', () {
      expect(
        shouldMarkReleaseLatest(
          package: 'datadog_flutter_plugin',
          prerelease: false,
          isSupport: false,
        ),
        isTrue,
      );
    });

    test('false for any other package', () {
      expect(
        shouldMarkReleaseLatest(
          package: 'datadog_dio',
          prerelease: false,
          isSupport: false,
        ),
        isFalse,
      );
    });

    test('false for the main package on a pre-release', () {
      expect(
        shouldMarkReleaseLatest(
          package: 'datadog_flutter_plugin',
          prerelease: true,
          isSupport: false,
        ),
        isFalse,
      );
    });

    test('false for the main package on a patch release', () {
      expect(
        shouldMarkReleaseLatest(
          package: 'datadog_flutter_plugin',
          prerelease: false,
          isSupport: true,
        ),
        isFalse,
      );
    });
  });

  group('expectedIntegrationBranch', () {
    test('mainline (develop) merges into main', () {
      expect(expectedIntegrationBranch('develop'), 'main');
    });

    test('the v4 pre-release merges into v4-main', () {
      expect(expectedIntegrationBranch('v4'), 'v4-main');
    });

    test('a pre-release branch outside the whitelist is not recognized', () {
      expect(expectedIntegrationBranch('v5'), isNull);
    });

    test('a patch-line support branch merges into itself', () {
      expect(
        expectedIntegrationBranch('release/datadog_dio/v2.2.x'),
        'release/datadog_dio/v2.2.x',
      );
    });

    test('a major-line support branch merges into itself', () {
      expect(
        expectedIntegrationBranch('release/datadog_dio/v3.x'),
        'release/datadog_dio/v3.x',
      );
    });

    test('an unrecognized branch returns null', () {
      expect(expectedIntegrationBranch('some-fork-main'), isNull);
      expect(expectedIntegrationBranch('main'), isNull);
    });
  });

  group('sourceBranchFor', () {
    test('main implies develop', () {
      expect(sourceBranchFor('main'), 'develop');
    });

    test('v4-main implies v4', () {
      expect(sourceBranchFor('v4-main'), 'v4');
    });

    test('a -main branch outside the whitelist throws', () {
      expect(() => sourceBranchFor('v5-main'), throwsStateError);
    });

    test('a patch-line support branch implies itself', () {
      expect(
        sourceBranchFor('release/datadog_dio/v2.2.x'),
        'release/datadog_dio/v2.2.x',
      );
    });

    test('a major-line support branch implies itself', () {
      expect(
        sourceBranchFor('release/datadog_dio/v3.x'),
        'release/datadog_dio/v3.x',
      );
    });

    test('is the exact inverse of expectedIntegrationBranch for every '
        'recognized branch', () {
      for (final sourceBranch in [
        'develop',
        'v4',
        'release/datadog_dio/v2.2.x',
        'release/datadog_dio/v3.x',
      ]) {
        final integrationBranch = expectedIntegrationBranch(sourceBranch)!;
        expect(sourceBranchFor(integrationBranch), sourceBranch);
      }
    });

    test('throws for an unrecognized branch', () {
      expect(() => sourceBranchFor('some-fork-main'), throwsStateError);
      expect(() => sourceBranchFor('develop'), throwsStateError);
    });
  });

  group('expectedSupportBranchFor', () {
    test('a patch bump stays on its exact minor line', () {
      expect(
        expectedSupportBranchFor(
          package: 'datadog_dio',
          toVersion: '2.2.1',
          bump: 'patch',
        ),
        'release/datadog_dio/v2.2.x',
      );
    });

    test('a minor bump comes from the major-line branch', () {
      expect(
        expectedSupportBranchFor(
          package: 'datadog_dio',
          toVersion: '3.5.0',
          bump: 'minor',
        ),
        'release/datadog_dio/v3.x',
      );
    });

    test('throws for a bump a support branch never produces', () {
      for (final bump in ['major', 'prerelease', 'first release']) {
        expect(
          () => expectedSupportBranchFor(
            package: 'datadog_dio',
            toVersion: '3.0.0',
            bump: bump,
          ),
          throwsStateError,
        );
      }
    });
  });
}
