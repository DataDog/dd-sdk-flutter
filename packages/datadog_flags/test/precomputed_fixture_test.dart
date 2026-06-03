// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures/precomputed_cases.dart';

void main() {
  setUp(() async {
    await DatadogFlags.disable();
  });

  tearDown(() async {
    await DatadogFlags.disable();
  });

  for (final fixtureCase in precomputedFixtureCases) {
    test(
      'precomputed fixture ${fixtureCase.name}',
      () async {
        final fixture = jsonDecode(fixtureCase.json) as Map<String, Object?>;
        final requests = <http.Request>[];
        final httpClient = MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/precompute-assignments') {
            return http.Response(jsonEncode(fixture['response']), 200);
          }
          if (request.url.path == '/api/v2/exposures' ||
              request.url.path == '/api/v2/flagevaluation') {
            return http.Response('{"ok":true}', 200);
          }
          return http.Response('{"error":"unexpected request"}', 404);
        });

        await DatadogFlags.enable(
          configuration: DatadogFlagsConfiguration(
            datadogContext: const DatadogFlagsContext(
              clientToken: 'client-token',
              env: 'staging',
              site: DatadogSite.us1,
              service: 'fixture-test',
              version: '1.0.0',
              applicationId: 'rum-app-id',
              sdkVersion: '9.8.7',
            ),
            store: InMemoryDatadogFlagsStore(),
            httpClient: httpClient,
            dateProvider: () => DateTime.fromMillisecondsSinceEpoch(1234567890),
            evaluationFlushInterval: const Duration(seconds: 1),
          ),
        );
        try {
          final client = DatadogFlags.sharedClient();

          final context = DatadogFlagsEvaluationContext.fromJson(
            fixture['context'] as Map<String, Object?>,
          );
          await client.setEvaluationContext(context);

          final evaluations = (fixture['evaluations'] as List<Object?>)
              .cast<Map<String, Object?>>();
          for (final evaluation in evaluations) {
            final details = _evaluate(client, evaluation);
            final result = evaluation['result'] as Map<String, Object?>;
            expect(details.value, result['value']);
            expect(details.variant, result['variant']);
            expect(details.reason, result['reason']);
            expect(details.error?.name, result['error']);
          }

          await Future<void>.delayed(Duration.zero);
          await client.flush();

          final exposureRequests = requests
              .where((request) => request.url.path == '/api/v2/exposures')
              .toList();
          final evaluationRequests = requests
              .where((request) => request.url.path == '/api/v2/flagevaluation')
              .toList();
          final expectedEmissions =
              fixture['expectedEmissions'] as Map<String, Object?>;

          expect(
            exposureRequests,
            hasLength(expectedEmissions['exposures'] as int),
          );
          expect(
            evaluationRequests,
            hasLength(expectedEmissions['flagevaluationRequests'] as int),
          );

          final evaluationEvents = evaluationRequests
              .expand((request) {
                final body = jsonDecode(request.body) as Map<String, Object?>;
                return body['flagEvaluations'] as List<Object?>;
              })
              .cast<Map<String, Object?>>()
              .toList();
          expect(
            evaluationEvents,
            hasLength(expectedEmissions['flagevaluationEvents'] as int),
          );
          _assertEvaluationPayloads(evaluationEvents, evaluations);
        } finally {
          await DatadogFlags.disable();
        }
      },
    );
  }
}

FlagDetails<Object?> _evaluate(
  DatadogFlagsClient client,
  Map<String, Object?> evaluation,
) {
  final flag = evaluation['flag'] as String;
  final defaultValue = evaluation['defaultValue'];
  switch (evaluation['variationType'] as String) {
    case 'boolean':
      return client.getBooleanDetails(
        key: flag,
        defaultValue: defaultValue as bool,
      );
    case 'string':
      return client.getStringDetails(
        key: flag,
        defaultValue: defaultValue as String,
      );
    case 'integer':
      return client.getIntegerDetails(
        key: flag,
        defaultValue: defaultValue as int,
      );
    case 'float':
      return client.getDoubleDetails(
        key: flag,
        defaultValue: (defaultValue as num).toDouble(),
      );
    case 'object':
      return client.getObjectDetails(key: flag, defaultValue: defaultValue);
    default:
      throw StateError('Unknown fixture variation type $evaluation');
  }
}

void _assertEvaluationPayloads(
  List<Map<String, Object?>> actual,
  List<Map<String, Object?>> expected,
) {
  for (final expectedEvaluation in expected) {
    final flag = expectedEvaluation['flag'] as String;
    final result = expectedEvaluation['result'] as Map<String, Object?>;
    final event = actual.singleWhere((candidate) {
      return (candidate['flag'] as Map<String, Object?>)['key'] == flag;
    });

    expect(event['evaluation_count'], 1);
    if (result['error'] == null) {
      expect(event['runtime_default_used'], isNull);
      expect(
          (event['variant'] as Map<String, Object?>)['key'], result['variant']);
    } else {
      expect(event['runtime_default_used'], isTrue);
      expect(event['variant'], isNull);
      expect(
        (event['error'] as Map<String, Object?>)['message'],
        _wireError(result['error'] as String),
      );
    }
  }
}

String _wireError(String error) {
  return switch (error) {
    'flagNotFound' => 'FLAG_NOT_FOUND',
    'providerNotReady' => 'PROVIDER_NOT_READY',
    'typeMismatch' => 'TYPE_MISMATCH',
    _ => throw StateError('Unknown fixture error $error'),
  };
}
