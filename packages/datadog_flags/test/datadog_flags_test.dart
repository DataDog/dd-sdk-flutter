// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/default_flags_client.dart';
import 'package:datadog_flags/src/evaluation_aggregator.dart';
import 'package:datadog_flags/src/exposure_logger.dart';
import 'package:datadog_flags/src/flag_assignments_fetcher.dart';
import 'package:datadog_flags/src/flags_repository.dart';
import 'package:datadog_flags/src/rum_flag_evaluation_reporter.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late List<http.Request> requests;
  late DateTime now;

  DatadogFlagsContext datadogContext({DatadogSite site = DatadogSite.us1}) {
    return DatadogFlagsContext(
      clientToken: 'client-token',
      env: 'staging',
      site: site,
      service: 'flutter-example',
      version: '1.2.3',
      applicationId: 'rum-app-id',
      sdkVersion: '9.8.7',
    );
  }

  setUp(() async {
    requests = [];
    now = DateTime.fromMillisecondsSinceEpoch(1234567890000);
    await DatadogFlags.disable();
  });

  tearDown(() async {
    await DatadogFlags.disable();
  });

  http.Client clientWithResponse(Object body, {int statusCode = 200}) {
    return MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode(body), statusCode);
    });
  }

  Map<String, Object?> assignmentsResponse({
    bool doLog = true,
    String booleanVariationKey = 'enabled',
    bool booleanValue = true,
  }) {
    return {
      'data': {
        'attributes': {
          'flags': {
            'show-paywall': {
              'allocationKey': 'allocation-a',
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
          },
        },
      },
    };
  }

  Future<DatadogFlagsClient> createClient({
    required http.Client httpClient,
    InMemoryDatadogFlagsStore? store,
    DatadogSite site = DatadogSite.us1,
    bool trackExposures = true,
    bool trackEvaluations = true,
    DatadogFlagsAssignmentsFetchObserver? assignmentsFetchObserver,
  }) async {
    await DatadogFlags.enable(
      configuration: DatadogFlagsConfiguration(
        datadogContext: datadogContext(site: site),
        store: store ?? InMemoryDatadogFlagsStore(),
        httpClient: httpClient,
        dateProvider: () => now,
        evaluationFlushInterval: const Duration(seconds: 1),
        trackExposures: trackExposures,
        trackEvaluations: trackEvaluations,
        assignmentsFetchObserver: assignmentsFetchObserver,
      ),
    );
    return DatadogFlagsClient.create();
  }

  List<http.Request> exposureRequests() {
    return requests
        .where((request) => request.url.path == '/api/v2/exposures')
        .toList();
  }

  List<http.Request> evaluationRequests() {
    return requests
        .where((request) => request.url.path == '/api/v2/flagevaluation')
        .toList();
  }

  Future<void> waitUntil(
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

  test('enable creates the default shared client', () async {
    await DatadogFlags.enable(
      configuration: DatadogFlagsConfiguration(
        datadogContext: datadogContext(),
        store: InMemoryDatadogFlagsStore(),
        httpClient: clientWithResponse(assignmentsResponse()),
        dateProvider: () => now,
      ),
    );

    final shared = DatadogFlags.sharedClient();

    expect(shared.name, DatadogFlagsClient.defaultName);
  });

  test('does not close custom HTTP clients when re-enabling', () async {
    final first = CloseTrackingClient();
    final second = CloseTrackingClient();

    await DatadogFlags.enable(
      configuration: DatadogFlagsConfiguration(
        datadogContext: datadogContext(),
        store: InMemoryDatadogFlagsStore(),
        httpClient: first,
      ),
    );
    await DatadogFlags.enable(
      configuration: DatadogFlagsConfiguration(
        datadogContext: datadogContext(),
        store: InMemoryDatadogFlagsStore(),
        httpClient: second,
      ),
    );

    expect(first.closed, isFalse);
    await DatadogFlags.disable();
    expect(second.closed, isFalse);
  });

  test('fetches precomputed assignments using the iOS request shape', () async {
    final client = await createClient(
      httpClient: clientWithResponse(assignmentsResponse()),
    );

    await client.setEvaluationContext(const DatadogFlagsEvaluationContext(
      targetingKey: 'user-123',
      attributes: {
        'plan': 'pro',
        'seat_count': 3,
      },
    ));

    expect(requests, hasLength(1));
    expect(
      requests.single.url.toString(),
      'https://preview.ff-cdn.datadoghq.com/precompute-assignments',
    );
    expect(requests.single.headers['Content-Type'], 'application/vnd.api+json');
    expect(requests.single.headers['dd-client-token'], 'client-token');
    expect(requests.single.headers.containsKey('Accept-Encoding'), isFalse);
    expect(requests.single.headers['dd-application-id'], 'rum-app-id');

    final body = jsonDecode(requests.single.body) as Map<String, Object?>;
    final attributes = ((body['data'] as Map<String, Object?>)['attributes']
        as Map<String, Object?>);
    expect(attributes['env'], {'dd_env': 'staging'});
    expect(attributes.containsKey('source'), isFalse);
    expect(attributes['subject'], {
      'targeting_key': 'user-123',
      'targeting_attributes': {'plan': 'pro', 'seat_count': 3},
    });
  });

  test('reports assignment fetch HTTP and deserialization diagnostics',
      () async {
    final response = assignmentsResponse();
    final diagnostics = <DatadogFlagsAssignmentsFetchDiagnostics>[];
    final client = await createClient(
      httpClient: clientWithResponse(response),
      assignmentsFetchObserver: diagnostics.add,
    );

    await client.setEvaluationContext(const DatadogFlagsEvaluationContext(
      targetingKey: 'user-123',
    ));

    expect(diagnostics, hasLength(1));
    final diagnostic = diagnostics.single;
    expect(
      diagnostic.endpoint.toString(),
      'https://preview.ff-cdn.datadoghq.com/precompute-assignments',
    );
    expect(diagnostic.statusCode, 200);
    expect(diagnostic.httpDuration.inMicroseconds, greaterThanOrEqualTo(0));
    expect(diagnostic.deserializationDuration, isNotNull);
    expect(
      diagnostic.deserializationDuration!.inMicroseconds,
      greaterThanOrEqualTo(0),
    );
    expect(
        diagnostic.responseBodyBytes, utf8.encode(jsonEncode(response)).length);
    expect(diagnostic.receivedFlagCount, 6);
    expect(diagnostic.assignmentCount, 5);
  });

  test('uses Datadog site endpoints and falls back to US1 for gov flags', () {
    expect(
      datadogContext(site: DatadogSite.us3).flagsEndpoint().toString(),
      'https://preview.ff-cdn.us3.datadoghq.com',
    );
    expect(
      datadogContext(site: DatadogSite.us5).flagsEndpoint().toString(),
      'https://preview.ff-cdn.us5.datadoghq.com',
    );
    expect(
      datadogContext(site: DatadogSite.eu1).flagsEndpoint().toString(),
      'https://preview.ff-cdn.datadoghq.eu',
    );
    expect(
      datadogContext(site: DatadogSite.ap1).flagsEndpoint().toString(),
      'https://preview.ff-cdn.ap1.datadoghq.com',
    );
    expect(
      datadogContext(site: DatadogSite.ap2).flagsEndpoint().toString(),
      'https://preview.ff-cdn.ap2.datadoghq.com',
    );
    expect(
      datadogContext(site: DatadogSite.us1Fed).flagsEndpoint().toString(),
      'https://preview.ff-cdn.datadoghq.com',
    );
  });

  test('returns typed values and drops unknown variation types', () async {
    final client = await createClient(
      httpClient: clientWithResponse(assignmentsResponse()),
    );
    await client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
    );

    expect(
      client.getBooleanValue(key: 'show-paywall', defaultValue: false),
      isTrue,
    );
    expect(client.getStringValue(key: 'theme', defaultValue: 'light'), 'dark');
    expect(client.getIntegerValue(key: 'max-items', defaultValue: 1), 3);
    expect(client.getDoubleValue(key: 'ratio', defaultValue: 1), 0.5);
    expect(client.getObjectValue(key: 'config', defaultValue: null), {
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

  test('throws network errors for unsuccessful precompute responses', () async {
    final client = await createClient(
      httpClient: clientWithResponse({'error': 'nope'}, statusCode: 500),
      trackExposures: false,
      trackEvaluations: false,
    );

    await expectLater(
      client.setEvaluationContext(
        const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
      ),
      throwsA(isA<FlagsException>().having(
        (error) => error.type,
        'type',
        FlagsErrorType.networkError,
      )),
    );
  });

  test('throws invalid response errors for malformed precompute payloads',
      () async {
    final client = await createClient(
      httpClient: clientWithResponse({'data': null}),
      trackExposures: false,
      trackEvaluations: false,
    );

    await expectLater(
      client.setEvaluationContext(
        const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
      ),
      throwsA(isA<FlagsException>().having(
        (error) => error.type,
        'type',
        FlagsErrorType.invalidResponse,
      )),
    );
  });

  test('persists the last known assignments for a later client', () async {
    final store = InMemoryDatadogFlagsStore();
    final client = await createClient(
      httpClient: clientWithResponse(assignmentsResponse()),
      store: store,
      trackExposures: false,
      trackEvaluations: false,
    );
    await client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
    );
    await DatadogFlags.disable();

    final restored = await createClient(
      httpClient: clientWithResponse(assignmentsResponse()),
      store: store,
      trackExposures: false,
      trackEvaluations: false,
    );

    expect(
      restored.getBooleanValue(key: 'show-paywall', defaultValue: false),
      isTrue,
    );
  });

  test('keeps the latest context when fetches resolve out of order', () async {
    final responseCompleters = <Completer<http.Response>>[];
    final client = await createClient(
      trackExposures: false,
      trackEvaluations: false,
      httpClient: MockClient((request) {
        requests.add(request);
        final completer = Completer<http.Response>();
        responseCompleters.add(completer);
        return completer.future;
      }),
    );

    final first = client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-first'),
    );
    final second = client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-second'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(responseCompleters, hasLength(2));
    responseCompleters[1].complete(http.Response(
      jsonEncode(assignmentsResponse(
        booleanVariationKey: 'second',
        booleanValue: false,
      )),
      200,
    ));
    await second;

    responseCompleters[0].complete(http.Response(
      jsonEncode(assignmentsResponse(
        booleanVariationKey: 'first',
        booleanValue: true,
      )),
      200,
    ));
    await first;

    final details = client.getBooleanDetails(
      key: 'show-paywall',
      defaultValue: true,
    );
    expect(details.value, isFalse);
    expect(details.variant, 'second');
  });

  test('reports only successful typed evaluations to RUM', () async {
    final datadogContextValue = datadogContext();
    final config = DatadogFlagsConfiguration(
      datadogContext: datadogContextValue,
      store: InMemoryDatadogFlagsStore(),
      httpClient: clientWithResponse(assignmentsResponse()),
      dateProvider: () => now,
      trackExposures: false,
      trackEvaluations: false,
    );
    final fetcher = FlagAssignmentsFetcher(
      datadogContext: datadogContextValue,
      configuration: config,
      httpClient: config.httpClient!,
    );
    final repository = FlagsRepository(
      clientName: 'rum-test',
      fetcher: fetcher,
      store: config.store!,
      dateProvider: () => now,
    );
    await repository.restore();
    final fakeRum = FakeRumFlagEvaluationReporter();
    final client = DefaultDatadogFlagsClient(
      name: 'rum-test',
      repository: repository,
      exposureLogger: ExposureLogger(
        datadogContext: datadogContextValue,
        configuration: config,
        httpClient: config.httpClient!,
      ),
      evaluationAggregator: EvaluationAggregator(
        datadogContext: datadogContextValue,
        configuration: config,
        httpClient: config.httpClient!,
      ),
      rumFlagEvaluationReporter: fakeRum,
    );

    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    await client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
    );
    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    client.getIntegerValue(key: 'show-paywall', defaultValue: 0);
    client.getBooleanValue(key: 'missing', defaultValue: false);

    expect(fakeRum.calls, [
      const RumCall('show-paywall', true),
    ]);
  });

  test('reports provider readiness, not-found, and type mismatch details',
      () async {
    final client = await createClient(
      httpClient: clientWithResponse(assignmentsResponse()),
    );

    final notReady = client.getBooleanDetails(
      key: 'show-paywall',
      defaultValue: false,
    );
    expect(notReady.error, FlagEvaluationError.providerNotReady);

    await client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
    );

    final missing = client.getBooleanDetails(
      key: 'missing',
      defaultValue: false,
    );
    expect(missing.error, FlagEvaluationError.flagNotFound);

    final mismatch = client.getIntegerDetails(
      key: 'show-paywall',
      defaultValue: 7,
    );
    expect(mismatch.value, 7);
    expect(mismatch.error, FlagEvaluationError.typeMismatch);
  });

  test('counts exposure emissions at the HTTP boundary', () async {
    final client = await createClient(
      httpClient: clientWithResponse(assignmentsResponse()),
    );
    await client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    await Future<void>.delayed(Duration.zero);
    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    client.getIntegerValue(key: 'show-paywall', defaultValue: 0);
    client.getBooleanValue(key: 'missing', defaultValue: false);
    await Future<void>.delayed(Duration.zero);

    expect(exposureRequests(), hasLength(1));
    final request = exposureRequests().single;
    expect(
      request.url.toString(),
      'https://browser-intake-datadoghq.com/api/v2/exposures?ddsource=flutter',
    );
    expect(request.headers['Content-Type'], 'text/plain;charset=UTF-8');
    expect(request.headers['DD-API-KEY'], 'client-token');
    expect(request.headers['DD-EVP-ORIGIN'], 'flutter');
    expect(request.headers['DD-EVP-ORIGIN-VERSION'], '9.8.7');

    final exposure = jsonDecode(request.body);
    expect(exposure['service'], 'flutter-example');
    expect(exposure['rum'], {
      'application': {'id': 'rum-app-id'},
      'view': null,
    });
    expect(exposure['flag'], {'key': 'show-paywall'});
    expect(exposure['allocation'], {'key': 'allocation-a'});
    expect(exposure['variant'], {'key': 'enabled'});
    expect(exposure['subject'], {
      'id': 'user-123',
      'attributes': <String, Object?>{},
    });
  });

  test('clears the exposure cache for repeated assignment emissions', () async {
    final client = await createClient(
      httpClient: clientWithResponse(assignmentsResponse()),
    );
    await client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    await waitUntil(() => exposureRequests().length == 1);
    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    await Future<void>.delayed(Duration.zero);

    expect(exposureRequests(), hasLength(1));

    client.clearExposureCache();
    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    await waitUntil(() => exposureRequests().length == 2);

    expect(exposureRequests(), hasLength(2));
  });

  test('does not emit exposures when doLog is false', () async {
    final client = await createClient(
      httpClient: clientWithResponse(assignmentsResponse(doLog: false)),
    );
    await client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    await Future<void>.delayed(Duration.zero);

    expect(exposureRequests(), isEmpty);
  });

  test('flushes aggregated evaluation metrics with success and error payloads',
      () async {
    final client = await createClient(
      httpClient: clientWithResponse(assignmentsResponse()),
    );

    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    await client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(
        targetingKey: 'user-123',
        attributes: {'plan': 'pro'},
      ),
    );
    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    client.getBooleanValue(key: 'show-paywall', defaultValue: false);
    client.getIntegerValue(key: 'show-paywall', defaultValue: 0);
    client.getBooleanValue(key: 'missing', defaultValue: false);

    await client.flush();

    expect(evaluationRequests(), hasLength(1));
    final request = evaluationRequests().single;
    expect(
      request.url.toString(),
      'https://browser-intake-datadoghq.com/api/v2/flagevaluation?ddsource=flutter',
    );
    expect(request.headers['Content-Type'], 'application/json');
    expect(request.headers['DD-API-KEY'], 'client-token');
    expect(request.headers['DD-EVP-ORIGIN'], 'flutter');
    expect(request.headers['DD-EVP-ORIGIN-VERSION'], '9.8.7');

    final batches = evaluationRequests().map((request) {
      return jsonDecode(request.body) as Map<String, Object?>;
    }).toList();
    final evaluations = batches
        .expand((batch) {
          return batch['flagEvaluations'] as List<Object?>;
        })
        .cast<Map<String, Object?>>()
        .toList();

    final success = evaluations.singleWhere((evaluation) {
      return (evaluation['flag'] as Map<String, Object?>)['key'] ==
              'show-paywall' &&
          evaluation['error'] == null;
    });
    expect(success['evaluation_count'], 2);
    expect(success['variant'], {'key': 'enabled'});
    expect(success['allocation'], {'key': 'allocation-a'});
    expect(success['runtime_default_used'], isNull);
    expect(success['context'], {
      'evaluation': {'plan': 'pro'},
      'dd': {
        'service': 'flutter-example',
        'rum': {
          'application': {'id': 'rum-app-id'},
          'view': null,
        },
      },
    });

    final providerNotReady = evaluations.singleWhere((evaluation) {
      return ((evaluation['error'] as Map<String, Object?>?)?['message']) ==
          'PROVIDER_NOT_READY';
    });
    expect(providerNotReady['runtime_default_used'], isTrue);
    expect(providerNotReady['variant'], isNull);
    expect(providerNotReady['allocation'], isNull);
    expect(providerNotReady['context'], {
      'dd': {
        'service': 'flutter-example',
        'rum': {
          'application': {'id': 'rum-app-id'},
          'view': null,
        },
      },
    });

    final typeMismatch = evaluations.singleWhere((evaluation) {
      return ((evaluation['error'] as Map<String, Object?>?)?['message']) ==
          'TYPE_MISMATCH';
    });
    expect(typeMismatch['runtime_default_used'], isTrue);

    final flagNotFound = evaluations.singleWhere((evaluation) {
      return ((evaluation['error'] as Map<String, Object?>?)?['message']) ==
          'FLAG_NOT_FOUND';
    });
    expect(flagNotFound['runtime_default_used'], isTrue);
  });

  test('sends aggregated evaluation metrics on the configured timer', () async {
    final client = await createClient(
      httpClient: clientWithResponse(assignmentsResponse()),
      trackExposures: false,
    );
    await client.setEvaluationContext(
      const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
    );

    client.getBooleanValue(key: 'show-paywall', defaultValue: false);

    expect(evaluationRequests(), isEmpty);
    await waitUntil(() => evaluationRequests().isNotEmpty);

    final batch =
        jsonDecode(evaluationRequests().single.body) as Map<String, Object?>;
    final evaluations = batch['flagEvaluations'] as List<Object?>;
    expect(evaluations, hasLength(1));
    final evaluation = evaluations.single as Map<String, Object?>;
    expect(evaluation['flag'], {'key': 'show-paywall'});
    expect(evaluation['evaluation_count'], 1);
  });
}

class FakeRumFlagEvaluationReporter implements RumFlagEvaluationReporter {
  final calls = <RumCall>[];

  @override
  void report(String flagKey, Object value) {
    calls.add(RumCall(flagKey, value));
  }
}

class CloseTrackingClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

class RumCall {
  final String flagKey;
  final Object value;

  const RumCall(this.flagKey, this.value);

  @override
  bool operator ==(Object other) {
    return other is RumCall && other.flagKey == flagKey && other.value == value;
  }

  @override
  int get hashCode => Object.hash(flagKey, value);

  @override
  String toString() => 'RumCall($flagKey, $value)';
}
