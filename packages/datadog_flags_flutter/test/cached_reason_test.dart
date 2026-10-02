// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';

void main() {
  test(
    'real core forwards cached and network details with RUM variant',
    () async {
      final h = await Harness.create();
      final rum = <Object>[];
      final wrapper = DatadogFlutterFlagsClient(
        name: 'default',
        resolveDelegate: () async => h.client,
        addRumFeatureFlagEvaluation: (key, value) {
          rum.add([key, value]);
        },
      );
      final pending = wrapper.initialize(Harness.context);
      await h.started.future;
      final cached = wrapper.getBooleanDetails(
        key: 'flag',
        defaultValue: false,
      );
      expect(cached.value, true);
      expect(cached.reason, 'CACHED');
      expect(cached.variant, 'on');
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
        wrapper.getBooleanDetails(key: 'flag', defaultValue: false).reason,
        'TARGETING_MATCH',
      );
      expect(rum, [
        ['flag', 'on'],
        ['flag', 'on'],
      ]);
    },
  );
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
  @override
  Future<FlagsData?> read(String clientName) async => data;
  @override
  Future<void> write(String clientName, FlagsData data) async {
    this.data = data;
  }

  @override
  Future<void> delete(String clientName) async {
    data = null;
  }
}
