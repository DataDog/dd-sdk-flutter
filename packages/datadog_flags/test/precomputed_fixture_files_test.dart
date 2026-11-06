// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'fixtures/precomputed_text.dart';

bool applies(Map<String, dynamic> value) {
  bool contains(String field) => (value[field] as List? ?? []).any(
    (entry) => entry['platform'] == 'flutter',
  );
  final included = (value['_include'] as List? ?? [])
      .map((entry) => entry['platform'])
      .toSet();
  // The shared corpus uses ios/flutter-only applicability for native Int64 cases,
  // including generated companions whose reason text differs from the source.
  final nativeIntegerOnly =
      included.length == 2 &&
      included.contains('ios') &&
      included.contains('flutter');
  return !(identical(1, 1.0) && nativeIntegerOnly) &&
      !contains('_skip') &&
      (!value.containsKey('_include') || contains('_include'));
}

bool matches(Object? actual, Object? expected) {
  if (expected is Map) {
    return actual is Map &&
        expected.entries.every(
          (entry) => matches(actual[entry.key], entry.value),
        );
  }
  if (expected is List) {
    return actual is List &&
        actual.length == expected.length &&
        List.generate(
          expected.length,
          (i) => i,
        ).every((i) => matches(actual[i], expected[i]));
  }
  return actual == expected;
}

void checkEvents(List<dynamic> events, List<dynamic> matchers, bool exact) {
  final remaining = List<dynamic>.of(events);
  for (final raw in matchers) {
    final matcher = Map<String, dynamic>.from(raw as Map);
    if (!applies(matcher)) continue;
    final fields = Map<String, dynamic>.from(matcher)
      ..removeWhere((key, _) => key.startsWith('_'));
    final count = matcher['_count'] as int;
    final selected = remaining
        .where((event) => matches(event, fields))
        .take(count)
        .toList();
    expect(selected, hasLength(count), reason: 'event matcher $matcher');
    for (final event in selected) {
      remaining.remove(event);
    }
  }
  if (exact) expect(remaining, isEmpty, reason: 'unmatched events');
}

void main() {
  numericGetterRegressions();
  legacyCacheBounds();
  if (precomputedText.isEmpty) {
    throw StateError('Empty canonical fixture snapshot');
  }
  group('canonical precompute $precomputedRevision', () {
    for (final entry in precomputedText.entries) {
      final fixture = jsonDecode(entry.value.fixture) as Map<String, dynamic>;
      final exactFixture =
          jsonDecode(quoteNumbers(entry.value.fixture)) as Map<String, dynamic>;
      for (final restored
          in fixture.containsKey('expectedResponseError') || !applies(fixture)
              ? [false]
              : [false, true]) {
        test(
          '${fixture['name']} restored=$restored',
          () async {
            final responseText = entry.value.response;
            final store = _JsonStore();
            var sdk = DatadogFlags();
            var offline = false;
            final requests = <http.Request>[];
            final configuration = DatadogFlagsConfiguration(
              store: store,
              datadogConfig: const DatadogFlagsConfig(
                clientToken: 'fixture',
                env: 'test',
                site: DatadogFlagsSite.us1,
              ),
              httpClient: MockClient((request) async {
                requests.add(request);
                if (offline && request.url.path == '/precompute-assignments') {
                  return http.Response('{}', 500);
                }
                return http.Response(
                  request.url.path == '/precompute-assignments'
                      ? responseText
                      : '{}',
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                );
              }),
            );
            await sdk.enable(configuration: configuration);
            addTearDown(() => sdk.disable());
            var client = sdk.sharedClient();
            final context = FlagsEvaluationContext.fromJson(
              Map<String, Object?>.from(fixture['context'] as Map),
            );
            await client.initialize(context);
            expect(
              (client as DatadogFlagsClientLifecycle).status,
              fixture['expectedResponseError'] == 'INVALID_RESPONSE'
                  ? DatadogFlagsClientStatus.error
                  : DatadogFlagsClientStatus.ready,
            );
            if (restored) {
              await sdk.disable();
              offline = true;
              requests.clear();
              sdk = DatadogFlags();
              await sdk.enable(configuration: configuration);
              client = sdk.sharedClient();
              await client.initialize(context);
            }
            final evaluationsList = fixture['evaluations'] as List;
            for (
              var evaluationIndex = 0;
              evaluationIndex < evaluationsList.length;
              evaluationIndex++
            ) {
              final raw = evaluationsList[evaluationIndex];
              final evaluation = Map<String, dynamic>.from(raw as Map);
              if (!applies(evaluation)) continue;
              final key = evaluation['flag'] as String;
              final fallback = evaluation['defaultValue'];
              final details = switch (evaluation['variationType']) {
                'boolean' => client.getBooleanDetails(
                  key: key,
                  defaultValue: fallback as bool,
                ),
                'string' => client.getStringDetails(
                  key: key,
                  defaultValue: fallback as String,
                ),
                'integer' => client.getIntegerDetails(
                  key: key,
                  defaultValue: (fallback as num).toInt(),
                ),
                'float' => client.getDoubleDetails(
                  key: key,
                  defaultValue: (fallback as num).toDouble(),
                ),
                'object' => client.getObjectDetails(
                  key: key,
                  defaultValue: fallback,
                ),
                _ => throw StateError('Unsupported fixture getter'),
              };
              if (restored && details.error == null) {
                expect(details.reason, 'CACHED');
              }
              final actual = {
                'value': details.value,
                'reason': details.error == null ? details.reason : 'ERROR',
                'errorCode': details.error?.code,
                'variantKey': details.variant,
              };
              for (final entry
                  in (evaluation['expectedResult'] as Map).entries) {
                if (restored &&
                    entry.key == 'reason' &&
                    details.error == null) {
                  continue;
                }
                if (entry.key == 'value') {
                  checkValue(
                    details.value,
                    evaluation['variationType'] as String,
                    (exactFixture['evaluations']
                        as List)[evaluationIndex]['expectedResult']['value'],
                    entry.value,
                  );
                  continue;
                }
                expect(
                  actual[entry.key],
                  equals(entry.value),
                  reason: '$key: ${entry.key}',
                );
              }
            }
            await sdk.disable();
            final exposures = requests
                .where((r) => r.url.path == '/api/v2/exposures')
                .expand(
                  (r) => r.body
                      .trim()
                      .split('\n')
                      .where((line) => line.isNotEmpty)
                      .map(jsonDecode),
                )
                .toList();
            final evaluations = requests
                .where((r) => r.url.path == '/api/v2/flagevaluation')
                .expand(
                  (r) => const bool.fromEnvironment('dart.library.js_interop')
                      ? r.body
                            .trim()
                            .split('\n')
                            .where((line) => line.isNotEmpty)
                            .map(jsonDecode)
                      : jsonDecode(r.body)['flagEvaluations'] as List,
                )
                .toList();
            final expected = fixture['expectations'] as Map;
            checkEvents(
              exposures,
              expected['exposures'] as List? ?? [],
              expected['noUnmatchedEvents'] == true,
            );
            checkEvents(
              evaluations,
              expected['evaluationEvents'] as List? ?? [],
              expected['noUnmatchedEvents'] == true,
            );
          },
          skip: applies(fixture)
              ? false
              : 'Excluded by canonical platform/accessor applicability (JS lacks native Int64)',
        );
      }
    }
  });
}

class _JsonStore implements DatadogFlagsStore {
  String? content;
  @override
  Future<FlagsData?> read(String clientName) async => content == null
      ? null
      : FlagsData.fromJson(jsonDecode(content!) as Map<String, Object?>);
  @override
  Future<void> write(String clientName, FlagsData data) async {
    content = jsonEncode(data.toJson());
  }

  @override
  Future<void> delete(String clientName) async {
    content = null;
  }
}

String quoteNumbers(String text) => text.replaceAllMapped(
  RegExp(r'"(?:[^"\\]|\\.)*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?'),
  (match) => match[0]!.startsWith('"') ? match[0]! : jsonEncode(match[0]),
);

void checkValue(Object? actual, String getter, Object? exact, Object? decoded) {
  switch (getter) {
    case 'integer':
      expect(actual, isA<int>());
      expect(BigInt.from(actual! as num), BigInt.parse(exact! as String));
    case 'float':
      expect(actual, isA<double>());
      expect(actual, double.parse(exact! as String));
    case 'boolean':
      expect(actual, isA<bool>());
      expect(actual, decoded);
    case 'string':
      expect(actual, isA<String>());
      expect(actual, decoded);
    default:
      expect(actual, decoded);
  }
}

void numericGetterRegressions() {
  final vectors = <(String, String?, double?)>[
    ('9223372036854775808.0', null, 9223372036854775808.0),
    ('-9223372036854775809', null, null),
    ('-9223372036854776832', null, null),
    ('9007199254740993.5', null, 9007199254740994.0),
    ('9007199254740993.0', identical(1, 1.0) ? null : '9007199254740993', null),
    ('4503599627370497.5', null, 4503599627370498.0),
    ('5.0000000000000001', null, 5.0),
    ('5.0', '5', 5.0),
    ('1e400', null, null),
    ('1e300', null, null),
    ('1e-400', null, null),
    ('-0.0', '0', 0.0),
    ('1e3', '1000', 1000.0),
  ];
  for (final label in ['integer', 'number', 'float']) {
    for (final (literal, integer, floating) in vectors) {
      for (final restored in [false, true]) {
        test('public numeric $label $literal restored=$restored', () async {
          final store = _JsonStore();
          var offline = false;
          final config = DatadogFlagsConfiguration(
            store: store,
            datadogConfig: const DatadogFlagsConfig(
              clientToken: 'fixture',
              env: 'test',
              site: DatadogFlagsSite.us1,
            ),
            httpClient: MockClient(
              (request) async => http.Response(
                request.url.path == '/precompute-assignments' && !offline
                    ? '{"data":{"attributes":{"flags":{"旗":{'
                          '"allocationKey":"a","variationKey":"v","variationType":"$label",'
                          '"variationValue":$literal,"reason":"STATIC","doLog":false}}}}}'
                    : '{}',
                offline ? 500 : 200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              ),
            ),
          );
          var sdk = DatadogFlags();
          await sdk.enable(configuration: config);
          addTearDown(() => sdk.disable());
          var client = sdk.sharedClient();
          final context = FlagsEvaluationContext(targetingKey: 'fixture');
          await client.initialize(context);
          if (restored) {
            await sdk.disable();
            expect(
              store.content,
              isNotNull,
              reason: 'JSON persistence must succeed even for overflow tokens',
            );
            offline = true;
            sdk = DatadogFlags();
            await sdk.enable(configuration: config);
            client = sdk.sharedClient();
            await client.initialize(context);
          }
          final intResult = client.getIntegerDetails(
            key: '旗',
            defaultValue: -99,
          );
          expect(intResult.value, isA<int>());
          expect(BigInt.from(intResult.value), BigInt.parse(integer ?? '-99'));
          expect(
            intResult.error?.code,
            integer == null ? 'TYPE_MISMATCH' : null,
          );
          final floatResult = client.getDoubleDetails(
            key: '旗',
            defaultValue: -99.5,
          );
          expect(floatResult.value, isA<double>());
          expect(floatResult.value, floating ?? -99.5);
          expect(
            floatResult.error?.code,
            floating == null ? 'TYPE_MISMATCH' : null,
          );
        });
      }
    }
  }
}

void legacyCacheBounds() {
  for (final (literal, expected) in <(String, int?)>[
    ('9223372036854775808.0', null),
    ('-9223372036854775808.0', -9223372036854775808),
    ('5.5', null),
    ('5.0', 5),
  ]) {
    test('legacy JSON cache Integer bound $literal', () async {
      final store = _JsonStore()
        ..content =
            '{"flags":{"flag":{"allocationKey":"a","variationKey":"v",'
            '"variationType":"float","variationValue":$literal,"reason":"STATIC","doLog":false}},'
            '"context":{"targetingKey":"fixture","attributes":{}},"date":"2026-11-04T00:00:00Z"}';
      final sdk = DatadogFlags();
      await sdk.enable(
        configuration: DatadogFlagsConfiguration(
          store: store,
          datadogConfig: const DatadogFlagsConfig(
            clientToken: 'fixture',
            env: 'test',
            site: DatadogFlagsSite.us1,
          ),
          httpClient: MockClient((_) async => http.Response('{}', 500)),
        ),
      );
      addTearDown(() => sdk.disable());
      final client = sdk.sharedClient();
      await client.initialize(FlagsEvaluationContext(targetingKey: 'fixture'));
      final details = client.getIntegerDetails(key: 'flag', defaultValue: -99);
      expect(BigInt.from(details.value), BigInt.from(expected ?? -99));
      expect(details.error?.code, expected == null ? 'TYPE_MISMATCH' : null);
    });
  }
}
