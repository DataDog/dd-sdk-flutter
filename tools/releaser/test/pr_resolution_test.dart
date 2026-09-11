// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:releaser/pr_resolution.dart';
import 'package:test/test.dart';

Future<ResolvedPr?> _neverCalled(String sha) =>
    throw StateError('searchBySha should not have been called: $sha');

void main() {
  group('resolvePr', () {
    test(
      'parses a squash-merge (#N) suffix without calling searchBySha',
      () async {
        final resolved = await resolvePr(
          'deadbeef',
          'add frustration signal tracking (#482)',
          _neverCalled,
        );

        expect(resolved?.number, 482);
        expect(resolved?.title, 'add frustration signal tracking');
      },
    );

    test('falls back to searchBySha when there is no suffix', () async {
      final resolved = await resolvePr(
        'deadbeef',
        'add frustration signal tracking',
        (sha) async {
          expect(sha, 'deadbeef');
          return const ResolvedPr(number: 17, title: 'From search');
        },
      );

      expect(resolved?.number, 17);
      expect(resolved?.title, 'From search');
    });

    test('returns null when searchBySha finds nothing', () async {
      final resolved = await resolvePr(
        'deadbeef',
        'add frustration signal tracking',
        (sha) async => null,
      );

      expect(resolved, isNull);
    });
  });

  group('stripSquashSuffix', () {
    test('strips a trailing (#N)', () {
      expect(
        stripSquashSuffix('add frustration signal tracking (#482)'),
        'add frustration signal tracking',
      );
    });

    test('is a no-op when there is no suffix', () {
      expect(
        stripSquashSuffix('add frustration signal tracking'),
        'add frustration signal tracking',
      );
    });
  });
}
