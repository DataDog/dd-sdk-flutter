// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:ci_helpers/integration_test_runner.dart';
import 'package:test/test.dart';

void main() {
  const loadingStart =
      '{"type":"testStart","test":{"id":1,"name":"loading /a_test.dart"}}';
  const realStart = '{"type":"testStart","test":{"id":2,"name":"my test"}}';

  group('started', () {
    final cases = {
      'is false after only a loading test': [loadingStart],
      'is false for non-JSON lines': ['Launching lib/main.dart'],
      'is true after a real test starts': [loadingStart, realStart],
    };
    for (final MapEntry(key: name, value: lines) in cases.entries) {
      test(name, () {
        final tracker = TestEventTracker();
        lines.forEach(tracker.handleLine);
        expect(tracker.started, name.contains('is true'));
      });
    }
  });

  group('failures', () {
    final cases = {
      'error event':
          '{"type":"error","testID":2,"error":"boom","stackTrace":"trace"}',
      'failed testDone':
          '{"type":"testDone","testID":2,"result":"failure","hidden":false}',
      'errored testDone':
          '{"type":"testDone","testID":2,"result":"error","hidden":false}',
    };
    for (final MapEntry(key: name, value: line) in cases.entries) {
      test('records $name with the test name', () {
        final tracker = TestEventTracker()..handleLine(realStart);
        final message = tracker.handleLine(line);
        expect(message, contains('my test'));
        expect(tracker.failures, hasLength(1));
      });
    }

    final ignored = {
      'successful testDone':
          '{"type":"testDone","testID":2,"result":"success","hidden":false}',
      'hidden testDone':
          '{"type":"testDone","testID":1,"result":"success","hidden":true}',
      'JSON array header': '[{"protocolVersion":"0.1.1"}]',
    };
    for (final MapEntry(key: name, value: line) in ignored.entries) {
      test('ignores $name', () {
        final tracker = TestEventTracker()..handleLine(realStart);
        expect(tracker.handleLine(line), isNull);
        expect(tracker.failures, isEmpty);
      });
    }
  });

  group('AttemptOutcome.isRetryable', () {
    for (final outcome in AttemptOutcome.values) {
      test(outcome.name, () {
        expect(
          outcome.isRetryable,
          {
            AttemptOutcome.launchFailure,
            AttemptOutcome.startupTimeout,
          }.contains(outcome),
        );
      });
    }
  });
}
