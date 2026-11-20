// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/flags_client.dart';
import 'package:datadog_flags/src/flags_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
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
    final count = matcher['_count'];
    if (count is! int || count < 1) {
      fail('Event matcher _count must be a positive integer: $matcher');
    }
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
  registerFallbackValue(_FakeFlagsData());
  numericGetterRegressions();
  numericTokenLayouts();
  plaintextKeyIdentity();
  runnerMatching();
  legacyCacheBounds();
  if (precomputedText.isEmpty) {
    throw StateError('Empty canonical fixture snapshot');
  }
  group('canonical precompute $precomputedRevision', () {
    final exclusions = <String>[];
    var executedEvaluations = 0;
    tearDownAll(() {
      // Reports the corpus revision, executed evaluations, and exclusions.
      print(
        [
          'Precomputed fixtures $precomputedRevision: '
              '${precomputedText.length} fixtures, '
              '$executedEvaluations evaluations executed, '
              '${exclusions.length} exclusions',
          for (final exclusion in exclusions) '  excluded $exclusion',
        ].join('\n'),
      );
    });
    for (final entry in precomputedText.entries) {
      final fixture = jsonDecode(entry.value.fixture) as Map<String, dynamic>;
      final exactFixture =
          jsonDecode(quoteNumbers(entry.value.fixture)) as Map<String, dynamic>;
      final name = fixture['name'];
      if (!applies(fixture)) {
        exclusions.add('fixture $name');
      } else {
        for (final (index, evaluation)
            in (fixture['evaluations'] as List).indexed) {
          if (!applies(Map<String, dynamic>.from(evaluation as Map))) {
            exclusions.add('$name evaluation $index (${evaluation['flag']})');
          }
        }
        final expected = fixture['expectations'] as Map? ?? const {};
        for (final kind in ['exposures', 'evaluationEvents']) {
          for (final (index, matcher)
              in (expected[kind] as List? ?? []).indexed) {
            if (!applies(Map<String, dynamic>.from(matcher as Map))) {
              exclusions.add('$name $kind matcher $index');
            }
          }
        }
      }
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
              executedEvaluations++;
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

class _FakeFlagsData extends Fake implements FlagsData {}

class _JsonStore extends Mock implements DatadogFlagsStore {
  String? content;

  _JsonStore() {
    when(() => read(any())).thenAnswer((_) async {
      final saved = content;
      return saved == null
          ? null
          : FlagsData.fromJson(jsonDecode(saved) as Map<String, Object?>);
    });
    when(() => write(any(), any())).thenAnswer((invocation) async {
      final data = invocation.positionalArguments[1] as FlagsData;
      content = jsonEncode(data.toJson());
    });
    when(() => delete(any())).thenAnswer((_) async {
      content = null;
    });
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
    ('1.00000000000000001', null, 1.0),
    ('1.20000000000000001', null, 1.2),
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
      const datadogConfig = DatadogFlagsConfig(
        clientToken: 'fixture',
        env: 'test',
        site: DatadogFlagsSite.us1,
      );
      final store = _JsonStore()
        ..content =
            '{"flags":{"flag":{"allocationKey":"a","variationKey":"v",'
            '"variationType":"float","variationValue":$literal,"reason":"STATIC","doLog":false}},'
            '"context":{"targetingKey":"fixture","attributes":{}},"date":"2026-11-04T00:00:00Z",'
            '"scope":"${flagsDataScope(datadogConfig)}"}';
      final sdk = DatadogFlags();
      await sdk.enable(
        configuration: DatadogFlagsConfiguration(
          store: store,
          datadogConfig: datadogConfig,
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

/// Starts a client on [response], optionally restoring it from a JSON cache.
Future<(DatadogFlags, DatadogFlagsClient, List<http.Request>)> startClient(
  String response, {
  required bool restored,
}) async {
  final store = _JsonStore();
  var offline = false;
  final requests = <http.Request>[];
  final config = DatadogFlagsConfiguration(
    store: store,
    datadogConfig: const DatadogFlagsConfig(
      clientToken: 'fixture',
      env: 'test',
      site: DatadogFlagsSite.us1,
    ),
    httpClient: MockClient((request) async {
      requests.add(request);
      final precompute = request.url.path == '/precompute-assignments';
      return http.Response(
        precompute && !offline ? response : '{}',
        precompute && offline ? 500 : 200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  final context = FlagsEvaluationContext(targetingKey: 'fixture');
  var sdk = DatadogFlags();
  await sdk.enable(configuration: config);
  await sdk.sharedClient().initialize(context);
  if (restored) {
    await sdk.disable();
    expect(store.content, isNotNull);
    offline = true;
    requests.clear();
    sdk = DatadogFlags();
    await sdk.enable(configuration: config);
    await sdk.sharedClient().initialize(context);
  }
  return (sdk, sdk.sharedClient(), requests);
}

List<Object?> exposuresIn(List<http.Request> requests) => [
  for (final request in requests)
    if (request.url.path == '/api/v2/exposures')
      for (final line in request.body.trim().split('\n'))
        if (line.isNotEmpty) jsonDecode(line),
];

List<Object?> evaluationsIn(List<http.Request> requests) => [
  for (final request in requests)
    if (request.url.path == '/api/v2/flagevaluation')
      ...const bool.fromEnvironment('dart.library.js_interop')
          ? [
              for (final line in request.body.trim().split('\n'))
                if (line.isNotEmpty) jsonDecode(line),
            ]
          : jsonDecode(request.body)['flagEvaluations'] as List,
];

void numericTokenLayouts() {
  String flag(String type, String value) =>
      '{"allocationKey":"a","variationKey":"v","variationType":"$type",'
      '"variationValue":$value,"reason":"STATIC","doLog":false}';
  final target = flag('integer', '4503599627370497.5');
  final layouts = {
    'pretty-printed':
        '{\n  "data" : {\n    "attributes" : {\n      "flags" : {\n'
        '        "target" : {\n          "allocationKey" : "a",\n'
        '          "variationKey" : "v",\n          "variationType" : "integer",\n'
        '          "variationValue" :\n            4503599627370497.5 ,\n'
        '          "reason" : "STATIC",\n          "doLog" : false\n'
        '        }\n      }\n    }\n  }\n}',
    'members after flags':
        '{"data":{"attributes":{"flags":{"target":$target},"extra":[1.5,2]},'
        '"id":"1","type":"precomputed-assignments"},"meta":{"n":3}}',
    'flags named after envelope keys':
        '{"data":{"attributes":{"flags":{"data":${flag('integer', '7')},'
        '"variationValue":${flag('float', '1.5')},"target":$target}}}}',
    'object values with numeric members':
        '{"data":{"attributes":{"flags":{"object":{"allocationKey":"a",'
        '"variationKey":"v","variationType":"object","variationValue":'
        '{"variationValue":1,"flags":{"target":2}},"reason":"STATIC",'
        '"doLog":false},"target":$target}}}}',
    'escaped string containing a number':
        '{"data":{"attributes":{"flags":{"q\\"1.5":${flag('integer', '3')},'
        '"target":$target}}}}',
    'duplicate flag key':
        '{"data":{"attributes":{"flags":{"target":${flag('integer', '5')},'
        '"target":$target}}}}',
  };
  for (final MapEntry(key: layout, value: response) in layouts.entries) {
    for (final restored in [false, true]) {
      test(
        'numeric token lookup ignores layout: $layout restored=$restored',
        () async {
          final (sdk, client, _) = await startClient(
            response,
            restored: restored,
          );
          addTearDown(sdk.disable);
          final integer = client.getIntegerDetails(
            key: 'target',
            defaultValue: -99,
          );
          expect(integer.value, -99);
          expect(integer.error?.code, 'TYPE_MISMATCH');
          final floating = client.getDoubleDetails(
            key: 'target',
            defaultValue: -99.5,
          );
          expect(floating.value, 4503599627370498.0);
          expect(floating.error, isNull);
        },
      );
    }
  }
}

void plaintextKeyIdentity() {
  const composed = 'caf\u00e9';
  const decomposed = 'cafe\u0301';
  const response =
      '{"data":{"attributes":{"flags":{"$composed":{"allocationKey":"a",'
      '"variationKey":"v","variationType":"boolean","variationValue":true,'
      '"reason":"STATIC","doLog":true}}}}}';
  for (final restored in [false, true]) {
    test('plaintext keys match exact code units restored=$restored', () async {
      final (sdk, client, requests) = await startClient(
        response,
        restored: restored,
      );
      addTearDown(sdk.disable);
      final missing = client.getBooleanDetails(
        key: decomposed,
        defaultValue: false,
      );
      expect(missing.error?.code, 'FLAG_NOT_FOUND');
      expect(missing.value, isFalse);
      final found = client.getBooleanDetails(
        key: composed,
        defaultValue: false,
      );
      expect(found.error, isNull);
      expect(found.value, isTrue);
      await sdk.disable();
      final exposures = exposuresIn(requests);
      expect(exposures, hasLength(1));
      expect(
        matches(exposures.single, {
          'flag': {'key': composed},
        }),
        isTrue,
      );
      final evaluations = evaluationsIn(requests);
      expect(
        evaluations.where(
          (event) => matches(event, {
            'flag': {'key': decomposed},
          }),
        ),
        hasLength(1),
      );
      expect(
        evaluations.where(
          (event) => matches(event, {
            'flag': {'key': composed},
          }),
        ),
        hasLength(1),
      );
    });
  }
}

void runnerMatching() {
  for (final (actual, expected) in <(Object?, Object?)>[
    (true, 1),
    (1, true),
    (false, 0),
    (0, false),
    ('1', 1),
    (null, false),
  ]) {
    test('runner matcher rejects $actual for expected $expected', () {
      expect(matches(actual, expected), isFalse);
      expect(matches({'v': actual}, {'v': expected}), isFalse);
      expect(matches([actual], [expected]), isFalse);
    });
  }
  for (final count in <Object?>[0, -1, true, false, '1', 1.5, null]) {
    test('runner rejects event matcher _count $count', () {
      expect(
        () => checkEvents(
          [
            {'flag': 'a'},
          ],
          [
            {'flag': 'a', '_count': count},
          ],
          false,
        ),
        throwsA(isA<TestFailure>()),
      );
    });
  }
}
