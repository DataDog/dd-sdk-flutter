// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_openfeature_provider/datadog_openfeature_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk_experimental.dart'
    show createIsolatedOpenFeatureAPI;
import 'package:test/test.dart';

void main() {
  late OpenFeatureAPI api;

  setUp(() {
    api = createIsolatedOpenFeatureAPI();
  });

  tearDown(() => api.shutdown());

  test('maps typed details, errors, and Datadog metadata', () async {
    final requests = <http.Request>[];
    final provider = DatadogOpenFeatureProvider(
      configuration: _configuration(
        MockClient((request) async {
          requests.add(request);
          return _responseFor(request, _assignmentsResponse());
        }),
      ),
    );

    await api.setEvaluationContextAndWait(
      EvaluationContext(
        targetingKey: 'user-123',
        attributes: const {'plan': 'pro'},
      ),
    );
    await api.setProviderAndWait(provider);
    final client = api.getClient();

    final boolean = client.getBooleanDetails('show-paywall', false);
    expect(boolean.value, isTrue);
    expect(boolean.variant, 'enabled');
    expect(boolean.reason, 'TARGETING_MATCH');
    expect(boolean.flagMetadata, {
      DatadogOpenFeatureProvider.allocationKeyMetadata: 'allocation-a',
      DatadogOpenFeatureProvider.serialIdMetadata: 42,
    });
    expect(client.getStringValue('theme', 'light'), 'dark');
    expect(client.getIntegerValue('max-items', 1), 3);
    expect(client.getDoubleValue('ratio', 1), 0.5);

    final structure = client.getStructureDetails('config', const {});
    expect(structure.value, {
      'enabled': true,
      'labels': ['a', 'b'],
    });
    expect(() => structure.value['changed'] = true, throwsUnsupportedError);
    expect(
      () => (structure.value['labels']! as List<Object?>).add('c'),
      throwsUnsupportedError,
    );

    final missing = client.getBooleanDetails('missing', false);
    expect(missing.value, isFalse);
    expect(missing.errorCode, ErrorCode.flagNotFound);
    expect(missing.reason, 'ERROR');

    final mismatch = client.getIntegerDetails('show-paywall', 7);
    expect(mismatch.value, 7);
    expect(mismatch.errorCode, ErrorCode.typeMismatch);
    expect(mismatch.reason, 'ERROR');

    final precompute = requests.singleWhere(
      (request) => request.url.path == '/precompute-assignments',
    );
    final requestBody = jsonDecode(precompute.body) as Map<String, Object?>;
    expect(_subject(requestBody), containsPair('targeting_key', 'user-123'));
  });

  test(
    'keeps the previous identity active until reconciliation succeeds',
    () async {
      final requests = <http.Request>[];
      final nextContextResponse = Completer<http.Response>();
      var assignmentRequestCount = 0;
      final providerEvents = <ProviderEventType>[];
      final provider = DatadogOpenFeatureProvider(
        configuration: _configuration(
          MockClient((request) {
            requests.add(request);
            if (request.url.path != '/precompute-assignments') {
              return Future.value(http.Response('{}', 202));
            }
            assignmentRequestCount += 1;
            if (assignmentRequestCount == 1) {
              return Future.value(
                http.Response(jsonEncode(_assignmentsResponse()), 200),
              );
            }
            return nextContextResponse.future;
          }),
        ),
      );
      provider.events.listen((event) => providerEvents.add(event.type));

      await api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'user-first'),
      );
      await api.setProviderAndWait(provider);
      final client = api.getClient();
      expect(client.getBooleanValue('show-paywall', false), isTrue);

      final reconcile = api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'user-second'),
      );
      await _waitUntil(() => assignmentRequestCount == 2);

      expect(client.providerStatus, ProviderStatus.reconciling);
      expect(client.getBooleanValue('show-paywall', false), isTrue);

      nextContextResponse.complete(
        http.Response(
          jsonEncode(_assignmentsResponse(booleanValue: false)),
          200,
        ),
      );
      await reconcile;

      expect(client.providerStatus, ProviderStatus.ready);
      expect(client.getBooleanValue('show-paywall', true), isFalse);
      expect(providerEvents, [
        ProviderEventType.ready,
        ProviderEventType.reconciling,
        ProviderEventType.contextChanged,
      ]);

      final subjects = requests
          .where((request) => request.url.path == '/precompute-assignments')
          .map(
            (request) => _subject(
              jsonDecode(request.body) as Map<String, Object?>,
            )['targeting_key'],
          )
          .toList();
      expect(subjects, ['user-first', 'user-second']);
    },
  );

  test('failed reconciliation retains the previous assignments', () async {
    var assignmentRequestCount = 0;
    final provider = DatadogOpenFeatureProvider(
      configuration: _configuration(
        MockClient((request) async {
          if (request.url.path != '/precompute-assignments') {
            return http.Response('{}', 202);
          }
          assignmentRequestCount += 1;
          if (assignmentRequestCount == 1) {
            return http.Response(jsonEncode(_assignmentsResponse()), 200);
          }
          return http.Response('unavailable', 503);
        }),
      ),
    );

    await api.setEvaluationContextAndWait(
      EvaluationContext(targetingKey: 'user-first'),
    );
    await api.setProviderAndWait(provider);
    final client = api.getClient();

    await expectLater(
      api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'user-second'),
      ),
      throwsA(isA<OpenFeatureException>()),
    );

    expect(client.providerStatus, ProviderStatus.error);
    expect(client.getBooleanValue('show-paywall', false), isTrue);
  });

  test('uses matching stored assignments with stale provider status', () async {
    final store = _MemoryStore();
    await store.write(
      DatadogFlags.defaultClientName,
      FlagsData.fromJson({
        'flags': {
          'show-paywall': _assignment(variationValue: true, serialId: 7),
        },
        'context': const FlagsEvaluationContext(
          targetingKey: 'cached-user',
        ).toJson(),
        'date': DateTime.utc(2026, 8, 26).toIso8601String(),
      }),
    );
    final providerEvents = <ProviderEventType>[];
    final provider = DatadogOpenFeatureProvider(
      configuration: _configuration(
        MockClient((request) async => http.Response('unavailable', 503)),
        store: store,
      ),
    );
    provider.events.listen((event) => providerEvents.add(event.type));

    await api.setEvaluationContextAndWait(
      EvaluationContext(targetingKey: 'cached-user'),
    );
    await api.setProviderAndWait(provider);

    final client = api.getClient();
    expect(client.providerStatus, ProviderStatus.stale);
    expect(client.getBooleanValue('show-paywall', false), isTrue);
    expect(providerEvents, [ProviderEventType.ready, ProviderEventType.stale]);
  });

  test(
    'preserves Datadog evaluation telemetry without claiming tracking',
    () async {
      final requests = <http.Request>[];
      final provider = DatadogOpenFeatureProvider(
        configuration: _configuration(
          MockClient((request) async {
            requests.add(request);
            return _responseFor(request, _assignmentsResponse());
          }),
          trackTelemetry: true,
        ),
      );

      expect(provider, isNot(isA<TrackingProvider>()));
      await api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'user-123'),
      );
      await api.setProviderAndWait(provider);
      api.getClient().getBooleanValue('show-paywall', false);
      api.getClient().track('checkout');
      await api.shutdown();

      expect(
        requests.where((request) => request.url.path == '/api/v2/exposures'),
        hasLength(1),
      );
      expect(
        requests.where(
          (request) => request.url.path == '/api/v2/flagevaluation',
        ),
        hasLength(1),
      );
    },
  );

  test('returns provider-not-ready defaults before initialization', () {
    final provider = DatadogOpenFeatureProvider(
      configuration: _configuration(
        MockClient((_) async => http.Response('', 500)),
      ),
    );

    final details = provider.resolveBooleanValue(
      'flag',
      false,
      EvaluationContext.empty,
    );

    expect(details.value, isFalse);
    expect(details.errorCode, ErrorCode.providerNotReady);
    expect(details.reason, 'ERROR');
  });
}

DatadogFlagsConfiguration _configuration(
  http.Client client, {
  DatadogFlagsStore? store,
  bool trackTelemetry = false,
}) {
  return DatadogFlagsConfiguration(
    datadogConfig: const DatadogFlagsConfig(
      clientToken: 'client-token',
      env: 'test',
      site: DatadogFlagsSite.us1,
      applicationId: 'application-id',
      service: 'test-service',
      version: '1.0.0',
    ),
    httpClient: client,
    store: store,
    trackExposures: trackTelemetry,
    trackEvaluations: trackTelemetry,
  );
}

http.Response _responseFor(
  http.Request request,
  Map<String, Object?> assignments,
) {
  if (request.url.path == '/precompute-assignments') {
    return http.Response(jsonEncode(assignments), 200);
  }
  return http.Response('{}', 202);
}

Map<String, Object?> _assignmentsResponse({bool booleanValue = true}) {
  return {
    'data': {
      'attributes': {
        'flags': {
          'show-paywall': _assignment(
            variationValue: booleanValue,
            serialId: 42,
          ),
          'theme': _assignment(
            allocationKey: 'allocation-b',
            variationKey: 'dark',
            variationType: 'string',
            variationValue: 'dark',
          ),
          'max-items': _assignment(
            allocationKey: 'allocation-c',
            variationKey: 'three',
            variationType: 'integer',
            variationValue: 3,
          ),
          'ratio': _assignment(
            allocationKey: 'allocation-d',
            variationKey: 'half',
            variationType: 'float',
            variationValue: 0.5,
          ),
          'config': _assignment(
            allocationKey: 'allocation-e',
            variationKey: 'object',
            variationType: 'object',
            variationValue: {
              'enabled': true,
              'labels': ['a', 'b'],
            },
          ),
        },
      },
    },
  };
}

Map<String, Object?> _assignment({
  String allocationKey = 'allocation-a',
  String variationKey = 'enabled',
  String variationType = 'boolean',
  required Object variationValue,
  int? serialId,
}) {
  return {
    'allocationKey': allocationKey,
    'variationKey': variationKey,
    'variationType': variationType,
    'variationValue': variationValue,
    'reason': 'TARGETING_MATCH',
    'doLog': true,
    'serialId': ?serialId,
  };
}

Map<String, Object?> _subject(Map<String, Object?> request) {
  final data = request['data']! as Map<String, Object?>;
  final attributes = data['attributes']! as Map<String, Object?>;
  return attributes['subject']! as Map<String, Object?>;
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Condition was not met before timeout.');
}

final class _MemoryStore implements DatadogFlagsStore {
  final Map<String, FlagsData> _values = {};

  @override
  Future<void> delete(String clientName) async {
    _values.remove(clientName);
  }

  @override
  Future<FlagsData?> read(String clientName) async => _values[clientName];

  @override
  Future<void> write(String clientName, FlagsData data) async {
    _values[clientName] = data;
  }
}
