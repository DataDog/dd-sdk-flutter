// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  for (final reason in ['TARGETING_MATCH', 'DEFAULT']) {
    test(
      'cached $reason preserves persistence, metrics and exposure dedup',
      () async {
        final h = await Harness.create(reason: reason);
        final original = h.store.data!.toJson();
        final pending = h.client.initialize(Harness.context);
        await h.started.future;
        final details = h.client.getBooleanDetails(
          key: 'flag',
          defaultValue: false,
        );
        expect(details.value, true);
        expect(details.variant, 'on');
        expect(details.reason, 'CACHED');
        expect(h.store.data!.toJson(), original);
        expect(
          h.client.getStringDetails(key: 'flag', defaultValue: '').reason,
          isNull,
        );
        expect(
          h.client
              .getBooleanDetails(key: 'missing', defaultValue: false)
              .reason,
          isNull,
        );
        h.response.complete(
          http.Response(
            jsonEncode({
              'data': {
                'attributes': {'flags': h.store.data!.toJson()['flags']},
              },
            }),
            200,
          ),
        );
        await pending;
        expect(
          h.client.getBooleanDetails(key: 'flag', defaultValue: false).reason,
          reason,
        );
        expect(h.store.data!.flags['flag']!.reason, reason);
        await h.client.shutdown();
        final exposure = h.requests
            .where((r) => r.url.path.contains('exposure'))
            .toList();
        expect(exposure, hasLength(1));
        final evaluations = h.requests.where(
          (r) => r.url.path.contains('flagevaluation'),
        );
        final events = evaluations.expand(
          (r) => (jsonDecode(r.body) as Map)['flagEvaluations'] as List,
        );
        final success = events.cast<Map<String, dynamic>>().firstWhere(
          (e) => e['flag']['key'] == 'flag' && e['error'] == null,
        );
        expect(success['evaluation_count'], 2);
        expect(
          success['runtime_default_used'],
          reason == 'DEFAULT' ? true : null,
        );
        expect(
          success['allocation'],
          reason == 'DEFAULT' ? null : {'key': 'allocation'},
        );
      },
    );
  }

  test(
    'captures cached provenance before dateProvider clears memory',
    () async {
      final h = await Harness.create();
      final pending = h.client.initialize(Harness.context);
      await h.started.future;
      h.onDate = () {
        unawaited(h.client.reset());
      };
      final details = h.client.getBooleanDetails(
        key: 'flag',
        defaultValue: false,
      );
      h.onDate = null;
      expect(details.value, true);
      expect(details.reason, 'CACHED');
      expect(
        h.client.getBooleanDetails(key: 'flag', defaultValue: false).error,
        FlagEvaluationError.providerNotReady,
      );
      h.response.complete(http.Response('{}', 500));
      await pending;
    },
  );

  test(
    'failed refresh retains cached provenance and empty response replaces it',
    () async {
      final h = await Harness.create();
      final pending = h.client.initialize(Harness.context);
      await h.started.future;
      h.response.complete(http.Response('{}', 500));
      await pending;
      expect(
        h.client.getBooleanDetails(key: 'flag', defaultValue: false).reason,
        'CACHED',
      );
      h.response = Completer<http.Response>();
      final next = h.client.initialize(Harness.context);
      h.response.complete(
        http.Response('{"data":{"attributes":{"flags":{}}}}', 200),
      );
      await next;
      final details = h.client.getBooleanDetails(
        key: 'flag',
        defaultValue: false,
      );
      expect(details.error, FlagEvaluationError.flagNotFound);
      expect(details.reason, isNull);
    },
  );

  test('late store read cannot replace an accepted network snapshot', () async {
    final h = await Harness.create();
    final cached = h.store.data;
    h.store.pendingRead = Completer<FlagsData?>();
    final pending = h.client.initialize(Harness.context);
    await h.started.future; // Fetch starts after the 100ms store timeout.
    h.response.complete(
      http.Response(
        jsonEncode({
          'data': {
            'attributes': {'flags': cached!.toJson()['flags']},
          },
        }),
        200,
      ),
    );
    await pending;
    h.store.pendingRead!.complete(cached);
    await Future<void>.delayed(Duration.zero);
    expect(
      h.client.getBooleanDetails(key: 'flag', defaultValue: false).reason,
      'TARGETING_MATCH',
    );
  });

  test(
    'obsolete network completion cannot replace newer cached context',
    () async {
      final h = await Harness.create();
      final oldResponse = h.response;
      final old = h.client.initialize(
        const FlagsEvaluationContext(targetingKey: 'other'),
      );
      await h.started.future;
      h.response = Completer<http.Response>();
      final current = h.client.initialize(Harness.context);
      await Future<void>.delayed(Duration.zero);
      oldResponse.complete(
        http.Response('{"data":{"attributes":{"flags":{}}}}', 200),
      );
      await old;
      expect(
        h.client.getBooleanDetails(key: 'flag', defaultValue: false).reason,
        'CACHED',
      );
      h.response.complete(http.Response('{}', 500));
      await current;
      expect(
        h.client.getBooleanDetails(key: 'flag', defaultValue: false).reason,
        'CACHED',
      );
    },
  );

  test('shutdown clears provenance and cancels the pending refresh', () async {
    final h = await Harness.create();
    final pending = h.client.initialize(Harness.context);
    await h.started.future;
    expect(
      h.client.getBooleanDetails(key: 'flag', defaultValue: false).reason,
      'CACHED',
    );
    await h.client.shutdown();
    h.response.complete(http.Response('{}', 500));
    await pending;
    expect(
      h.client.getBooleanDetails(key: 'flag', defaultValue: false).reason,
      isNull,
    );
  });

  test('mismatched context never installs stored assignments', () async {
    final h = await Harness.create();
    final pending = h.client.initialize(
      const FlagsEvaluationContext(targetingKey: 'other'),
    );
    await h.started.future;
    expect(
      h.client.getBooleanDetails(key: 'flag', defaultValue: false).reason,
      isNull,
    );
    h.response.complete(http.Response('{}', 500));
    await pending;
  });
}

class Harness {
  static const context = FlagsEvaluationContext(targetingKey: 'user');
  final sdk = DatadogFlags();
  final store = Store();
  final started = Completer<void>();
  Completer<http.Response> response = Completer<http.Response>();
  final requests = <http.Request>[];
  void Function()? onDate;
  DatadogFlagsClient get client => sdk.sharedClient();

  static Future<Harness> create({String reason = 'TARGETING_MATCH'}) async {
    final h = Harness();
    h.store.data = FlagsData.fromJson({
      'context': context.toJson(),
      'date': '2026-01-01T00:00:00.000Z',
      'flags': {
        'flag': {
          'allocationKey': 'allocation',
          'variationKey': 'on',
          'variationType': 'boolean',
          'variationValue': true,
          'reason': reason,
          'doLog': true,
          'serialId': 42,
        },
      },
    });
    await h.sdk.enable(
      configuration: DatadogFlagsConfiguration(
        datadogConfig: const DatadogFlagsConfig(
          clientToken: 'token',
          env: 'test',
          site: DatadogFlagsSite.us1,
        ),
        store: h.store,
        dateProvider: () {
          h.onDate?.call();
          return DateTime.utc(2026);
        },
        httpClient: MockClient((r) {
          if (r.url.path.contains('precompute')) {
            if (!h.started.isCompleted) h.started.complete();
            return h.response.future;
          }
          h.requests.add(r);
          return Future.value(http.Response('{}', 202));
        }),
      ),
    );
    addTearDown(h.sdk.disable);
    return h;
  }
}

class Store implements DatadogFlagsStore {
  FlagsData? data;
  Completer<FlagsData?>? pendingRead;
  @override
  Future<FlagsData?> read(String clientName) async =>
      pendingRead == null ? data : await pendingRead!.future;
  @override
  Future<void> write(String clientName, FlagsData data) async {
    this.data = data;
  }

  @override
  Future<void> delete(String clientName) async {
    data = null;
  }
}
