// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';
import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/flags_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk_experimental.dart'
    show createIsolatedOpenFeatureAPI;
import 'package:test/test.dart';

void main() {
  for (final useProvider in [false, true]) {
    for (final strict in [false, true, 'true']) {
      for (final sameKey in [false, true]) {
        for (final withStore in [false, true]) {
          for (final status in [200, 401, 503]) {
            test(
              '${useProvider ? 'OpenFeature' : 'Dart'} strict=$strict(${strict.runtimeType}) sameKey=$sameKey store=$withStore status=$status',
              () async {
                final requests = <http.Request>[];
                final response = Completer<http.Response>();
                final started = Completer<void>();
                var count = 0;
                final config = DatadogFlagsConfiguration(
                  datadogConfig: const DatadogFlagsConfig(
                    clientToken: 'test',
                    env: 'test',
                    site: DatadogFlagsSite.us1,
                  ),
                  store: withStore ? InMemoryDatadogFlagsStore() : null,
                  httpClient: MockClient((request) {
                    requests.add(request);
                    if (request.url.path != '/precompute-assignments') {
                      return Future.value(http.Response('{}', 202));
                    }
                    if (++count == 1) return Future.value(_response(true));
                    if (count == 2) {
                      started.complete();
                      return response.future;
                    }
                    return Future.value(_response(false));
                  }),
                );
                final api = createIsolatedOpenFeatureAPI();
                final owner = DatadogFlags();
                addTearDown(api.shutdown);
                addTearDown(owner.disable);
                late Future<void> Function(FlagsEvaluationContext) change;
                late bool Function(bool) read;
                final initial = FlagsEvaluationContext(
                  targetingKey: 'A',
                  attributes: {
                    'plan': 'free',
                    'dd_strict_evaluation_context_switching': strict,
                  },
                );
                if (useProvider) {
                  change = (context) => api.setEvaluationContextAndWait(
                    EvaluationContext(
                      targetingKey: context.targetingKey,
                      attributes: context.attributes,
                    ),
                  );
                  await change(initial);
                  await api.setProviderAndWait(
                    DatadogProvider.fromConfiguration(config),
                  );
                  read = (fallback) =>
                      api.getClient().getBooleanValue('flag', fallback);
                } else {
                  await owner.enable(configuration: config);
                  final client = owner.sharedClient();
                  change = client.initialize;
                  read = (fallback) => client
                      .getBooleanDetails(key: 'flag', defaultValue: fallback)
                      .value;
                  await change(initial);
                }
                expect(read(false), isTrue);
                final next = FlagsEvaluationContext(
                  targetingKey: sameKey ? 'A' : 'B',
                  attributes: {
                    'plan': 'pro',
                    'dd_strict_evaluation_context_switching': strict,
                  },
                );
                final operation = change(next);
                final completion = useProvider && status != 200
                    ? expectLater(
                        operation,
                        throwsA(isA<OpenFeatureException>()),
                      )
                    : operation;
                await started.future;
                final retains = sameKey && strict != true;
                expect(read(false), retains);
                response.complete(
                  status == 200
                      ? _response(false)
                      : http.Response('unavailable', status),
                );
                await completion;
                expect(read(status == 200), status == 200 ? false : retains);
                if (status != 200) {
                  final retry = change(next);
                  expect(read(false), retains);
                  await retry;
                  expect(read(true), isFalse);
                }
                await api.shutdown();
                await owner.disable();
                for (final request in requests) {
                  expect(
                    request.body,
                    isNot(contains('dd_strict_evaluation_context_switching')),
                  );
                }
                final exposures = requests.where(
                  (request) => request.url.path == '/api/v2/exposures',
                );
                expect(exposures, isNotEmpty);
                expect(exposures.first.body, contains('free'));
                if (!sameKey) {
                  expect(exposures.last.body, contains('B'));
                }
              },
            );
          }
        }
      }
    }
  }
  for (final withStore in [false, true]) {
    test(
      'strict refresh withholds values through failure and retry, store=$withStore',
      () async {
        final api = createIsolatedOpenFeatureAPI();
        addTearDown(api.shutdown);
        var count = 0;
        final first = Completer<http.Response>();
        final retry = Completer<http.Response>();
        final firstStarted = Completer<void>();
        final retryStarted = Completer<void>();
        final events = <ProviderEventType>[];
        final provider = DatadogProvider.fromConfiguration(
          DatadogFlagsConfiguration(
            datadogConfig: const DatadogFlagsConfig(
              clientToken: 'test',
              env: 'test',
              site: DatadogFlagsSite.us1,
            ),
            store: withStore ? InMemoryDatadogFlagsStore() : null,
            httpClient: MockClient((request) {
              if (request.url.path != '/precompute-assignments') {
                return Future.value(http.Response('{}', 202));
              }
              switch (++count) {
                case 1:
                  return Future.value(_response(true));
                case 2:
                  firstStarted.complete();
                  return first.future;
                default:
                  retryStarted.complete();
                  return retry.future;
              }
            }),
          ),
        );
        provider.events.listen((event) {
          events.add(event.type);
          if (event.type == ProviderEventType.error) {
            expect(api.getClient().getBooleanValue('flag', false), isFalse);
          }
        });
        await api.setEvaluationContextAndWait(
          EvaluationContext(
            targetingKey: 'A',
            attributes: {'dd_strict_evaluation_context_switching': true},
          ),
        );
        await api.setProviderAndWait(provider);
        final refreshing = provider.refresh();
        await firstStarted.future;
        expect(api.getClient().getBooleanValue('flag', false), isTrue);
        first.complete(http.Response('unavailable', 503));
        await refreshing;
        expect(api.getClient().getBooleanValue('flag', false), isFalse);
        expect(api.getClient().providerStatus, ProviderStatus.error);
        final retrying = provider.refresh();
        await retryStarted.future;
        expect(api.getClient().getBooleanValue('flag', false), isFalse);
        retry.complete(_response(true));
        await retrying;
        expect(api.getClient().getBooleanValue('flag', false), isTrue);
        expect(events, [
          ProviderEventType.ready,
          ProviderEventType.error,
          ProviderEventType.ready,
          ProviderEventType.configurationChanged,
        ]);
      },
    );
  }

  for (final strict in [false, true]) {
    test(
      'null and empty keys share assignments when enabling strict=$strict',
      () async {
        final api = createIsolatedOpenFeatureAPI();
        addTearDown(api.shutdown);
        var count = 0;
        final response = Completer<http.Response>();
        final started = Completer<void>();
        final provider = DatadogProvider.fromConfiguration(
          DatadogFlagsConfiguration(
            datadogConfig: const DatadogFlagsConfig(
              clientToken: 'test',
              env: 'test',
              site: DatadogFlagsSite.us1,
            ),
            httpClient: MockClient((request) {
              if (request.url.path != '/precompute-assignments') {
                return Future.value(http.Response('{}', 202));
              }
              if (++count == 1) return Future.value(_response(true));
              started.complete();
              return response.future;
            }),
          ),
        );
        await api.setProviderAndWait(provider);
        final changing = expectLater(
          api.setEvaluationContextAndWait(
            EvaluationContext(
              targetingKey: '',
              attributes: {'dd_strict_evaluation_context_switching': strict},
            ),
          ),
          throwsA(isA<OpenFeatureException>()),
        );
        await started.future;
        expect(api.getClient().getBooleanValue('flag', false), isTrue);
        response.complete(http.Response('offline', 503));
        await changing;
        expect(api.getClient().getBooleanValue('flag', false), !strict);
      },
    );
  }
  test(
    'strict cache cannot restore values after failed refresh or a late retry',
    () async {
      final api = createIsolatedOpenFeatureAPI();
      addTearDown(api.shutdown);
      final store = InMemoryDatadogFlagsStore();
      var requests = 0;
      final late = Completer<http.Response>();
      final provider = DatadogProvider.fromConfiguration(
        DatadogFlagsConfiguration(
          datadogConfig: const DatadogFlagsConfig(
            clientToken: 'test',
            env: 'test',
            site: DatadogFlagsSite.us1,
          ),
          initializationTimeout: const Duration(milliseconds: 30),
          store: store,
          httpClient: MockClient((request) {
            if (request.url.path != '/precompute-assignments') {
              return Future.value(http.Response('{}', 202));
            }
            return switch (++requests) {
              1 => Future.value(_response(true)),
              2 => Future.value(http.Response('offline', 503)),
              3 => late.future,
              _ => Future.value(_response(true)),
            };
          }),
        ),
      );
      final context = EvaluationContext(
        targetingKey: 'A',
        attributes: {'dd_strict_evaluation_context_switching': true},
      );
      await api.setEvaluationContextAndWait(context);
      await api.setProviderAndWait(provider);
      expect(api.getClient().getBooleanValue('flag', false), isTrue);
      await provider.refresh();
      expect(api.getClient().getBooleanValue('flag', false), isFalse);
      await expectLater(
        api.setEvaluationContextAndWait(context),
        throwsA(isA<OpenFeatureException>()),
      );
      expect(api.getClient().getBooleanValue('flag', false), isFalse);
      late.complete(_response(true));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(api.getClient().getBooleanValue('flag', false), isFalse);
      await expectLater(provider.refresh(), throwsStateError);
      await api.setEvaluationContextAndWait(context);
      expect(api.getClient().getBooleanValue('flag', false), isTrue);
    },
  );
}

http.Response _response(bool value) => http.Response(
  jsonEncode({
    'data': {
      'attributes': {
        'flags': {
          'flag': {
            'allocationKey': 'allocation',
            'variationKey': value ? 'on' : 'off',
            'variationType': 'boolean',
            'variationValue': value,
            'reason': 'TARGETING_MATCH',
            'doLog': true,
          },
        },
      },
    },
  }),
  200,
);
