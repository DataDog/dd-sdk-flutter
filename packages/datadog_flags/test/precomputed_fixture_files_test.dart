// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

bool applies(Map<String, dynamic> value) {
  bool contains(String field) => (value[field] as List? ?? []).any(
    (entry) => entry['platform'] == 'flutter',
  );
  return !contains('_skip') &&
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
  final root = Directory('test/fixtures/precomputed');
  if (!root.existsSync()) {
    throw StateError('Missing canonical fixture snapshot');
  }
  final files =
      Directory('${root.path}/cases')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) throw StateError('Empty canonical fixture snapshot');
  if (!files.any(
    (file) =>
        applies(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>),
  )) {
    throw StateError('All canonical fixtures excluded');
  }
  final source = jsonDecode(
    File('${root.path}/SOURCE.json').readAsStringSync(),
  );
  group('canonical precompute ${source['commit']}', () {
    for (final file in files) {
      final fixture =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final restored
          in fixture.containsKey('expectedResponseError') || !applies(fixture)
              ? [false]
              : [false, true]) {
        test(
          '${fixture['name']} restored=$restored',
          () async {
            final responseText = File(
              '${root.path}/responses/${file.path.substring(root.path.length + 1)}',
            ).readAsStringSync();
            final directory = await Directory.systemTemp.createTemp(
              'canonical-flags-',
            );
            addTearDown(() => directory.delete(recursive: true));
            final store = _FileStore(File('${directory.path}/flags.json'));
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
            for (final raw in fixture['evaluations'] as List) {
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
                .expand((r) => jsonDecode(r.body)['flagEvaluations'] as List)
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
              : 'Excluded by canonical platform filter',
        );
      }
    }
  });
}

class _FileStore implements DatadogFlagsStore {
  final File file;
  _FileStore(this.file);
  @override
  Future<FlagsData?> read(String clientName) async => await file.exists()
      ? FlagsData.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, Object?>,
        )
      : null;
  @override
  Future<void> write(String clientName, FlagsData data) =>
      file.writeAsString(jsonEncode(data.toJson()));
  @override
  Future<void> delete(String clientName) async {
    if (await file.exists()) await file.delete();
  }
}
