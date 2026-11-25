// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/intake_platform.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk_experimental.dart'
    show createIsolatedOpenFeatureAPI;
import 'package:test/test.dart';

const _peekDomain = 'peek';

void main() {
  late OpenFeatureAPI api;
  late List<http.Request> requests;
  late List<ExposureEvaluation> hookEvaluations;

  const datadogConfig = DatadogFlagsConfig(
    clientToken: 'client-token',
    env: 'test',
    site: DatadogFlagsSite.us1,
  );

  http.Client httpClient() => MockClient((request) async {
    requests.add(request);
    if (request.url.path == '/precompute-assignments') {
      return http.Response(
        jsonEncode({
          'data': {
            'attributes': {
              'flags': {
                'flag': {
                  'allocationKey': 'allocation-a',
                  'variationKey': 'on',
                  'variationType': 'boolean',
                  'variationValue': true,
                  'reason': 'TARGETING_MATCH',
                  'doLog': true,
                  'serialId': 1,
                },
                'config': {
                  'allocationKey': 'allocation-b',
                  'variationKey': 'compact',
                  'variationType': 'object',
                  'variationValue': {'layout': 'compact'},
                  'reason': 'TARGETING_MATCH',
                  'doLog': true,
                },
              },
            },
          },
        }),
        200,
      );
    }
    return http.Response('{}', 202);
  });

  DatadogFlagsConfiguration configuration({
    bool trackExposures = true,
    bool trackEvaluations = true,
  }) => DatadogFlagsConfiguration(
    datadogConfig: datadogConfig,
    httpClient: httpClient(),
    trackExposures: trackExposures,
    trackEvaluations: trackEvaluations,
  );

  List<Map<String, Object?>> exposureEvents() => [
    for (final request in requests)
      if (request.url.path == '/api/v2/exposures')
        for (final line in request.body.split('\n'))
          if (line.isNotEmpty) jsonDecode(line) as Map<String, Object?>,
  ];

  List<Map<String, Object?>> evaluationEvents() => [
    for (final request in requests)
      if (request.url.path == '/api/v2/flagevaluation')
        for (final event
            in isWebFlagsIntake
                ? LineSplitter.split(request.body).map(jsonDecode)
                : (jsonDecode(request.body)
                          as Map<String, Object?>)['flagEvaluations']!
                      as List<Object?>)
          event! as Map<String, Object?>,
  ];

  /// Registers [provider] for the peek domain and returns its client.
  Future<OpenFeatureClient> startPeek(DatadogProvider provider) async {
    await api.setProviderForDomainAndWait(_peekDomain, provider);
    return api.getClient(_peekDomain);
  }

  /// Registers a provider with default tracking as the default provider.
  Future<OpenFeatureClient> startDefault() async {
    await api.setProviderAndWait(
      DatadogProvider.fromConfiguration(configuration()),
    );
    return api.getClient();
  }

  setUp(() async {
    api = createIsolatedOpenFeatureAPI();
    requests = [];
    hookEvaluations = [];
    await api.setEvaluationContextAndWait(
      EvaluationContext(targetingKey: 'user-1', attributes: {'plan': 'pro'}),
    );
    api.addHooks([ExposureHook(hookEvaluations.add)]);
  });

  tearDown(() => api.shutdown());

  test('tracks exposures and evaluations by default', () async {
    final provider = DatadogProvider.fromConfiguration(configuration());
    expect(provider.trackExposures, isTrue);
    expect(provider.trackEvaluations, isTrue);
    final client = await startPeek(provider);

    final details = client.getBooleanDetails('flag', false);
    await api.shutdown();

    expect(details.value, isTrue);
    expect(details.flagMetadata, isNot(contains('__dd_track_evaluations')));
    expect(hookEvaluations.single.isExposure, isTrue);
    expect(exposureEvents(), hasLength(1));
    expect(evaluationEvents(), hasLength(1));
  });

  test('trackExposures: false sends no exposure and reports none', () async {
    final client = await startPeek(
      DatadogProvider.fromConfiguration(configuration(), trackExposures: false),
    );

    final details = client.getBooleanDetails('flag', false);
    await api.shutdown();

    expect(details.value, isTrue);
    expect(details.variant, 'on');
    final evaluation = hookEvaluations.single;
    expect(evaluation.isExposure, isFalse);
    expect(evaluation.shouldSend, isFalse);
    expect(exposureEvents(), isEmpty);
    expect(evaluationEvents(), hasLength(1));
  });

  test('trackEvaluations: false sends no evaluation telemetry', () async {
    final client = await startPeek(
      DatadogProvider.fromConfiguration(
        configuration(),
        trackEvaluations: false,
      ),
    );

    final details = client.getBooleanDetails('flag', false);
    await api.shutdown();

    expect(details.value, isTrue);
    expect(details.flagMetadata['__dd_track_evaluations'], isFalse);
    expect(hookEvaluations.single.isExposure, isTrue);
    expect(exposureEvents(), hasLength(1));
    expect(evaluationEvents(), isEmpty);
  });

  test('both off records nothing and keeps the value', () async {
    final client = await startPeek(
      DatadogProvider.fromConfiguration(
        configuration(),
        trackExposures: false,
        trackEvaluations: false,
      ),
    );

    final details = client.getBooleanDetails('flag', false);
    await api.shutdown();

    expect(details.value, isTrue);
    expect(details.variant, 'on');
    expect(details.reason, 'TARGETING_MATCH');
    expect(details.flagMetadata['allocationKey'], 'allocation-a');
    expect(hookEvaluations.single.isExposure, isFalse);
    expect(exposureEvents(), isEmpty);
    expect(evaluationEvents(), isEmpty);
  });

  test('a later default evaluation still sends its exposure', () async {
    final peek = await startPeek(
      DatadogProvider.fromConfiguration(
        configuration(),
        trackExposures: false,
        trackEvaluations: false,
      ),
    );
    final normal = await startDefault();

    expect(peek.getBooleanValue('flag', false), isTrue);
    expect(peek.getBooleanValue('flag', false), isTrue);
    expect(normal.getBooleanValue('flag', false), isTrue);
    await api.shutdown();

    expect(
      [for (final e in hookEvaluations) e.isExposure],
      [false, false, true],
    );
    expect(
      [for (final e in hookEvaluations) e.isCacheHit],
      [false, false, false],
    );
    final exposure = exposureEvents().single;
    expect(exposure['flag'], {'key': 'flag'});
    expect((exposure['subject']! as Map)['id'], 'user-1');
    expect(evaluationEvents(), hasLength(1));
  });

  for (final (name, evaluate)
      in <(String, Object? Function(OpenFeatureClient))>[
        ('a missing flag', (c) => c.getBooleanValue('missing', false)),
        ('a type mismatch', (c) => c.getStringValue('flag', 'default')),
        ('a structure', (c) => c.getStructureValue('config', const {})),
      ]) {
    for (final trackEvaluations in [true, false]) {
      test('${trackEvaluations ? 'sends' : 'trackEvaluations: false sends no'} '
          'evaluation telemetry for $name', () async {
        final client = await startPeek(
          DatadogProvider.fromConfiguration(
            configuration(),
            trackEvaluations: trackEvaluations,
          ),
        );

        evaluate(client);
        await api.shutdown();

        expect(evaluationEvents(), hasLength(trackEvaluations ? 1 : 0));
      });
    }
  }

  test('cannot widen exposure or evaluation tracking', () async {
    final client = await startPeek(
      DatadogProvider.fromConfiguration(
        configuration(trackExposures: false, trackEvaluations: false),
      ),
    );

    client.getBooleanValue('flag', false);
    await api.shutdown();

    expect(exposureEvents(), isEmpty);
    expect(evaluationEvents(), isEmpty);
  });
}
