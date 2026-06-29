// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/evaluation_aggregator.dart';
import 'package:datadog_flags/src/exposure_logger.dart';
import 'package:datadog_flags/src/flags_store.dart';
import 'package:datadog_flags/src/sdk_metadata.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('enable creates the default shared client', () async {
    final requests = <http.Request>[];
    final datadogFlags = DatadogFlags();
    await datadogFlags.enable(
      configuration: DatadogFlagsConfiguration(
        datadogConfig: _datadogConfig(),
        httpClient: _clientWithResponse(requests, _assignmentsResponse()),
      ),
    );

    final shared = datadogFlags.sharedClient();

    expect(shared.name, DatadogFlags.defaultClientName);
    expect(datadogFlags.isEnabled, isTrue);
  });

  test('disable does not close a caller-provided HTTP client', () async {
    final requests = <http.Request>[];
    final httpClient = _CloseTrackingClient(
      _clientWithResponse(requests, _assignmentsResponse()),
    );
    addTearDown(httpClient.close);
    final datadogFlags = DatadogFlags();
    await datadogFlags.enable(
      configuration: DatadogFlagsConfiguration(
        datadogConfig: _datadogConfig(),
        httpClient: httpClient,
      ),
    );

    await datadogFlags.disable();

    expect(httpClient.closed, isFalse);
  });

  test('missing configuration creates a no-op client', () async {
    final datadogFlags = DatadogFlags();

    await datadogFlags.enable();
    final flags = datadogFlags.sharedClient();

    expect(datadogFlags.isEnabled, isFalse);
    final details = flags.getBooleanDetails(
      key: 'show-paywall',
      defaultValue: false,
    );
    expect(details.value, isFalse);
    expect(details.error, FlagEvaluationError.providerNotReady);
  });

  test('coerces evaluation flush intervals to native SDK bounds', () async {
    expect(
      const DatadogFlagsConfiguration(
        evaluationFlushInterval: Duration.zero,
      ).evaluationFlushInterval,
      DatadogFlagsConfiguration.minEvaluationFlushInterval,
    );
    expect(
      const DatadogFlagsConfiguration(
        evaluationFlushInterval: Duration(minutes: 2),
      ).evaluationFlushInterval,
      DatadogFlagsConfiguration.maxEvaluationFlushInterval,
    );
    expect(
      const DatadogFlagsConfiguration(
        evaluationFlushInterval: Duration(seconds: 30),
      ).evaluationFlushInterval,
      const Duration(seconds: 30),
    );

    final datadogFlags = DatadogFlags();
    await expectLater(
      datadogFlags.enable(
        configuration: DatadogFlagsConfiguration(
          datadogConfig: _datadogConfig(),
          evaluationFlushInterval: Duration.zero,
          httpClient: _clientWithResponse([], _assignmentsResponse()),
        ),
      ),
      completes,
    );
    await datadogFlags.disable();
  });

  test('returns typed details and drops unknown variation types', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    final booleanDetails = client.getBooleanDetails(
      key: 'show-paywall',
      defaultValue: false,
    );
    expect(booleanDetails.value, isTrue);

    final stringDetails = client.getStringDetails(
      key: 'theme',
      defaultValue: 'light',
    );
    expect(stringDetails.value, 'dark');

    final integerDetails = client.getIntegerDetails(
      key: 'max-items',
      defaultValue: 1,
    );
    expect(integerDetails.value, 3);

    final doubleDetails = client.getDoubleDetails(
      key: 'ratio',
      defaultValue: 1,
    );
    expect(doubleDetails.value, 0.5);

    final objectDetails = client.getObjectDetails(
      key: 'config',
      defaultValue: null,
    );
    expect(objectDetails.value, {
      'enabled': true,
      'labels': ['a', 'b'],
    });

    final missing = client.getStringDetails(
      key: 'bad',
      defaultValue: 'fallback',
    );
    expect(missing.value, 'fallback');
    expect(missing.error, FlagEvaluationError.flagNotFound);
  });

  test(
    'reports provider readiness, not-found, and type mismatch details',
    () async {
      final requests = <http.Request>[];
      final client = await _createClient(
        requests: requests,
        response: _assignmentsResponse(),
      );

      final notReady = client.getBooleanDetails(
        key: 'show-paywall',
        defaultValue: false,
      );
      expect(notReady.value, isFalse);
      expect(notReady.error, FlagEvaluationError.providerNotReady);

      await client.initialize(
        const FlagsEvaluationContext(targetingKey: 'user-123'),
      );

      final missing = client.getBooleanDetails(
        key: 'missing',
        defaultValue: false,
      );
      expect(missing.value, isFalse);
      expect(missing.error, FlagEvaluationError.flagNotFound);

      final mismatch = client.getIntegerDetails(
        key: 'show-paywall',
        defaultValue: 7,
      );
      expect(mismatch.value, 7);
      expect(mismatch.error, FlagEvaluationError.typeMismatch);
    },
  );

  test('keeps the latest context when fetches resolve out of order', () async {
    final requests = <http.Request>[];
    final responseCompleters = <Completer<http.Response>>[];
    final client = await _createClient(
      requests: requests,
      httpClient: MockClient((request) {
        requests.add(request);
        final completer = Completer<http.Response>();
        responseCompleters.add(completer);
        return completer.future;
      }),
    );

    final first = client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-first'),
    );
    final second = client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-second'),
    );
    await _waitUntil(() => responseCompleters.length == 2);

    expect(responseCompleters, hasLength(2));
    responseCompleters[1].complete(
      http.Response(
        jsonEncode(
          _assignmentsResponse(
            booleanVariationKey: 'second',
            booleanValue: false,
          ),
        ),
        200,
      ),
    );
    await second;

    responseCompleters[0].complete(
      http.Response(
        jsonEncode(
          _assignmentsResponse(
            booleanVariationKey: 'first',
            booleanValue: true,
          ),
        ),
        200,
      ),
    );
    await first;

    final details = client.getBooleanDetails(
      key: 'show-paywall',
      defaultValue: true,
    );
    expect(details.value, isFalse);
    expect(details.variant, 'second');
  });

  test('does not throw when context fetch fails', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('not found', 404);
      }),
    );

    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    final details = client.getBooleanDetails(
      key: 'show-paywall',
      defaultValue: false,
    );
    expect(details.value, isFalse);
    expect(details.error, FlagEvaluationError.providerNotReady);
  });

  test('returns object defaults without validating their JSON shape', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
    );

    final defaultValue = Object();
    final details = client.getObjectDetails(
      key: 'config',
      defaultValue: defaultValue,
    );

    expect(details.value, same(defaultValue));
    expect(details.error, FlagEvaluationError.providerNotReady);
  });

  test('shutdown clears the current assignment state', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    expect(
      client.getBooleanDetails(key: 'show-paywall', defaultValue: false).value,
      isTrue,
    );

    await client.shutdown();

    final details = client.getBooleanDetails(
      key: 'show-paywall',
      defaultValue: false,
    );
    expect(details.value, isFalse);
    expect(details.error, FlagEvaluationError.providerNotReady);
  });

  test(
    'emits exposure events for successful details at the HTTP boundary',
    () async {
      final requests = <http.Request>[];
      final now = DateTime.fromMillisecondsSinceEpoch(1234567890000);
      final client = await _createClient(
        requests: requests,
        response: _assignmentsResponse(),
        trackExposures: true,
        dateProvider: () => now,
      );

      client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
      await Future<void>.delayed(Duration.zero);
      expect(_exposureRequests(requests), isEmpty);

      await client.initialize(
        const FlagsEvaluationContext(
          targetingKey: 'user-123',
          attributes: {'plan': 'pro'},
        ),
      );

      client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
      client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
      client.getIntegerDetails(key: 'show-paywall', defaultValue: 0);
      client.getBooleanDetails(key: 'missing', defaultValue: false);
      await client.shutdown();

      expect(_exposureRequests(requests), hasLength(1));
      final request = _exposureRequests(requests).single;
      expect(
        request.url.toString(),
        'https://browser-intake-datadoghq.com/api/v2/exposures?ddsource=dart-client',
      );
      expect(request.headers['Content-Type'], 'text/plain;charset=UTF-8');
      expect(request.headers['DD-API-KEY'], 'client-token');
      expect(request.headers['DD-EVP-ORIGIN'], 'dart-client');
      expect(request.headers['DD-EVP-ORIGIN-VERSION'], datadogFlagsSdkVersion);
      expect(request.headers['DD-REQUEST-ID'], isNotEmpty);

      final exposure = _exposureEvents(request).single;
      expect(exposure, {
        'timestamp': 1234567890000,
        'allocation': {'key': 'allocation-a'},
        'flag': {'key': 'show-paywall'},
        'variant': {'key': 'enabled'},
        'subject': {
          'id': 'user-123',
          'attributes': {'plan': 'pro'},
        },
      });
    },
  );

  test('does not emit exposures when tracking is disabled', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
      trackExposures: false,
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await Future<void>.delayed(Duration.zero);

    expect(_exposureRequests(requests), isEmpty);
  });

  test('does not emit exposures when doLog is false', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(doLog: false),
      trackExposures: true,
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await client.shutdown();

    expect(_exposureRequests(requests), isEmpty);
  });

  test('retries exposure emission after a failed send', () async {
    final requests = <http.Request>[];
    var exposureAttempt = 0;
    final client = await _createClient(
      requests: requests,
      trackExposures: true,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/precompute-assignments') {
          return http.Response(jsonEncode(_assignmentsResponse()), 200);
        }
        if (request.url.path == '/api/v2/exposures') {
          exposureAttempt += 1;
          return http.Response('{"ok":true}', exposureAttempt == 1 ? 500 : 200);
        }
        return http.Response('{"error":"unexpected"}', 404);
      }),
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await client.shutdown();
    await client.shutdown();

    expect(exposureAttempt, 2);
  });

  test('drops exposure emission after a non-retryable client error', () async {
    final requests = <http.Request>[];
    var exposureAttempt = 0;
    final client = await _createClient(
      requests: requests,
      trackExposures: true,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/precompute-assignments') {
          return http.Response(jsonEncode(_assignmentsResponse()), 200);
        }
        if (request.url.path == '/api/v2/exposures') {
          exposureAttempt += 1;
          return http.Response('{"error":"invalid token"}', 403);
        }
        return http.Response('{"error":"unexpected"}', 404);
      }),
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await client.shutdown();
    await client.shutdown();

    expect(exposureAttempt, 1);
  });

  test('waits for an in-flight exposure upload during shutdown', () async {
    final requests = <http.Request>[];
    final exposureStarted = Completer<void>();
    final exposureResponse = Completer<http.Response>();
    final client = await _createClient(
      requests: requests,
      trackExposures: true,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/precompute-assignments') {
          return http.Response(jsonEncode(_assignmentsResponse()), 200);
        }
        if (request.url.path == '/api/v2/exposures') {
          exposureStarted.complete();
          return exposureResponse.future;
        }
        return http.Response('{"error":"unexpected"}', 404);
      }),
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );
    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);

    final firstFlush = client.shutdown();
    await exposureStarted.future;

    var secondFlushCompleted = false;
    final secondFlush = client.shutdown().then((_) {
      secondFlushCompleted = true;
    });
    await Future<void>.delayed(Duration.zero);

    expect(secondFlushCompleted, isFalse);

    exposureResponse.complete(http.Response('{"ok":true}', 200));
    await firstFlush;
    await secondFlush;

    expect(secondFlushCompleted, isTrue);
    expect(_exposureRequests(requests), hasLength(1));
  });

  test('coalesces concurrent shutdown exposure drains after failure', () async {
    final requests = <http.Request>[];
    final exposureStarted = Completer<void>();
    final exposureResponse = Completer<http.Response>();
    var exposureAttempt = 0;
    final client = await _createClient(
      requests: requests,
      trackExposures: true,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/precompute-assignments') {
          return http.Response(jsonEncode(_assignmentsResponse()), 200);
        }
        if (request.url.path == '/api/v2/exposures') {
          exposureAttempt += 1;
          if (exposureAttempt == 1) {
            exposureStarted.complete();
            return exposureResponse.future;
          }
          return http.Response('{"ok":false}', 500);
        }
        return http.Response('{"error":"unexpected"}', 404);
      }),
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );
    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);

    final firstShutdown = client.shutdown();
    await exposureStarted.future;
    final secondShutdown = client.shutdown();
    await Future<void>.delayed(Duration.zero);

    expect(exposureAttempt, 1);

    exposureResponse.complete(http.Response('{"ok":false}', 500));
    await Future.wait([firstShutdown, secondShutdown]);

    expect(exposureAttempt, 1);
    expect(_exposureRequests(requests), hasLength(1));
  });

  test('bounds shutdown when an exposure upload does not complete', () async {
    addTearDown(() {
      ExposureLogger.uploadTimeout = ExposureLogger.defaultUploadTimeout;
    });
    ExposureLogger.uploadTimeout = const Duration(milliseconds: 1);

    final requests = <http.Request>[];
    final exposureResponse = Completer<http.Response>();
    final client = await _createClient(
      requests: requests,
      trackExposures: true,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/precompute-assignments') {
          return http.Response(jsonEncode(_assignmentsResponse()), 200);
        }
        if (request.url.path == '/api/v2/exposures') {
          return exposureResponse.future;
        }
        return http.Response('{"error":"unexpected"}', 404);
      }),
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );
    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);

    await expectLater(
      client.shutdown().timeout(const Duration(seconds: 1)),
      completes,
    );

    expect(exposureResponse.isCompleted, isFalse);
    expect(_exposureRequests(requests), hasLength(1));
  });

  test('batches unique exposure events in one request body', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
      trackExposures: true,
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    client.getStringDetails(key: 'theme', defaultValue: 'light');
    await client.shutdown();

    final request = _exposureRequests(requests).single;
    final events = _exposureEvents(request);
    expect(events, hasLength(2));
    expect(
      events.map((event) => (event['flag'] as Map<String, Object?>)['key']),
      ['show-paywall', 'theme'],
    );
    expect(request.body.split('\n'), hasLength(2));
  });

  test('deduplicates repeated exposures for the same assignment', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
      trackExposures: true,
    );
    await client.initialize(
      const FlagsEvaluationContext(
        targetingKey: 'user-123',
        attributes: {'plan': 'pro'},
      ),
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await client.initialize(
      const FlagsEvaluationContext(
        targetingKey: 'user-123',
        attributes: {'plan': 'enterprise'},
      ),
    );
    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await client.shutdown();

    final event = _exposureEvents(_exposureRequests(requests).single).single;
    expect(event['subject'], {
      'id': 'user-123',
      'attributes': {'plan': 'pro'},
    });
  });

  test('does not collapse distinct exposure tuples with separators', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(
        additionalFlags: {
          'c': _assignment(
            allocationKey: 'd',
            variationKey: 'e',
            variationType: 'boolean',
            variationValue: true,
          ),
          'b|c': _assignment(
            allocationKey: 'd',
            variationKey: 'e',
            variationType: 'boolean',
            variationValue: true,
          ),
        },
      ),
      trackExposures: true,
    );

    await client.initialize(const FlagsEvaluationContext(targetingKey: 'a|b'));
    client.getBooleanDetails(key: 'c', defaultValue: false);
    await client.initialize(const FlagsEvaluationContext(targetingKey: 'a'));
    client.getBooleanDetails(key: 'b|c', defaultValue: false);
    await client.shutdown();

    final events = _exposureEvents(_exposureRequests(requests).single);
    expect(events, hasLength(2));
    expect(
      events.map(
        (event) => [
          ((event['subject'] as Map<String, Object?>)['id']),
          ((event['flag'] as Map<String, Object?>)['key']),
        ],
      ),
      [
        ['a|b', 'c'],
        ['a', 'b|c'],
      ],
    );
  });

  test('logs another exposure when the assignment cycles', () async {
    final requests = <http.Request>[];
    var precomputeRequestCount = 0;
    final client = await _createClient(
      requests: requests,
      trackExposures: true,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/precompute-assignments') {
          precomputeRequestCount += 1;
          return http.Response(
            jsonEncode(
              _assignmentsResponse(
                booleanVariationKey:
                    precomputeRequestCount.isOdd ? 'enabled' : 'disabled',
                booleanValue: precomputeRequestCount.isOdd,
              ),
            ),
            200,
          );
        }
        return http.Response('{"ok":true}', 200);
      }),
    );

    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );
    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );
    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );
    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await client.shutdown();

    final events = _exposureEvents(_exposureRequests(requests).single);
    expect(
      events.map((event) => (event['variant'] as Map<String, Object?>)['key']),
      ['enabled', 'disabled', 'enabled'],
    );
  });

  test(
    'emits flag evaluation batches for typed details at the HTTP boundary',
    () async {
      final requests = <http.Request>[];
      final now = DateTime.fromMillisecondsSinceEpoch(1234567890000);
      final client = await _createClient(
        requests: requests,
        response: _assignmentsResponse(),
        trackExposures: false,
        trackEvaluations: true,
        dateProvider: () => now,
      );
      await client.initialize(
        const FlagsEvaluationContext(
          targetingKey: 'user-123',
          attributes: {'plan': 'pro'},
        ),
      );

      client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
      client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
      client.getIntegerDetails(key: 'show-paywall', defaultValue: 7);
      client.getBooleanDetails(key: 'missing', defaultValue: false);
      await client.shutdown();

      final request = _evaluationRequests(requests).single;
      expect(
        request.url.toString(),
        'https://browser-intake-datadoghq.com/api/v2/flagevaluation?ddsource=dart-client',
      );
      expect(request.headers['Content-Type'], 'application/json');
      expect(request.headers['DD-API-KEY'], 'client-token');
      expect(request.headers['DD-EVP-ORIGIN'], 'dart-client');
      expect(request.headers['DD-EVP-ORIGIN-VERSION'], datadogFlagsSdkVersion);
      expect(request.headers['DD-REQUEST-ID'], isNotEmpty);

      final body = jsonDecode(request.body) as Map<String, Object?>;
      expect(body['context'], _datadogEventContext());

      final evaluations = (body['flagEvaluations'] as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(evaluations, hasLength(3));

      final success = _evaluation(
        evaluations,
        flagKey: 'show-paywall',
        error: null,
      );
      expect(success['timestamp'], 1234567890000);
      expect(success['first_evaluation'], 1234567890000);
      expect(success['last_evaluation'], 1234567890000);
      expect(success['evaluation_count'], 2);
      expect(success['variant'], {'key': 'enabled'});
      expect(success['allocation'], {'key': 'allocation-a'});
      expect(success['targeting_key'], 'user-123');
      expect(success['context'], {
        'evaluation': {'plan': 'pro'},
      });
      expect(success.containsKey('runtime_default_used'), isFalse);

      final mismatch = _evaluation(
        evaluations,
        flagKey: 'show-paywall',
        error: FlagEvaluationError.typeMismatch.code,
      );
      expect(mismatch['runtime_default_used'], isTrue);
      expect(mismatch['error'], {
        'message': FlagEvaluationError.typeMismatch.code,
      });
      expect(mismatch.containsKey('variant'), isFalse);
      expect(mismatch.containsKey('allocation'), isFalse);

      final missing = _evaluation(
        evaluations,
        flagKey: 'missing',
        error: FlagEvaluationError.flagNotFound.code,
      );
      expect(missing['runtime_default_used'], isTrue);
      expect(missing['error'], {
        'message': FlagEvaluationError.flagNotFound.code,
      });
      expect(missing['targeting_key'], 'user-123');
    },
  );

  test('emits provider-not-ready flag evaluation defaults', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
      trackExposures: false,
      trackEvaluations: true,
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await client.shutdown();

    final request = _evaluationRequests(requests).single;
    final body = jsonDecode(request.body) as Map<String, Object?>;
    final evaluations =
        (body['flagEvaluations'] as List<Object?>).cast<Map<String, Object?>>();

    final evaluation = evaluations.single;
    expect(evaluation['flag'], {'key': 'show-paywall'});
    expect(evaluation['runtime_default_used'], isTrue);
    expect(evaluation['error'], {
      'message': FlagEvaluationError.providerNotReady.code,
    });
    expect(evaluation.containsKey('targeting_key'), isFalse);
  });

  test('does not emit flag evaluations when tracking is disabled', () async {
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
      trackExposures: false,
      trackEvaluations: false,
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await client.shutdown();

    expect(_evaluationRequests(requests), isEmpty);
  });

  test('sends flag evaluations when max batch size is reached', () async {
    addTearDown(() {
      EvaluationAggregator.maxBatchSize =
          EvaluationAggregator.defaultMaxBatchSize;
    });
    EvaluationAggregator.maxBatchSize = 1;

    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
      trackExposures: false,
      trackEvaluations: true,
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await _waitUntil(() => _evaluationRequests(requests).length == 1);
    await client.shutdown();

    expect(_evaluationRequests(requests), hasLength(1));
  });

  test('retries flag evaluation emission after a failed send', () async {
    final requests = <http.Request>[];
    var evaluationAttempt = 0;
    final client = await _createClient(
      requests: requests,
      trackExposures: false,
      trackEvaluations: true,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/precompute-assignments') {
          return http.Response(jsonEncode(_assignmentsResponse()), 200);
        }
        if (request.url.path == '/api/v2/flagevaluation') {
          evaluationAttempt += 1;
          return http.Response(
            '{"ok":true}',
            evaluationAttempt == 1 ? 500 : 200,
          );
        }
        return http.Response('{"error":"unexpected"}', 404);
      }),
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await client.shutdown();
    await client.shutdown();

    expect(evaluationAttempt, 2);
    expect(_evaluationRequests(requests), hasLength(2));
  });

  test('drops flag evaluation emission after a non-retryable client error',
      () async {
    final requests = <http.Request>[];
    var evaluationAttempt = 0;
    final client = await _createClient(
      requests: requests,
      trackExposures: false,
      trackEvaluations: true,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/precompute-assignments') {
          return http.Response(jsonEncode(_assignmentsResponse()), 200);
        }
        if (request.url.path == '/api/v2/flagevaluation') {
          evaluationAttempt += 1;
          return http.Response('{"error":"invalid token"}', 403);
        }
        return http.Response('{"error":"unexpected"}', 404);
      }),
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await client.shutdown();
    await client.shutdown();

    expect(evaluationAttempt, 1);
    expect(_evaluationRequests(requests), hasLength(1));
  });

  test('keeps flag evaluations recorded while upload is in flight', () async {
    addTearDown(() {
      EvaluationAggregator.maxBatchSize =
          EvaluationAggregator.defaultMaxBatchSize;
    });
    EvaluationAggregator.maxBatchSize = 1;

    final requests = <http.Request>[];
    final evaluationStarted = Completer<void>();
    final evaluationResponse = Completer<http.Response>();
    var evaluationAttempt = 0;
    final client = await _createClient(
      requests: requests,
      trackExposures: false,
      trackEvaluations: true,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/precompute-assignments') {
          return http.Response(jsonEncode(_assignmentsResponse()), 200);
        }
        if (request.url.path == '/api/v2/flagevaluation') {
          evaluationAttempt += 1;
          if (evaluationAttempt == 1) {
            evaluationStarted.complete();
            return evaluationResponse.future;
          }
          return http.Response('{"ok":true}', 200);
        }
        return http.Response('{"error":"unexpected"}', 404);
      }),
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await evaluationStarted.future;
    client.getStringDetails(key: 'theme', defaultValue: 'light');
    evaluationResponse.complete(http.Response('{"ok":true}', 200));
    await client.shutdown();

    expect(_evaluationRequests(requests), hasLength(2));
    final secondBody = jsonDecode(_evaluationRequests(requests).last.body)
        as Map<String, Object?>;
    final secondEvaluations = (secondBody['flagEvaluations'] as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(secondEvaluations.single['flag'], {'key': 'theme'});
  });

  test('bounds shutdown when a flag evaluation upload does not complete',
      () async {
    addTearDown(() {
      EvaluationAggregator.uploadTimeout =
          EvaluationAggregator.defaultUploadTimeout;
    });
    EvaluationAggregator.uploadTimeout = const Duration(milliseconds: 1);

    final requests = <http.Request>[];
    final evaluationResponse = Completer<http.Response>();
    final client = await _createClient(
      requests: requests,
      trackExposures: false,
      trackEvaluations: true,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/precompute-assignments') {
          return http.Response(jsonEncode(_assignmentsResponse()), 200);
        }
        if (request.url.path == '/api/v2/flagevaluation') {
          return evaluationResponse.future;
        }
        return http.Response('{"error":"unexpected"}', 404);
      }),
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );
    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);

    await expectLater(
      client.shutdown().timeout(const Duration(seconds: 1)),
      completes,
    );

    expect(evaluationResponse.isCompleted, isFalse);
    expect(_evaluationRequests(requests), hasLength(1));
  });

  test('uses matching stored assignments while live refresh runs', () async {
    final store = InMemoryDatadogFlagsStore();
    final requests = <http.Request>[];
    final datadogFlags = DatadogFlags();
    addTearDown(datadogFlags.disable);
    await datadogFlags.enable(
      configuration: DatadogFlagsConfiguration(
        datadogConfig: _datadogConfig(),
        trackExposures: false,
        trackEvaluations: false,
        httpClient: _clientWithResponse(requests, _assignmentsResponse()),
        store: store,
      ),
    );
    const cachedContext = FlagsEvaluationContext(
      targetingKey: 'user-123',
      attributes: {
        'plan': 'pro',
        'config': {'b': 2, 'a': 1},
        'cohorts': ['beta', 'paid'],
      },
    );
    await datadogFlags.sharedClient().initialize(cachedContext);
    await datadogFlags.disable();

    final refreshResponse = Completer<http.Response>();
    final restoredRequests = <http.Request>[];
    await datadogFlags.enable(
      configuration: DatadogFlagsConfiguration(
        datadogConfig: _datadogConfig(),
        trackExposures: false,
        trackEvaluations: false,
        httpClient: MockClient((request) {
          restoredRequests.add(request);
          return refreshResponse.future;
        }),
        store: store,
      ),
    );
    final restored = datadogFlags.sharedClient();

    final refresh = restored.initialize(
      const FlagsEvaluationContext(
        targetingKey: 'user-123',
        attributes: {
          'cohorts': ['beta', 'paid'],
          'config': {'a': 1, 'b': 2},
          'plan': 'pro',
        },
      ),
    );
    await _waitUntil(() => restoredRequests.length == 1);
    expect(
      restored
          .getBooleanDetails(key: 'show-paywall', defaultValue: false)
          .value,
      isTrue,
    );

    refreshResponse.complete(
      http.Response(jsonEncode(_assignmentsResponse(booleanValue: false)), 200),
    );
    await refresh;
    expect(
      restored.getBooleanDetails(key: 'show-paywall', defaultValue: true).value,
      isFalse,
    );
  });

  test('does not replace current assignments with matching stored assignments',
      () async {
    final store = InMemoryDatadogFlagsStore();
    final requests = <http.Request>[];
    final liveResponse = Completer<http.Response>();
    var precomputeRequests = 0;
    final datadogFlags = DatadogFlags();
    addTearDown(datadogFlags.disable);
    await datadogFlags.enable(
      configuration: DatadogFlagsConfiguration(
        datadogConfig: _datadogConfig(),
        trackExposures: false,
        trackEvaluations: false,
        httpClient: MockClient((request) {
          requests.add(request);
          precomputeRequests += 1;
          if (precomputeRequests == 1) {
            return Future.value(
              http.Response(jsonEncode(_assignmentsResponse()), 200),
            );
          }
          return liveResponse.future;
        }),
        store: store,
      ),
    );
    const context = FlagsEvaluationContext(targetingKey: 'user-123');
    final client = datadogFlags.sharedClient();

    await client.initialize(context);
    expect(
      client.getBooleanDetails(key: 'show-paywall', defaultValue: false).value,
      isTrue,
    );

    await store.write(
      DatadogFlags.defaultClientName,
      FlagsData.fromJson({
        'flags': {
          'show-paywall': _assignment(
            allocationKey: 'stale-allocation',
            variationKey: 'disabled',
            variationType: 'boolean',
            variationValue: false,
          ),
        },
        'context': context.toJson(),
        'date': DateTime.utc(2026, 6, 23).toIso8601String(),
      }),
    );

    final refresh = client.initialize(context);
    await _waitUntil(() => requests.length == 2);
    expect(
      client.getBooleanDetails(key: 'show-paywall', defaultValue: false).value,
      isTrue,
    );

    liveResponse.complete(
      http.Response(jsonEncode(_assignmentsResponse(booleanValue: false)), 200),
    );
    await refresh;
    expect(
      client.getBooleanDetails(key: 'show-paywall', defaultValue: true).value,
      isFalse,
    );
  });

  test('ignores stored assignments for a different context', () async {
    final store = InMemoryDatadogFlagsStore();
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
      trackExposures: false,
      trackEvaluations: false,
      store: store,
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    final liveResponse = Completer<http.Response>();
    final restoredRequests = <http.Request>[];
    final datadogFlags = DatadogFlags();
    await datadogFlags.enable(
      configuration: DatadogFlagsConfiguration(
        datadogConfig: _datadogConfig(),
        trackExposures: false,
        trackEvaluations: false,
        httpClient: MockClient((request) {
          restoredRequests.add(request);
          return liveResponse.future;
        }),
        store: store,
      ),
    );
    addTearDown(datadogFlags.disable);
    final restored = datadogFlags.sharedClient();

    final refresh = restored.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-456'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      restored
          .getBooleanDetails(key: 'show-paywall', defaultValue: false)
          .error,
      FlagEvaluationError.providerNotReady,
    );

    liveResponse.complete(
      http.Response(jsonEncode(_assignmentsResponse(booleanValue: false)), 200),
    );
    await refresh;
    expect(restoredRequests, hasLength(1));
    expect(
      restored.getBooleanDetails(key: 'show-paywall', defaultValue: true).value,
      isFalse,
    );
  });

  test(
      'reset clears memory and stored assignments without shutting down client',
      () async {
    final store = InMemoryDatadogFlagsStore();
    final requests = <http.Request>[];
    final datadogFlags = DatadogFlags();
    addTearDown(datadogFlags.disable);
    await datadogFlags.enable(
      configuration: DatadogFlagsConfiguration(
        datadogConfig: _datadogConfig(),
        trackExposures: false,
        trackEvaluations: true,
        evaluationFlushInterval: const Duration(seconds: 1),
        httpClient: _clientWithResponse(requests, _assignmentsResponse()),
        store: store,
      ),
    );
    final client = datadogFlags.sharedClient();
    const context = FlagsEvaluationContext(targetingKey: 'user-123');
    await client.initialize(context);
    expect(await store.read(DatadogFlags.defaultClientName), isNotNull);

    await datadogFlags.reset();

    expect(await store.read(DatadogFlags.defaultClientName), isNull);
    expect(
      client.getBooleanDetails(key: 'show-paywall', defaultValue: false).error,
      FlagEvaluationError.providerNotReady,
    );

    await client.initialize(context);
    client.getBooleanDetails(key: 'show-paywall', defaultValue: false);
    await _waitUntil(() => _evaluationRequests(requests).length == 1);
  });

  test('reset cancels in-flight assignment refreshes', () async {
    final liveResponse = Completer<http.Response>();
    final requests = <http.Request>[];
    final datadogFlags = DatadogFlags();
    addTearDown(datadogFlags.disable);
    await datadogFlags.enable(
      configuration: DatadogFlagsConfiguration(
        datadogConfig: _datadogConfig(),
        trackExposures: false,
        trackEvaluations: false,
        httpClient: MockClient((request) {
          requests.add(request);
          return liveResponse.future;
        }),
      ),
    );
    final client = datadogFlags.sharedClient();
    final initialize = client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );
    await _waitUntil(() => requests.length == 1);

    await datadogFlags.reset();
    liveResponse
        .complete(http.Response(jsonEncode(_assignmentsResponse()), 200));
    await initialize;

    expect(
      client.getBooleanDetails(key: 'show-paywall', defaultValue: false).error,
      FlagEvaluationError.providerNotReady,
    );
  });

  test('reset waits for pending store writes before deleting assignments',
      () async {
    final store = _DelayedWriteStore();
    final requests = <http.Request>[];
    final datadogFlags = DatadogFlags();
    addTearDown(datadogFlags.disable);
    await datadogFlags.enable(
      configuration: DatadogFlagsConfiguration(
        datadogConfig: _datadogConfig(),
        trackExposures: false,
        trackEvaluations: false,
        httpClient: _clientWithResponse(requests, _assignmentsResponse()),
        store: store,
      ),
    );
    final initialize = datadogFlags
        .sharedClient()
        .initialize(const FlagsEvaluationContext(targetingKey: 'user-123'));

    await store.writeStarted.future;
    final reset = datadogFlags.reset();
    store.allowWrite.complete();

    await initialize;
    await reset;
    expect(await store.read(DatadogFlags.defaultClientName), isNull);
  });

  test('unsupported context attributes miss cache without throwing', () async {
    final store = InMemoryDatadogFlagsStore();
    final requests = <http.Request>[];
    final client = await _createClient(
      requests: requests,
      response: _assignmentsResponse(),
      trackExposures: false,
      trackEvaluations: false,
      store: store,
    );
    await client.initialize(
      const FlagsEvaluationContext(targetingKey: 'user-123'),
    );

    await expectLater(
      client.initialize(
        FlagsEvaluationContext(
          targetingKey: 'user-123',
          attributes: {'unsupported': Object()},
        ),
      ),
      completes,
    );
    expect(
      client.getBooleanDetails(key: 'show-paywall', defaultValue: false).error,
      FlagEvaluationError.providerNotReady,
    );
    expect(requests, hasLength(1));
  });
}

Future<DatadogFlagsClient> _createClient({
  required List<http.Request> requests,
  Object? response,
  http.Client? httpClient,
  bool trackExposures = false,
  bool trackEvaluations = false,
  DateTime Function()? dateProvider,
  DatadogFlagsStore? store,
}) async {
  final datadogFlags = DatadogFlags();
  await datadogFlags.enable(
    configuration: DatadogFlagsConfiguration(
      datadogConfig: _datadogConfig(),
      trackExposures: trackExposures,
      trackEvaluations: trackEvaluations,
      evaluationFlushInterval: const Duration(hours: 1),
      httpClient: httpClient ?? _clientWithResponse(requests, response!),
      dateProvider: dateProvider ?? DateTime.now,
      store: store,
    ),
  );
  return datadogFlags.sharedClient();
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

http.Client _clientWithResponse(
  List<http.Request> requests,
  Object body, {
  int statusCode = 200,
}) {
  return MockClient((request) async {
    requests.add(request);
    return http.Response(jsonEncode(body), statusCode);
  });
}

class _CloseTrackingClient extends http.BaseClient {
  final http.Client _inner;
  bool closed = false;

  _CloseTrackingClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request);
  }

  @override
  void close() {
    closed = true;
    _inner.close();
    super.close();
  }
}

Map<String, Object?> _assignmentsResponse({
  bool doLog = true,
  String booleanAllocationKey = 'allocation-a',
  String booleanVariationKey = 'enabled',
  bool booleanValue = true,
  Map<String, Object?> additionalFlags = const {},
}) {
  return {
    'data': {
      'attributes': {
        'flags': {
          'show-paywall': {
            'allocationKey': booleanAllocationKey,
            'variationKey': booleanVariationKey,
            'variationType': 'boolean',
            'variationValue': booleanValue,
            'reason': 'TARGETING_MATCH',
            'doLog': doLog,
          },
          'theme': {
            'allocationKey': 'allocation-b',
            'variationKey': 'dark',
            'variationType': 'string',
            'variationValue': 'dark',
            'reason': 'TARGETING_MATCH',
            'doLog': true,
          },
          'max-items': {
            'allocationKey': 'allocation-c',
            'variationKey': 'three',
            'variationType': 'integer',
            'variationValue': 3,
            'reason': 'TARGETING_MATCH',
            'doLog': true,
          },
          'ratio': {
            'allocationKey': 'allocation-d',
            'variationKey': 'half',
            'variationType': 'float',
            'variationValue': 0.5,
            'reason': 'TARGETING_MATCH',
            'doLog': true,
          },
          'config': {
            'allocationKey': 'allocation-e',
            'variationKey': 'object',
            'variationType': 'object',
            'variationValue': {
              'enabled': true,
              'labels': ['a', 'b'],
            },
            'reason': 'TARGETING_MATCH',
            'doLog': true,
          },
          'bad': {
            'allocationKey': 'allocation-f',
            'variationKey': 'bad',
            'variationType': 'unsupported',
            'variationValue': 'bad',
            'reason': 'TARGETING_MATCH',
            'doLog': true,
          },
          ...additionalFlags,
        },
      },
    },
  };
}

Map<String, Object?> _assignment({
  required String allocationKey,
  required String variationKey,
  required String variationType,
  required Object variationValue,
  bool doLog = true,
}) {
  return {
    'allocationKey': allocationKey,
    'variationKey': variationKey,
    'variationType': variationType,
    'variationValue': variationValue,
    'reason': 'TARGETING_MATCH',
    'doLog': doLog,
  };
}

List<http.Request> _exposureRequests(List<http.Request> requests) {
  return requests
      .where((request) => request.url.path == '/api/v2/exposures')
      .toList();
}

List<http.Request> _evaluationRequests(List<http.Request> requests) {
  return requests
      .where((request) => request.url.path == '/api/v2/flagevaluation')
      .toList();
}

List<Map<String, Object?>> _exposureEvents(http.Request request) {
  return request.body
      .split('\n')
      .where((line) => line.isNotEmpty)
      .map((line) => jsonDecode(line) as Map<String, Object?>)
      .toList();
}

Map<String, Object?> _datadogEventContext() {
  return {
    'env': 'staging',
    'service': 'shopping-cart',
    'version': '1.2.3',
    'rum': {
      'application': {'id': 'application-id'},
    },
  };
}

Map<String, Object?> _evaluation(
  List<Map<String, Object?>> evaluations, {
  required String flagKey,
  required String? error,
}) {
  return evaluations.singleWhere((evaluation) {
    final flag = evaluation['flag'] as Map<String, Object?>;
    final errorBody = evaluation['error'] as Map<String, Object?>?;
    return flag['key'] == flagKey && errorBody?['message'] == error;
  });
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

class _DelayedWriteStore implements DatadogFlagsStore {
  final InMemoryDatadogFlagsStore _delegate = InMemoryDatadogFlagsStore();
  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> allowWrite = Completer<void>();

  @override
  Future<FlagsData?> read(String clientName) {
    return _delegate.read(clientName);
  }

  @override
  Future<void> write(String clientName, FlagsData data) async {
    if (!writeStarted.isCompleted) {
      writeStarted.complete();
    }
    await allowWrite.future;
    await _delegate.write(clientName, data);
  }

  @override
  Future<void> delete(String clientName) {
    return _delegate.delete(clientName);
  }
}
