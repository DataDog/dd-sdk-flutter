// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/assignment.dart';
import 'package:datadog_flags/src/flag_assignments_fetcher.dart';
import 'package:datadog_flags/src/flags_error.dart';
import 'package:datadog_flags/src/sdk_metadata.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('FlagAssignmentsFetcher', () {
    final requestFixture = {
      'context': {
        'targetingKey': 'precomputed-user',
        'attributes': {'plan': 'pro', 'platform': 'flutter'},
      },
      'response': {'data': _emptyAssignments()},
    };

    test(
      'builds the precompute request expected by canonical fixtures',
      () async {
        final requests = <http.Request>[];
        final fetcher = FlagAssignmentsFetcher(
          datadogConfig: const DatadogFlagsConfig(
            clientToken: 'client-token',
            env: 'staging',
            site: DatadogFlagsSite.us1,
            applicationId: 'application-id',
          ),
          configuration: const DatadogFlagsConfiguration(),
          httpClient: _jsonClient(requests, requestFixture['response']),
        );

        await fetcher.fetch(
          FlagsEvaluationContext.fromJson(
            requestFixture['context'] as Map<String, Object?>,
          ),
        );

        expect(requests, hasLength(1));
        final request = requests.single;
        expect(
          request.url,
          Uri.parse(
            'https://preview.ff-cdn.datadoghq.com/precompute-assignments',
          ),
        );
        expect(request.headers['Content-Type'], 'application/vnd.api+json');
        expect(request.headers['dd-client-token'], 'client-token');
        expect(request.headers['dd-application-id'], 'application-id');
        expect(request.headers.containsKey('X-Use-Cache'), isFalse);
        expect(jsonDecode(request.body), {
          'data': {
            'type': 'precompute-assignments-request',
            'attributes': {
              'env': {'dd_env': 'staging'},
              'source': {
                'sdk_name': 'dd-sdk-dart',
                'sdk_version': datadogFlagsSdkVersion,
              },
              'subject': {
                'targeting_key': 'precomputed-user',
                'targeting_attributes': {'plan': 'pro', 'platform': 'flutter'},
              },
            },
          },
        });
      },
    );

    test(
      'omits application id unless configured and applies custom headers',
      () async {
        final requests = <http.Request>[];
        final fetcher = FlagAssignmentsFetcher(
          datadogConfig: const DatadogFlagsConfig(
            clientToken: 'token',
            env: 'dev',
            site: DatadogFlagsSite.us1,
          ),
          configuration: DatadogFlagsConfiguration(
            customFlagsEndpoint: Uri.parse('https://example.com/precompute'),
            customFlagsHeaders: const {'x-test-header': '1'},
          ),
          httpClient: _jsonClient(requests, {'data': _emptyAssignments()}),
        );

        await fetcher.fetch(
          const FlagsEvaluationContext(targetingKey: 'subject'),
        );

        final request = requests.single;
        expect(request.url, Uri.parse('https://example.com/precompute'));
        expect(request.headers['dd-client-token'], 'token');
        expect(request.headers.containsKey('dd-application-id'), isFalse);
        expect(request.headers['x-test-header'], '1');
      },
    );

    test('sends empty targeting key when none is configured', () async {
      final requests = <http.Request>[];
      final fetcher = FlagAssignmentsFetcher(
        datadogConfig: _contextFor(DatadogFlagsSite.us1),
        configuration: const DatadogFlagsConfiguration(),
        httpClient: _jsonClient(requests, {'data': _emptyAssignments()}),
      );

      await fetcher.fetch(
        const FlagsEvaluationContext(attributes: {'companyId': '1'}),
      );

      expect(jsonDecode(requests.single.body), {
        'data': {
          'type': 'precompute-assignments-request',
          'attributes': {
            'env': {'dd_env': 'dev'},
            'source': {
              'sdk_name': 'dd-sdk-dart',
              'sdk_version': datadogFlagsSdkVersion,
            },
            'subject': {
              'targeting_key': '',
              'targeting_attributes': {'companyId': '1'},
            },
          },
        },
      });
    });

    test('serializes targeting attributes as scalar values', () async {
      final requests = <http.Request>[];
      final fetcher = FlagAssignmentsFetcher(
        datadogConfig: _contextFor(DatadogFlagsSite.us1),
        configuration: const DatadogFlagsConfiguration(),
        httpClient: _jsonClient(requests, {'data': _emptyAssignments()}),
      );

      await fetcher.fetch(
        const FlagsEvaluationContext(
          targetingKey: 'subject',
          attributes: {
            'string': 'value',
            'integer': 42,
            'double': 0.5,
            'boolean': true,
            'null': null,
            'object': {'nested': 'value'},
            'list': ['a', 1],
          },
        ),
      );

      final body = jsonDecode(requests.single.body) as Map<String, Object?>;
      final data = body['data'] as Map<String, Object?>;
      final attributes = data['attributes'] as Map<String, Object?>;
      final subject = attributes['subject'] as Map<String, Object?>;
      expect(subject['targeting_attributes'], {
        'string': 'value',
        'integer': 42,
        'double': 0.5,
        'boolean': true,
        'null': null,
        'object': '{"nested":"value"}',
        'list': '["a",1]',
      });
    });

    test('maps all supported sites', () {
      expect(
        _contextFor(DatadogFlagsSite.us1).flagsEndpoint(),
        Uri.parse('https://preview.ff-cdn.datadoghq.com'),
      );
      expect(
        _contextFor(DatadogFlagsSite.us1Staging).flagsEndpoint(),
        Uri.parse('https://preview.ff-cdn.datad0g.com'),
      );
      expect(
        _contextFor(DatadogFlagsSite.us3).flagsEndpoint(),
        Uri.parse('https://preview.ff-cdn.us3.datadoghq.com'),
      );
      expect(
        _contextFor(DatadogFlagsSite.us5).flagsEndpoint(),
        Uri.parse('https://preview.ff-cdn.us5.datadoghq.com'),
      );
      expect(
        _contextFor(DatadogFlagsSite.eu1).flagsEndpoint(),
        Uri.parse('https://preview.ff-cdn.datadoghq.eu'),
      );
      expect(
        _contextFor(DatadogFlagsSite.ap1).flagsEndpoint(),
        Uri.parse('https://preview.ff-cdn.ap1.datadoghq.com'),
      );
      expect(
        _contextFor(DatadogFlagsSite.ap2).flagsEndpoint(),
        Uri.parse('https://preview.ff-cdn.ap2.datadoghq.com'),
      );
    });

    test(
      'keeps canonical number variation names from the server',
      () async {
        final requests = <http.Request>[];
        final fetcher = FlagAssignmentsFetcher(
          datadogConfig: _contextFor(DatadogFlagsSite.us1),
          configuration: const DatadogFlagsConfiguration(),
          httpClient: _jsonClient(requests, {
            'data': {
              'attributes': {
                'flags': {
                  'enabled': _assignment('boolean', true),
                  'title': _assignment('string', 'Hello'),
                  'integer': _assignment('number', 12),
                  'float': _assignment('number', 0.25),
                  'object': _assignment('object', {
                    'nested': ['value'],
                  }),
                },
              },
            },
          }),
        );

        final assignments = (await fetcher.fetch(
          const FlagsEvaluationContext(targetingKey: 'subject'),
        ))
            .flags;

        expect(
          assignments['enabled']!.variationType,
          FlagVariationType.boolean,
        );
        expect(assignments['title']!.variationType, FlagVariationType.string);
        expect(
          assignments['integer']!.variationType,
          FlagVariationType.number,
        );
        expect(assignments['float']!.variationType, FlagVariationType.number);
        expect(assignments['object']!.variationType, FlagVariationType.object);
        expect(assignments['integer']!.variationValue, 12);
        expect(assignments['float']!.variationValue, 0.25);
      },
    );

    test(
      'ignores malformed flag entries without dropping valid assignments',
      () async {
        final requests = <http.Request>[];
        final fetcher = FlagAssignmentsFetcher(
          datadogConfig: _contextFor(DatadogFlagsSite.us1),
          configuration: const DatadogFlagsConfiguration(),
          httpClient: _jsonClient(requests, {
            'data': {
              'attributes': {
                'flags': {
                  'valid': _assignment('boolean', true),
                  'not-object': 'bad',
                  'missing-fields': {'variationType': 'boolean'},
                  'null-value': _assignment('string', null),
                  'unsupported': _assignment('unsupported', 'ignored'),
                },
              },
            },
          }),
        );

        final assignments = (await fetcher.fetch(
          const FlagsEvaluationContext(targetingKey: 'subject'),
        ))
            .flags;

        expect(assignments.keys, ['valid']);
      },
    );

    test('returns response metadata with assignments', () async {
      final requests = <http.Request>[];
      final fetcher = FlagAssignmentsFetcher(
        datadogConfig: _contextFor(DatadogFlagsSite.us1),
        configuration: const DatadogFlagsConfiguration(),
        httpClient: _jsonClient(requests, {
          'data': {
            'attributes': {
              'createdAt': '2026-06-04T12:00:00.000Z',
              'environment': 'prod',
              'flags': {
                'valid': _assignment('boolean', true),
              },
            },
          },
        }),
      );

      final response = await fetcher.fetch(
        const FlagsEvaluationContext(targetingKey: 'subject'),
      );

      expect(response.createdAt, DateTime.utc(2026, 6, 4, 12));
      expect(response.environment, 'prod');
      expect(response.flags.keys, ['valid']);
    });

    test('accepts live response environment objects', () async {
      final requests = <http.Request>[];
      final fetcher = FlagAssignmentsFetcher(
        datadogConfig: _contextFor(DatadogFlagsSite.us1),
        configuration: const DatadogFlagsConfiguration(),
        httpClient: _jsonClient(requests, {
          'data': {
            'attributes': {
              'createdAt': '2026-06-23T21:04:41.025844773Z',
              'environment': {'name': 'Development - Local or Hash'},
              'flags': {
                'valid': _assignment('boolean', true),
              },
            },
          },
        }),
      );

      final response = await fetcher.fetch(
        const FlagsEvaluationContext(targetingKey: 'subject'),
      );

      expect(response.environment, 'Development - Local or Hash');
      expect(response.flags.keys, ['valid']);
    });

    test(
      'reports internal network errors for wrapper fallback handling',
      () async {
        final nonSuccessFetcher = FlagAssignmentsFetcher(
          datadogConfig: _contextFor(DatadogFlagsSite.us1),
          configuration: const DatadogFlagsConfiguration(),
          httpClient: MockClient((_) async => http.Response('nope', 500)),
        );

        await expectLater(
          nonSuccessFetcher.fetch(
            const FlagsEvaluationContext(targetingKey: 'subject'),
          ),
          throwsA(
            isA<FlagsException>().having(
              (error) => error.type,
              'type',
              FlagsErrorType.networkError,
            ),
          ),
        );

        final failingFetcher = FlagAssignmentsFetcher(
          datadogConfig: _contextFor(DatadogFlagsSite.us1),
          configuration: const DatadogFlagsConfiguration(),
          httpClient: MockClient((_) async => throw StateError('offline')),
        );

        await expectLater(
          failingFetcher.fetch(
            const FlagsEvaluationContext(targetingKey: 'subject'),
          ),
          throwsA(
            isA<FlagsException>()
                .having(
                  (error) => error.type,
                  'type',
                  FlagsErrorType.networkError,
                )
                .having((error) => error.cause, 'cause', isA<StateError>()),
          ),
        );
      },
    );

    test('reports invalid response errors for malformed envelopes', () async {
      final fetcher = FlagAssignmentsFetcher(
        datadogConfig: _contextFor(DatadogFlagsSite.us1),
        configuration: const DatadogFlagsConfiguration(),
        httpClient: MockClient((_) async => http.Response('{"data":[]}', 200)),
      );

      await expectLater(
        fetcher.fetch(
          const FlagsEvaluationContext(targetingKey: 'subject'),
        ),
        throwsA(
          isA<FlagsException>().having(
            (error) => error.type,
            'type',
            FlagsErrorType.invalidResponse,
          ),
        ),
      );
    });
  });
}

DatadogFlagsConfig _contextFor(DatadogFlagsSite site) {
  return DatadogFlagsConfig(clientToken: 'token', env: 'dev', site: site);
}

http.Client _jsonClient(List<http.Request> requests, Object? body) {
  return MockClient((request) async {
    requests.add(request);
    return http.Response(jsonEncode(body), 200);
  });
}

Map<String, Object?> _emptyAssignments() {
  return {
    'attributes': {'flags': <String, Object?>{}},
  };
}

Map<String, Object?> _assignment(String variationType, Object? value) {
  return {
    'allocationKey': 'allocation-$variationType',
    'variationKey': 'variation-$variationType',
    'variationType': variationType,
    'variationValue': value,
    'reason': 'TARGETING_MATCH',
    'doLog': true,
  };
}
