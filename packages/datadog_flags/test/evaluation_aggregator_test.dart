// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/assignment.dart';
import 'package:datadog_flags/src/evaluation_aggregator.dart';
import 'package:datadog_flags/src/flags_runtime.dart';
import 'package:datadog_flags/src/intake_platform.dart';
import 'package:datadog_flags/src/sdk_metadata.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test(
    'batch and periodic triggers preserve increasing backoff across handoff',
    () async {
      EvaluationAggregator.maxBatchSize = 1;
      final requests = <http.Request>[];
      final clock = Stopwatch()..start();
      final times = <int>[];
      final client = MockClient((request) async {
        requests.add(request);
        times.add(clock.elapsedMilliseconds);
        return http.Response('{}', times.length < 3 ? 503 : 202);
      });
      final first = _aggregator(
        requests: requests,
        httpClient: client,
        flushInterval: const Duration(milliseconds: 20),
      );
      final second = _aggregator(
        requests: requests,
        httpClient: client,
        flushInterval: const Duration(milliseconds: 20),
      );
      addTearDown(first.shutdown);
      addTearDown(second.shutdown);
      void record(EvaluationAggregator target, String key) =>
          target.recordEvaluation(
            flagKey: key,
            assignment: _assignment(),
            evaluationContext: const FlagsEvaluationContext(targetingKey: 'A'),
            error: null,
          );
      record(first, 'first');
      await _waitUntil(() => times.length == 1);
      second.inheritPendingEvaluations(first);
      for (var i = 0; i < 10; i++) {
        record(second, 'next-$i');
        await second.flush();
      }
      expect(times, hasLength(1));
      await _waitUntil(() => times.length == 2);
      for (var i = 0; i < 10; i++) {
        record(second, 'later-$i');
        await second.flush();
      }
      expect(times, hasLength(2));
      await _waitUntil(() => times.length == 3);
      expect(times[1] - times[0], greaterThanOrEqualTo(390));
      expect(times[2] - times[1], greaterThanOrEqualTo(790));
      record(second, 'after-success');
      await _waitUntil(() => times.length == 4);
      expect(times[3] - times[2], lessThan(400));
    },
  );

  tearDown(() {
    EvaluationAggregator.maxBatchSize =
        EvaluationAggregator.defaultMaxBatchSize;
    EvaluationAggregator.uploadTimeout =
        EvaluationAggregator.defaultUploadTimeout;
  });

  test('periodic flush repeats and stops retrying after shutdown', () async {
    final requests = <http.Request>[];
    final aggregator = _aggregator(
      requests: requests,
      flushInterval: const Duration(milliseconds: 20),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('{}', requests.length < 3 ? 202 : 503);
      }),
    );
    addTearDown(aggregator.shutdown);

    for (var i = 1; i <= 3; i++) {
      aggregator.recordEvaluation(
        flagKey: 'flag-$i',
        assignment: _assignment(),
        evaluationContext: const FlagsEvaluationContext(targetingKey: 'A'),
        error: null,
      );
      await _waitUntil(() => requests.length == i);
    }
    await aggregator.shutdown();
    final countAfterDrain = requests.length;
    // Failed batches remain pending, so another timer would attempt an upload.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(requests, hasLength(countAfterDrain));
  });

  test('aggregates matching flag evaluations into one intake event', () async {
    final requests = <http.Request>[];
    final dates = [
      DateTime.fromMillisecondsSinceEpoch(1000),
      DateTime.fromMillisecondsSinceEpoch(2000),
    ];
    final aggregator = _aggregator(
      requests: requests,
      dateProvider: () => dates.removeAt(0),
    );
    addTearDown(aggregator.shutdown);

    aggregator.recordEvaluation(
      flagKey: 'checkout.enabled',
      assignment: _assignment(),
      evaluationContext: const FlagsEvaluationContext(
        targetingKey: 'user-123',
        attributes: {'companyId': '1', 'plan': 'pro'},
      ),
      error: null,
    );
    aggregator.recordEvaluation(
      flagKey: 'checkout.enabled',
      assignment: _assignment(),
      evaluationContext: const FlagsEvaluationContext(
        targetingKey: 'user-123',
        attributes: {'plan': 'pro', 'companyId': '1'},
      ),
      error: null,
    );

    await aggregator.flush();

    final request = _evaluationRequests(requests).single;
    _expectIntakeMetadata(request, nativeContentType: 'application/json');

    final evaluation = _flagEvaluations(request).single;
    expect(evaluation['flag'], {'key': 'checkout.enabled'});
    expect(evaluation['variant'], {'key': 'enabled'});
    expect(evaluation['allocation'], {'key': 'allocation-a'});
    expect(evaluation['targeting_key'], 'user-123');
    expect(evaluation['first_evaluation'], 1000);
    expect(evaluation['last_evaluation'], 2000);
    expect(evaluation['evaluation_count'], 2);
    expect(evaluation['context'], {
      'evaluation': {'companyId': '1', 'plan': 'pro'},
      if (isWebFlagsIntake)
        'dd': {
          'service': 'shopping-cart',
          'rum': {
            'application': {'id': 'application-id'},
          },
        },
    });
    if (!isWebFlagsIntake) {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      expect(body['context'], {
        'env': 'staging',
        'service': 'shopping-cart',
        'version': '1.2.3',
        'rum': {
          'application': {'id': 'application-id'},
        },
      });
    }
    expect(evaluation.containsKey('runtime_default_used'), isFalse);
  });

  test('keeps runtime-default and error evaluations separate', () async {
    final requests = <http.Request>[];
    final aggregator = _aggregator(requests: requests);
    addTearDown(aggregator.shutdown);

    aggregator.recordEvaluation(
      flagKey: 'checkout.enabled',
      assignment: _assignment(reason: 'DEFAULT'),
      evaluationContext: const FlagsEvaluationContext(targetingKey: 'user-123'),
      error: null,
    );
    aggregator.recordEvaluation(
      flagKey: 'checkout.enabled',
      assignment: _assignment(),
      evaluationContext: const FlagsEvaluationContext(targetingKey: 'user-123'),
      error: FlagEvaluationError.typeMismatch.code,
    );

    await aggregator.flush();

    final evaluations = _flagEvaluations(_evaluationRequests(requests).single);
    expect(evaluations, hasLength(2));
    expect(
      evaluations.map((evaluation) => evaluation['runtime_default_used']),
      everyElement(isTrue),
    );
    expect(
      evaluations.map((evaluation) => evaluation['error']),
      contains(equals({'message': FlagEvaluationError.typeMismatch.code})),
    );
  });

  test(
    'restores failed uploads and merges matching later evaluations',
    () async {
      final requests = <http.Request>[];
      var attempt = 0;
      final aggregator = _aggregator(
        requests: requests,
        httpClient: MockClient((request) async {
          requests.add(request);
          attempt += 1;
          return http.Response('{"ok":true}', attempt == 1 ? 500 : 200);
        }),
      );
      addTearDown(aggregator.shutdown);

      aggregator.recordEvaluation(
        flagKey: 'checkout.enabled',
        assignment: _assignment(),
        evaluationContext: const FlagsEvaluationContext(
          targetingKey: 'user-123',
        ),
        error: null,
      );
      await aggregator.flush();

      aggregator.recordEvaluation(
        flagKey: 'checkout.enabled',
        assignment: _assignment(),
        evaluationContext: const FlagsEvaluationContext(
          targetingKey: 'user-123',
        ),
        error: null,
      );
      await aggregator.flush();

      expect(_evaluationRequests(requests), hasLength(1));
      await Future<void>.delayed(const Duration(milliseconds: 650));
      expect(_evaluationRequests(requests), hasLength(2));
      final resentEvaluation = _flagEvaluations(
        _evaluationRequests(requests).last,
      ).single;
      expect(resentEvaluation['evaluation_count'], 2);
    },
  );

  test('drops non-retryable client error uploads', () async {
    final requests = <http.Request>[];
    final aggregator = _aggregator(
      requests: requests,
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('{"error":"invalid token"}', 403);
      }),
    );
    addTearDown(aggregator.shutdown);

    aggregator.recordEvaluation(
      flagKey: 'checkout.enabled',
      assignment: _assignment(),
      evaluationContext: const FlagsEvaluationContext(targetingKey: 'user-123'),
      error: null,
    );
    await aggregator.flush();
    await aggregator.flush();

    expect(_evaluationRequests(requests), hasLength(1));
  });

  test('auto-flushes when the internal max batch size is reached', () async {
    EvaluationAggregator.maxBatchSize = 1;

    final requests = <http.Request>[];
    final aggregator = _aggregator(requests: requests);
    addTearDown(aggregator.shutdown);

    aggregator.recordEvaluation(
      flagKey: 'checkout.enabled',
      assignment: _assignment(),
      evaluationContext: const FlagsEvaluationContext(targetingKey: 'user-123'),
      error: null,
    );

    await _waitUntil(() => _evaluationRequests(requests).length == 1);
  });

  test('does not send evaluations when tracking is disabled', () async {
    final requests = <http.Request>[];
    final aggregator = _aggregator(requests: requests, trackEvaluations: false);
    addTearDown(aggregator.shutdown);

    aggregator.recordEvaluation(
      flagKey: 'checkout.enabled',
      assignment: _assignment(),
      evaluationContext: const FlagsEvaluationContext(targetingKey: 'user-123'),
      error: null,
    );
    await aggregator.flush();

    expect(_evaluationRequests(requests), isEmpty);
  });

  test('bounds shutdown when an upload does not complete', () async {
    EvaluationAggregator.uploadTimeout = const Duration(milliseconds: 1);

    final requests = <http.Request>[];
    final response = Completer<http.Response>();
    final aggregator = _aggregator(
      requests: requests,
      httpClient: MockClient((request) async {
        requests.add(request);
        return response.future;
      }),
    );

    aggregator.recordEvaluation(
      flagKey: 'checkout.enabled',
      assignment: _assignment(),
      evaluationContext: const FlagsEvaluationContext(targetingKey: 'user-123'),
      error: null,
    );

    await expectLater(
      aggregator.shutdown().timeout(const Duration(seconds: 1)),
      completes,
    );

    expect(response.isCompleted, isFalse);
    expect(_evaluationRequests(requests), hasLength(1));
  });
}

EvaluationAggregator _aggregator({
  required List<http.Request> requests,
  http.Client? httpClient,
  bool trackEvaluations = true,
  Duration flushInterval = const Duration(hours: 1),
  DateTime Function()? dateProvider,
}) {
  final client = httpClient ?? _successClient(requests);
  return EvaluationAggregator(
    FlagsRuntime(
      configuration: DatadogFlagsConfiguration(
        datadogConfig: _datadogConfig(),
        trackEvaluations: trackEvaluations,
        evaluationFlushInterval: flushInterval,
        httpClient: client,
        dateProvider: dateProvider ?? DateTime.now,
      ),
      datadogConfig: _datadogConfig(),
      httpClient: client,
    ),
  );
}

http.Client _successClient(List<http.Request> requests) {
  return MockClient((request) async {
    requests.add(request);
    return http.Response('{"ok":true}', 200);
  });
}

DatadogFlagsConfig _datadogConfig() {
  return const DatadogFlagsConfig(
    clientToken: 'client-token',
    env: 'staging',
    site: DatadogFlagsSite.us1,
    applicationId: 'application-id',
    service: 'shopping-cart',
    version: '1.2.3',
  );
}

FlagAssignment _assignment({String reason = 'TARGETING_MATCH'}) {
  return FlagAssignment.fromJson({
    'allocationKey': 'allocation-a',
    'variationKey': 'enabled',
    'variationType': 'boolean',
    'variationValue': true,
    'reason': reason,
    'doLog': true,
  });
}

List<http.Request> _evaluationRequests(List<http.Request> requests) {
  return requests
      .where((request) => request.url.path == '/api/v2/flagevaluation')
      .toList();
}

List<Map<String, Object?>> _flagEvaluations(http.Request request) {
  if (isWebFlagsIntake) {
    return request.body
        .split('\n')
        .where((line) => line.isNotEmpty)
        .map((line) => jsonDecode(line) as Map<String, Object?>)
        .toList();
  }
  final body = jsonDecode(request.body) as Map<String, Object?>;
  return (body['flagEvaluations'] as List<Object?>)
      .cast<Map<String, Object?>>();
}

void _expectIntakeMetadata(
  http.Request request, {
  required String nativeContentType,
}) {
  expect(request.url.queryParameters['ddsource'], datadogFlagsSource);
  if (isWebFlagsIntake) {
    expect(request.headers['Content-Type'], startsWith('text/plain'));
    expect(request.headers['DD-API-KEY'], isNull);
    expect(request.headers['DD-EVP-ORIGIN'], isNull);
    expect(request.headers['DD-EVP-ORIGIN-VERSION'], isNull);
    expect(request.headers['DD-REQUEST-ID'], isNull);
    expect(request.url.queryParameters['dd-api-key'], 'client-token');
    expect(request.url.queryParameters['dd-evp-origin'], datadogFlagsSource);
    expect(
      request.url.queryParameters['dd-evp-origin-version'],
      datadogFlagsSdkVersion,
    );
    expect(request.url.queryParameters['dd-request-id'], isNotEmpty);
    return;
  }

  expect(request.headers['Content-Type'], nativeContentType);
  expect(request.headers['DD-API-KEY'], 'client-token');
  expect(request.headers['DD-EVP-ORIGIN'], datadogFlagsSource);
  expect(request.headers['DD-EVP-ORIGIN-VERSION'], datadogFlagsSdkVersion);
  expect(request.headers['DD-REQUEST-ID'], isNotEmpty);
}

Future<void> _waitUntil(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}
