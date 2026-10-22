// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
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

  test(
    'refresh during reconciliation does not quarantine the provider',
    () async {
      api = createIsolatedOpenFeatureAPI(
        lifecycleTimeout: const Duration(seconds: 2),
      );
      final pendingB = Completer<http.Response>();
      final subjects = <String?>[];
      final provider = DatadogOpenFeatureProvider(
        configuration: _configuration(
          MockClient((request) {
            if (request.url.path != '/precompute-assignments')
              return Future.value(http.Response('{}', 202));
            final subject =
                _subject(
                      jsonDecode(request.body) as Map<String, Object?>,
                    )['targeting_key']
                    as String?;
            subjects.add(subject);
            if (subjects.length == 2) return pendingB.future;
            return Future.value(
              http.Response(
                jsonEncode(_assignmentsResponse(booleanValue: subject == 'A')),
                200,
              ),
            );
          }),
          initializationTimeout: const Duration(seconds: 1),
        ),
      );
      await api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'A'),
      );
      await api.setProviderAndWait(provider);
      final reconciliation = api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'B'),
      );
      await _waitUntil(() => subjects.length == 2);
      final refreshing = provider.refresh();
      pendingB.complete(
        http.Response(
          jsonEncode(_assignmentsResponse(booleanValue: false)),
          200,
        ),
      );
      await Future.wait([reconciliation, refreshing]);
      expect(api.getClient().providerStatus, ProviderStatus.ready);
      expect(api.getClient().getBooleanValue('show-paywall', true), isFalse);
      expect(subjects, ['A', 'B', 'B']);
    },
  );

  test('unchanged refresh preserves exposure deduplication', () async {
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
    await api.setEvaluationContextAndWait(
      EvaluationContext(targetingKey: 'same-user'),
    );
    await api.setProviderAndWait(provider);
    expect(api.getClient().getBooleanValue('show-paywall', false), isTrue);
    await provider.refresh();
    expect(api.getClient().getBooleanValue('show-paywall', false), isTrue);
    await api.shutdown();
    final exposures = requests.where((r) => r.url.path.contains('exposure'));
    expect(exposures, hasLength(1));
  });

  test('failed sign-out requires an API retry before refresh', () async {
    var failAnonymous = true;
    final subjects = <String?>[];
    final provider = DatadogOpenFeatureProvider(
      configuration: _configuration(
        MockClient((request) async {
          if (request.url.path != '/precompute-assignments')
            return http.Response('{}', 202);
          final subject =
              _subject(
                    jsonDecode(request.body) as Map<String, Object?>,
                  )['targeting_key']
                  as String?;
          subjects.add(subject);
          if (subject == '' && failAnonymous)
            return http.Response('offline', 503);
          return http.Response(
            jsonEncode(_assignmentsResponse(booleanValue: subject == 'A')),
            200,
          );
        }),
      ),
    );
    await api.setEvaluationContextAndWait(EvaluationContext(targetingKey: 'A'));
    await api.setProviderAndWait(provider);
    await expectLater(
      api.setEvaluationContextAndWait(EvaluationContext.empty),
      throwsA(isA<OpenFeatureException>()),
    );
    failAnonymous = false;
    await expectLater(provider.refresh(), throwsStateError);
    expect(subjects, ['A', '']);
    expect(api.getClient().getBooleanValue('show-paywall', false), isFalse);
    await api.setEvaluationContextAndWait(EvaluationContext.empty);
    expect(api.getClient().providerStatus, ProviderStatus.ready);
    expect(api.getClient().getBooleanValue('show-paywall', true), isFalse);
    expect(subjects, ['A', '', '']);
  });

  test('changed serial ID still emits an exposure after refresh', () async {
    final requests = <http.Request>[];
    var serialId = 1;
    final provider = DatadogOpenFeatureProvider(
      configuration: _configuration(
        MockClient((request) async {
          requests.add(request);
          return _responseFor(request, {
            'data': {
              'attributes': {
                'flags': {
                  'show-paywall': _assignment(
                    variationValue: true,
                    serialId: serialId,
                  ),
                },
              },
            },
          });
        }),
        trackTelemetry: true,
      ),
    );
    await api.setEvaluationContextAndWait(
      EvaluationContext(targetingKey: 'same-user'),
    );
    await api.setProviderAndWait(provider);
    expect(api.getClient().getBooleanValue('show-paywall', false), isTrue);
    serialId = 2;
    await provider.refresh();
    expect(api.getClient().getBooleanValue('show-paywall', false), isTrue);
    await api.shutdown();
    expect(
      requests
          .where((r) => r.url.path.contains('exposure'))
          .expand((r) => r.body.split('\n')),
      hasLength(2),
    );
  });

  test('shutdown fences a refresh waiting for reconciliation', () async {
    final pendingB = Completer<http.Response>();
    var calls = 0;
    final provider = DatadogOpenFeatureProvider(
      configuration: _configuration(
        MockClient((request) async {
          if (++calls == 2) return pendingB.future;
          return _responseFor(request, _assignmentsResponse());
        }),
      ),
    );
    await provider.initialize(EvaluationContext(targetingKey: 'A'));
    final reconciling = provider.onContextChanged(
      EvaluationContext(targetingKey: 'A'),
      EvaluationContext(targetingKey: 'B'),
    );
    await _waitUntil(() => calls == 2);
    final refreshing = provider.refresh();
    final refreshExpectation = expectLater(refreshing, throwsStateError);
    await provider.shutdown();
    pendingB.complete(http.Response(jsonEncode(_assignmentsResponse()), 200));
    await Future.wait([reconciling, refreshExpectation]);
    expect(calls, 2);
    expect(
      provider
          .resolveBooleanValue('show-paywall', false, EvaluationContext.empty)
          .errorCode,
      ErrorCode.providerNotReady,
    );
  });

  for (final refreshCount in [1, 2]) {
    test(
      'in-flight exposure retries after $refreshCount runtime replacements',
      () async {
        await runZoned(
          () async {
            final firstUpload = Completer<http.Response>();
            final started = Completer<void>();
            var attempts = 0;
            var successes = 0;
            final provider = DatadogOpenFeatureProvider(
              configuration: _configuration(
                MockClient((request) async {
                  if (request.url.path.contains('exposure')) {
                    attempts++;
                    if (attempts == 1) {
                      started.complete();
                      return firstUpload.future;
                    }
                    successes++;
                    return http.Response('{}', 202);
                  }
                  return _responseFor(request, _assignmentsResponse());
                }),
                trackTelemetry: true,
              ),
            );
            await api.setEvaluationContextAndWait(
              EvaluationContext(targetingKey: 'subject'),
            );
            await api.setProviderAndWait(provider);
            expect(
              api.getClient().getBooleanValue('show-paywall', false),
              isTrue,
            );
            await started.future.timeout(const Duration(seconds: 2));
            for (var i = 0; i < refreshCount; i++) {
              await provider.refresh();
            }
            firstUpload.complete(http.Response('offline', 503));
            expect(
              api.getClient().getBooleanValue('show-paywall', false),
              isTrue,
            );
            await api.shutdown();
            expect(attempts, 2);
            expect(successes, 1);
          },
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, callback) =>
                parent.createTimer(
                  zone,
                  duration == const Duration(seconds: 10)
                      ? Duration.zero
                      : duration,
                  callback,
                ),
          ),
        );
      },
    );
  }

  test('evaluates obfuscated assignments and restores them from cache', () async {
    final store = _MemoryStore();
    var offline = false;
    final configuration = _configuration(
      MockClient((request) async {
        if (offline) return http.Response('offline', 503);
        return _responseFor(request, {
          'data': {
            'attributes': {
              'obfuscated': true,
              'obfuscation': {
                'scheme': 'flag-key-sha256-v1',
                'salt': '000102030405060708090a0b0c0d0e0f',
              },
              'flags': {
                // The upstream obfuscation fixture encodes the original key 'flag'.
                '9817872c144b018abd77e3915bd77e2c27f4f534dccff8ffaca27361e3a5e1ee':
                    _assignment(variationValue: true, serialId: 42),
              },
            },
          },
        });
      }),
      store: store,
    );
    await api.setEvaluationContextAndWait(
      EvaluationContext(targetingKey: 'subject'),
    );
    await api.setProviderAndWait(
      DatadogOpenFeatureProvider(configuration: configuration),
    );
    final details = api.getClient().getBooleanDetails('flag', false);
    expect(details.value, isTrue);
    expect(details.reason, 'TARGETING_MATCH');
    expect(details.flagMetadata, {
      DatadogOpenFeatureProvider.allocationKeyMetadata: 'allocation-a',
      DatadogOpenFeatureProvider.serialIdMetadata: 42,
    });
    expect(api.getClient().providerStatus, ProviderStatus.ready);

    offline = true;
    await api.setProviderAndWait(
      DatadogOpenFeatureProvider(configuration: configuration),
    );
    final cached = api.getClient().getBooleanDetails('flag', false);
    expect(cached.value, isTrue);
    expect(cached.reason, 'CACHED');
    expect(cached.flagMetadata, details.flagMetadata);
    expect(api.getClient().providerStatus, ProviderStatus.stale);
  });

  test('shutdown releases timers and ignores a pending refresh', () async {
    final timers = <Timer>[];
    await runZoned(
      () async {
        final response = Completer<http.Response>();
        var assignmentRequests = 0;
        final provider = DatadogOpenFeatureProvider(
          configuration: _configuration(
            MockClient((request) {
              if (request.url.path != '/precompute-assignments') {
                return Future.value(http.Response('{}', 202));
              }
              if (++assignmentRequests == 1) {
                return Future.value(
                  http.Response(jsonEncode(_assignmentsResponse()), 200),
                );
              }
              return response.future;
            }),
            trackTelemetry: true,
          ),
        );
        await provider.initialize(EvaluationContext(targetingKey: 'subject'));
        expect(timers.any((timer) => timer.isActive), isTrue);
        final refreshing = provider.refresh();
        await _waitUntil(() => assignmentRequests == 2);
        await provider.shutdown();
        await provider.shutdown();
        expect(timers.every((timer) => !timer.isActive), isTrue);
        final details = provider.resolveBooleanValue(
          'show-paywall',
          false,
          EvaluationContext.empty,
        );
        expect(
          details.errorMessage,
          'The Datadog provider has not loaded assignments.',
        );
        response.complete(
          http.Response(jsonEncode(_assignmentsResponse()), 200),
        );
        await refreshing;
        expect(timers.every((timer) => !timer.isActive), isTrue);
      },
      zoneSpecification: ZoneSpecification(
        createPeriodicTimer: (self, parent, zone, duration, callback) {
          final timer = parent.createPeriodicTimer(zone, duration, callback);
          timers.add(timer);
          return timer;
        },
      ),
    );
  });

  test(
    'cached reconciliation stays stale after OpenFeature commits the context',
    () async {
      final store = _MemoryStore();
      var fail = false;
      final provider = DatadogOpenFeatureProvider(
        configuration: _configuration(
          MockClient(
            (_) async => fail
                ? http.Response('offline', 503)
                : http.Response(jsonEncode(_assignmentsResponse()), 200),
          ),
          store: store,
        ),
      );
      await api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'first'),
      );
      await api.setProviderAndWait(provider);
      await store.write(
        'default',
        FlagsData.fromJson({
          'flags': {'show-paywall': _assignment(variationValue: false)},
          'context': const FlagsEvaluationContext(
            targetingKey: 'second',
          ).toJson(),
          'date': DateTime.utc(2026).toIso8601String(),
        }),
      );
      fail = true;
      await api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'second'),
      );
      expect(api.getClient().providerStatus, ProviderStatus.stale);
      expect(api.getClient().getBooleanValue('show-paywall', true), isFalse);
    },
  );

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

  test('recovers when initial assignments arrive after the deadline', () async {
    final assignmentResponse = Completer<http.Response>();
    var assignmentRequestCount = 0;
    final providerEvents = <ProviderEventType>[];
    final provider = DatadogOpenFeatureProvider(
      configuration: _configuration(
        MockClient((request) {
          if (request.url.path != '/precompute-assignments') {
            return Future.value(http.Response('{}', 202));
          }
          assignmentRequestCount += 1;
          return assignmentResponse.future;
        }),
        initializationTimeout: const Duration(milliseconds: 100),
      ),
    );
    provider.events.listen((event) => providerEvents.add(event.type));

    await api.setEvaluationContextAndWait(
      EvaluationContext(targetingKey: 'user-123'),
    );
    final registration = api.setProviderAndWait(provider);
    await _waitUntil(() => assignmentRequestCount == 1);
    await expectLater(registration, throwsA(isA<OpenFeatureException>()));

    final client = api.getClient();
    expect(client.providerStatus, ProviderStatus.error);
    expect(client.getBooleanValue('show-paywall', false), isFalse);

    assignmentResponse.complete(
      http.Response(jsonEncode(_assignmentsResponse()), 200),
    );
    await _waitUntil(() => client.providerStatus == ProviderStatus.ready);

    expect(client.getBooleanValue('show-paywall', false), isTrue);
    expect(providerEvents, [ProviderEventType.error, ProviderEventType.ready]);
  });

  test(
    'does not apply late assignments from a failed reconciliation',
    () async {
      final nextContextResponse = Completer<http.Response>();
      var assignmentRequestCount = 0;
      final provider = DatadogOpenFeatureProvider(
        configuration: _configuration(
          MockClient((request) {
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
          initializationTimeout: const Duration(milliseconds: 100),
        ),
      );

      await api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'user-first'),
      );
      await api.setProviderAndWait(provider);
      final client = api.getClient();

      final reconciliation = api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'user-second'),
      );
      await _waitUntil(() => assignmentRequestCount == 2);
      await expectLater(reconciliation, throwsA(isA<OpenFeatureException>()));
      expect(client.providerStatus, ProviderStatus.error);
      expect(client.getBooleanValue('show-paywall', false), isTrue);

      nextContextResponse.complete(
        http.Response(
          jsonEncode(_assignmentsResponse(booleanValue: false)),
          200,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(client.providerStatus, ProviderStatus.error);
      expect(client.getBooleanValue('show-paywall', false), isTrue);
    },
  );

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

  test('reports structure mismatches without logging an exposure', () async {
    final requests = <http.Request>[];
    final provider = DatadogOpenFeatureProvider(
      configuration: _configuration(
        MockClient((request) async {
          requests.add(request);
          return _responseFor(
            request,
            _assignmentsResponse(configValue: const ['not-a-structure']),
          );
        }),
        trackTelemetry: true,
      ),
    );

    await api.setEvaluationContextAndWait(
      EvaluationContext(targetingKey: 'user-123'),
    );
    await api.setProviderAndWait(provider);

    final details = api.getClient().getStructureDetails('config', const {});
    expect(details.value, isEmpty);
    expect(details.errorCode, ErrorCode.typeMismatch);

    await api.shutdown();
    expect(
      requests.where((request) => request.url.path == '/api/v2/exposures'),
      isEmpty,
    );
  });

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

  test('reports missing Datadog configuration during initialization', () async {
    final provider = DatadogOpenFeatureProvider(
      configuration: const DatadogFlagsConfiguration(),
    );

    await expectLater(
      api.setProviderAndWait(provider),
      throwsA(isA<OpenFeatureException>()),
    );

    expect(api.getClient().providerStatus, ProviderStatus.error);
  });
  test(
    'published assignments survive a store write that never finishes',
    () async {
      final store = _BlockedWriteStore();
      final provider = DatadogOpenFeatureProvider(
        configuration: _configuration(
          MockClient(
            (request) async => _responseFor(request, _assignmentsResponse()),
          ),
          store: store,
          initializationTimeout: const Duration(milliseconds: 100),
        ),
      );
      await api.setProviderAndWait(provider);
      expect(api.getClient().providerStatus, ProviderStatus.ready);
      expect(api.getClient().getBooleanValue('show-paywall', false), isTrue);
      expect(store.writes, 1);
      await api.shutdown();
      store.release.complete();
    },
  );

  test(
    'cached timeout reports stale until the pending request succeeds',
    () async {
      final store = _MemoryStore();
      await store.write(
        'default',
        FlagsData.fromJson({
          'flags': {'show-paywall': _assignment(variationValue: true)},
          'context': const FlagsEvaluationContext(
            targetingKey: 'cached',
          ).toJson(),
          'date': DateTime.utc(2026).toIso8601String(),
        }),
      );
      final response = Completer<http.Response>();
      final events = <ProviderEvent>[];
      final provider = DatadogOpenFeatureProvider(
        configuration: _configuration(
          MockClient((_) => response.future),
          store: store,
          initializationTimeout: const Duration(milliseconds: 100),
        ),
      );
      provider.events.listen(events.add);
      await api.setEvaluationContextAndWait(
        EvaluationContext(targetingKey: 'cached'),
      );
      await api.setProviderAndWait(provider);
      expect(api.getClient().providerStatus, ProviderStatus.stale);
      expect(api.getClient().getBooleanValue('show-paywall', false), isTrue);
      expect(
        api.getClient().getBooleanDetails('show-paywall', false).reason,
        'CACHED',
      );
      expect(events.last.message, isNot(contains('failed')));
      response.complete(
        http.Response(
          jsonEncode(_assignmentsResponse(booleanValue: false)),
          200,
        ),
      );
      await _waitUntil(
        () => api.getClient().providerStatus == ProviderStatus.ready,
      );
      expect(api.getClient().getBooleanValue('show-paywall', true), isFalse);
      expect(
        api.getClient().getBooleanDetails('show-paywall', true).reason,
        'TARGETING_MATCH',
      );
    },
  );

  for (final timeout in [
    null,
    Duration.zero,
    const Duration(seconds: -1),
    const Duration(seconds: 21),
  ]) {
    test(
      'rejects unsafe lifecycle budget $timeout before starting HTTP',
      () async {
        var requests = 0;
        final provider = DatadogOpenFeatureProvider(
          configuration: _configuration(
            MockClient((_) async {
              requests++;
              return http.Response('', 500);
            }),
            initializationTimeout: timeout,
          ),
        );
        await expectLater(
          api.setProviderAndWait(provider),
          throwsA(isA<OpenFeatureException>()),
        );
        expect(requests, 0);
        expect(api.getClient().providerStatus, ProviderStatus.error);
      },
    );
  }

  test('direct context races cannot publish a superseded response', () async {
    final first = Completer<http.Response>();
    var requests = 0;
    final events = <ProviderEventType>[];
    final provider = DatadogOpenFeatureProvider(
      configuration: _configuration(
        MockClient((request) {
          requests++;
          if (requests == 1) return first.future;
          return Future.value(
            http.Response(
              jsonEncode(_assignmentsResponse(booleanValue: false)),
              200,
            ),
          );
        }),
      ),
    );
    provider.events.listen((event) => events.add(event.type));
    addTearDown(provider.shutdown);
    final old = provider.initialize(EvaluationContext(targetingKey: 'old'));
    await _waitUntil(() => requests == 1);
    await provider.onContextChanged(
      EvaluationContext(targetingKey: 'old'),
      EvaluationContext(targetingKey: 'new'),
    );
    first.complete(http.Response(jsonEncode(_assignmentsResponse()), 200));
    await old;
    expect(events, [
      ProviderEventType.reconciling,
      ProviderEventType.contextChanged,
    ]);
    expect(
      provider
          .resolveBooleanValue('show-paywall', true, EvaluationContext.empty)
          .value,
      isFalse,
    );
  });

  test('sign-out retires private flags when anonymous loading fails', () async {
    var requests = 0;
    final provider = DatadogOpenFeatureProvider(
      configuration: _configuration(
        MockClient(
          (_) async => ++requests == 1
              ? http.Response(jsonEncode(_assignmentsResponse()), 200)
              : http.Response('offline', 503),
        ),
      ),
    );
    await api.setEvaluationContextAndWait(
      EvaluationContext(targetingKey: 'private-user'),
    );
    await api.setProviderAndWait(provider);
    await expectLater(
      api.setEvaluationContextAndWait(EvaluationContext.empty),
      throwsA(isA<OpenFeatureException>()),
    );
    expect(api.getClient().getBooleanValue('show-paywall', false), isFalse);
  });

  for (var offset = 0; offset < 7; offset++) {
    test(
      'shutdown fences direct initialization at microtask $offset',
      () async {
        final response = Completer<http.Response>();
        final events = <ProviderEvent>[];
        final store = _MemoryStore();
        final provider = DatadogOpenFeatureProvider(
          configuration: _configuration(
            MockClient((_) => response.future),
            store: store,
          ),
        );
        provider.events.listen(events.add);
        final initializing = provider.initialize(
          EvaluationContext(targetingKey: 'retired'),
        );
        for (var i = 0; i < offset; i++) {
          await Future<void>.value();
        }
        await provider.shutdown();
        await provider.shutdown();
        final count = events.length;
        response.complete(
          http.Response(jsonEncode(_assignmentsResponse()), 200),
        );
        await initializing;
        expect(events, hasLength(count));
        expect(await store.read('default'), isNull);
        expect(
          provider
              .resolveBooleanValue(
                'show-paywall',
                false,
                EvaluationContext.empty,
              )
              .errorCode,
          ErrorCode.providerNotReady,
        );
      },
    );
  }
}

DatadogFlagsConfiguration _configuration(
  http.Client client, {
  DatadogFlagsStore? store,
  bool trackTelemetry = false,
  Duration? initializationTimeout =
      DatadogFlagsConfiguration.defaultInitializationTimeout,
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
    initializationTimeout: initializationTimeout,
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

Map<String, Object?> _assignmentsResponse({
  bool booleanValue = true,
  Object configValue = const {
    'enabled': true,
    'labels': ['a', 'b'],
  },
}) {
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
            variationValue: configValue,
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
  for (var attempt = 0; attempt < 2000; attempt += 1) {
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

final class _BlockedWriteStore implements DatadogFlagsStore {
  final release = Completer<void>();
  int writes = 0;
  @override
  Future<FlagsData?> read(String clientName) async => null;
  @override
  Future<void> write(String clientName, FlagsData data) {
    writes++;
    return release.future;
  }

  @override
  Future<void> delete(String clientName) async {}
}
