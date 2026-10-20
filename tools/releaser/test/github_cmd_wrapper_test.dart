// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:releaser/github_cmd_wrapper.dart';
import 'package:test/test.dart';

void main() {
  group('commitStatusStateIsSuccess', () {
    test('true when the context is success', () {
      final response = {
        'statuses': [
          {'context': 'dd-gitlab/notify-pipeline-succeeded', 'state': 'success'},
        ],
      };

      expect(
        commitStatusStateIsSuccess(
          response,
          'dd-gitlab/notify-pipeline-succeeded',
        ),
        isTrue,
      );
    });

    test('false when the context is pending', () {
      final response = {
        'statuses': [
          {'context': 'dd-gitlab/notify-pipeline-succeeded', 'state': 'pending'},
        ],
      };

      expect(
        commitStatusStateIsSuccess(
          response,
          'dd-gitlab/notify-pipeline-succeeded',
        ),
        isFalse,
      );
    });

    test('false when the context is not present at all', () {
      final response = {
        'statuses': [
          {'context': 'some/other-check', 'state': 'success'},
        ],
      };

      expect(
        commitStatusStateIsSuccess(
          response,
          'dd-gitlab/notify-pipeline-succeeded',
        ),
        isFalse,
      );
    });

    test('false against an empty statuses list', () {
      expect(commitStatusStateIsSuccess({'statuses': []}, 'any-context'), isFalse);
    });

    test(
      'uses the newest entry when the same context appears more than once',
      () {
        // The API returns entries newest-first; an older "pending" for the
        // same context (e.g. a retried GitLab job) must not shadow a newer
        // "success".
        final response = {
          'statuses': [
            {'context': 'dd-gitlab/notify-pipeline-succeeded', 'state': 'success'},
            {'context': 'dd-gitlab/notify-pipeline-succeeded', 'state': 'pending'},
          ],
        };

        expect(
          commitStatusStateIsSuccess(
            response,
            'dd-gitlab/notify-pipeline-succeeded',
          ),
          isTrue,
        );
      },
    );
  });

  group('selectLatestWorkflowRun', () {
    test('returns null when nothing matches the tag ref', () {
      expect(selectLatestWorkflowRun([], 'datadog_dio/v2.3.0'), isNull);
    });

    test('picks the run matching the tag ref', () {
      final runs = [
        {
          'headBranch': 'datadog_dio/v2.3.0',
          'status': 'completed',
          'conclusion': 'success',
          'createdAt': '2026-01-01T00:00:00Z',
          'url': 'https://example.com/run/1',
        },
        {
          'headBranch': 'datadog_flags/v1.0.0',
          'status': 'completed',
          'conclusion': 'success',
          'createdAt': '2026-01-01T00:00:01Z',
          'url': 'https://example.com/run/2',
        },
      ];

      final run = selectLatestWorkflowRun(runs, 'datadog_dio/v2.3.0');
      expect(run, isNotNull);
      expect(run!.url, 'https://example.com/run/1');
      expect(run.succeeded, isTrue);
    });

    test('picks the newest match when there is more than one', () {
      final runs = [
        {
          'headBranch': 'datadog_dio/v2.3.0',
          'status': 'completed',
          'conclusion': 'failure',
          'createdAt': '2026-01-01T00:00:00Z',
          'url': 'https://example.com/run/old',
        },
        {
          'headBranch': 'datadog_dio/v2.3.0',
          'status': 'in_progress',
          'conclusion': null,
          'createdAt': '2026-01-02T00:00:00Z',
          'url': 'https://example.com/run/new',
        },
      ];

      final run = selectLatestWorkflowRun(runs, 'datadog_dio/v2.3.0');
      expect(run!.url, 'https://example.com/run/new');
      expect(run.isComplete, isFalse);
    });
  });
}
