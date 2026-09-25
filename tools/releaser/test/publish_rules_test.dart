// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:releaser/publish_rules.dart';
import 'package:test/test.dart';

void main() {
  group('isPatchReleaseBranch', () {
    test('recognizes a standing patch branch', () {
      expect(isPatchReleaseBranch('release/datadog_dio/v2.2.x'), isTrue);
    });

    test('rejects develop', () {
      expect(isPatchReleaseBranch('develop'), isFalse);
    });

    test('rejects a pre-release branch', () {
      expect(isPatchReleaseBranch('v4'), isFalse);
    });

    test('rejects a release-prep branch', () {
      expect(isPatchReleaseBranch('release-prep/20260101-abc123'), isFalse);
    });
  });

  group('shouldMarkReleaseLatest', () {
    test('true for the main package on a mainline release', () {
      expect(
        shouldMarkReleaseLatest(
          package: 'datadog_flutter_plugin',
          prerelease: false,
          isPatch: false,
        ),
        isTrue,
      );
    });

    test('false for any other package', () {
      expect(
        shouldMarkReleaseLatest(
          package: 'datadog_dio',
          prerelease: false,
          isPatch: false,
        ),
        isFalse,
      );
    });

    test('false for the main package on a pre-release', () {
      expect(
        shouldMarkReleaseLatest(
          package: 'datadog_flutter_plugin',
          prerelease: true,
          isPatch: false,
        ),
        isFalse,
      );
    });

    test('false for the main package on a patch release', () {
      expect(
        shouldMarkReleaseLatest(
          package: 'datadog_flutter_plugin',
          prerelease: false,
          isPatch: true,
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

    test('a patch branch merges into itself', () {
      expect(
        expectedIntegrationBranch('release/datadog_dio/v2.2.x'),
        'release/datadog_dio/v2.2.x',
      );
    });

    test('an unrecognized branch returns null', () {
      expect(expectedIntegrationBranch('some-fork-main'), isNull);
      expect(expectedIntegrationBranch('main'), isNull);
    });
  });
}
