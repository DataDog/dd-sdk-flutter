// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/flags_store.dart'
    show InMemoryDatadogFlagsStore;
import 'package:test/test.dart';

void main() {
  test(
    'disabled opt-out emits evaluations and exposures over real HTTP',
    () async {
      final intake = await _Intake.start();
      addTearDown(intake.close);
      final sdk = DatadogFlags();
      addTearDown(sdk.disable);
      await sdk.enable(configuration: intake.configuration());
      final client = sdk.sharedClient();
      await client.initialize(
        const FlagsEvaluationContext(
          targetingKey: 'baseline',
          attributes: {'dd_evaluation_telemetry_opt_out': true},
        ),
      );
      final details = client.getBooleanDetails(
        key: 'enabled',
        defaultValue: false,
      );
      expect(details.value, isTrue);
      expect(details.variant, 'on');
      await sdk.disable();
      expect(intake.assignments, hasLength(1));
      expect(intake.evaluations, hasLength(1));
      expect(intake.evaluations.single['evaluation_count'], 1);
      expect(intake.exposures, hasLength(1));
      expect(
        intake
            .assignments
            .single['data']['attributes']['subject']['targeting_attributes']['dd_evaluation_telemetry_opt_out'],
        isTrue,
      );
      print(
        'HTTP baseline: assignments=1 evaluation_count=1 exposures=1 value=true',
      );
    },
  );

  for (final control in <Object?>[false, null, 'true', 1, [], {}, true]) {
    test('only boolean true suppresses HTTP telemetry: $control', () async {
      final intake = await _Intake.start();
      addTearDown(intake.close);
      final sdk = DatadogFlags();
      addTearDown(sdk.disable);
      await sdk.enable(configuration: intake.configuration(enabled: true));
      final client = sdk.sharedClient();
      await client.initialize(_context(control));
      expect(
        client.getBooleanDetails(key: 'enabled', defaultValue: false).value,
        isTrue,
      );
      client.getBooleanDetails(key: 'enabled', defaultValue: false);
      expect(
        client.getBooleanDetails(key: 'missing', defaultValue: false).error,
        FlagEvaluationError.flagNotFound,
      );
      expect(
        client.getStringDetails(key: 'enabled', defaultValue: 'fallback').value,
        'fallback',
      );
      final fallback = client.getBooleanDetails(
        key: 'default',
        defaultValue: false,
      );
      expect(fallback.value, isTrue);
      expect(fallback.reason, 'DEFAULT');
      await sdk.disable();
      final suppressed = control is bool && control;
      expect(intake.evaluationCount, suppressed ? 0 : 5);
      expect(intake.exposures, hasLength(1));
      expect(
        intake
            .assignments
            .single['data']['attributes']['subject']['targeting_attributes'],
        {'ordinary': 'attribute'},
      );
    });
  }

  test(
    'control transitions preserve values, queued counts and exposure deduplication',
    () async {
      final intake = await _Intake.start();
      addTearDown(intake.close);
      final sdk = DatadogFlags();
      addTearDown(sdk.disable);
      await sdk.enable(configuration: intake.configuration(enabled: true));
      final client = sdk.sharedClient();
      await client.initialize(_context(false));
      final before = client.getBooleanDetails(
        key: 'enabled',
        defaultValue: false,
      );
      await client.initialize(_context(true));
      final suppressed = client.getBooleanDetails(
        key: 'enabled',
        defaultValue: false,
      );
      await client.initialize(_context(false));
      final after = client.getBooleanDetails(
        key: 'enabled',
        defaultValue: false,
      );
      expect([before.value, suppressed.value, after.value], [true, true, true]);
      expect(
        [before.variant, suppressed.variant, after.variant],
        ['on', 'on', 'on'],
      );
      expect(intake.assignments, hasLength(1));
      await sdk.disable();
      expect(intake.evaluationCount, 2);
      expect(intake.exposures, hasLength(1));
      print('HTTP transitions: assignments=1 evaluation_count=2 exposures=1');
    },
  );

  test(
    'missing control and genuine targeting changes keep evaluation behavior',
    () async {
      final intake = await _Intake.start();
      addTearDown(intake.close);
      final sdk = DatadogFlags();
      addTearDown(sdk.disable);
      await sdk.enable(configuration: intake.configuration(enabled: true));
      final client = sdk.sharedClient();
      await client.initialize(
        const FlagsEvaluationContext(targetingKey: 'user'),
      );
      client.getBooleanDetails(key: 'enabled', defaultValue: false);
      await client.initialize(
        const FlagsEvaluationContext(targetingKey: 'other'),
      );
      client.getBooleanDetails(key: 'enabled', defaultValue: false);
      await client.initialize(
        const FlagsEvaluationContext(targetingKey: 'other'),
      );
      expect(
        intake.assignments,
        hasLength(3),
        reason: 'Explicit refresh remains supported.',
      );
      await sdk.disable();
      expect(intake.evaluationCount, 2);
      expect(intake.exposures, hasLength(2));
    },
  );

  test(
    'pending response cannot restore the previous telemetry policy',
    () async {
      final intake = await _Intake.start();
      addTearDown(intake.close);
      final release = Completer<void>();
      intake.assignmentWait = release.future;
      final sdk = DatadogFlags();
      addTearDown(sdk.disable);
      await sdk.enable(configuration: intake.configuration(enabled: true));
      final client = sdk.sharedClient();
      final pending = client.initialize(_context(false));
      await intake.assignmentStarted.future;
      await client.initialize(_context(true));
      expect(
        client.getBooleanDetails(key: 'enabled', defaultValue: false).error,
        FlagEvaluationError.providerNotReady,
      );
      release.complete();
      await pending;
      expect(
        client.getBooleanDetails(key: 'enabled', defaultValue: false).value,
        isTrue,
      );
      await sdk.disable();
      expect(intake.assignments, hasLength(1));
      expect(intake.evaluationCount, 0);
      expect(intake.exposures, hasLength(1));
    },
  );

  test(
    'failed loading keeps local policy and supports resuming telemetry',
    () async {
      final intake = await _Intake.start();
      addTearDown(intake.close);
      intake.assignmentStatus = 400;
      final sdk = DatadogFlags();
      addTearDown(sdk.disable);
      await sdk.enable(configuration: intake.configuration(enabled: true));
      final client = sdk.sharedClient();
      await client.initialize(_context(true));
      client.getBooleanDetails(key: 'enabled', defaultValue: false);
      await client.initialize(_context(false));
      client.getBooleanDetails(key: 'enabled', defaultValue: false);
      await sdk.disable();
      expect(intake.assignments, hasLength(1));
      expect(intake.evaluationCount, 1);
      expect(intake.evaluations.single['error'], {
        'message': 'PROVIDER_NOT_READY',
      });
      expect(intake.exposures, isEmpty);
    },
  );

  test(
    'cached contexts cannot restore policy and named clients remain independent',
    () async {
      final intake = await _Intake.start();
      addTearDown(intake.close);
      final store = InMemoryDatadogFlagsStore();
      final first = DatadogFlags();
      await first.enable(configuration: intake.configuration(store: store));
      await first.sharedClient().initialize(_context(false));
      await first.disable();
      final release = Completer<void>();
      intake.assignmentWait = release.future;
      intake.assignmentStarted = Completer<void>();
      final sdk = DatadogFlags();
      addTearDown(sdk.disable);
      await sdk.enable(
        configuration: intake.configuration(enabled: true, store: store),
      );
      final client = sdk.sharedClient();
      final pending = client.initialize(_context(true));
      await intake.assignmentStarted.future;
      final cached = client.getBooleanDetails(
        key: 'enabled',
        defaultValue: false,
      );
      expect(cached.value, isTrue);
      expect(cached.variant, 'on');
      release.complete();
      await pending;
      final other = sdk.sharedClient(name: 'other');
      await other.initialize(_context(false));
      other.getBooleanDetails(key: 'enabled', defaultValue: false);
      client.getBooleanDetails(key: 'enabled', defaultValue: false);
      await sdk.disable();
      expect(intake.assignments, hasLength(3));
      expect(intake.evaluationCount, 1);
      expect(intake.exposures, hasLength(2));
    },
  );
}

FlagsEvaluationContext _context(Object? control) => FlagsEvaluationContext(
  targetingKey: 'user',
  attributes: {
    'ordinary': 'attribute',
    'dd_evaluation_telemetry_opt_out': control,
  },
);

class _Intake {
  final HttpServer server;
  final assignments = <dynamic>[];
  final evaluations = <dynamic>[];
  final exposures = <dynamic>[];
  Future<void>? assignmentWait;
  Completer<void> assignmentStarted = Completer<void>();
  int assignmentStatus = 200;

  int get evaluationCount => evaluations.fold<int>(
    0,
    (count, event) => count + (event['evaluation_count'] as int),
  );

  _Intake(this.server);

  static Future<_Intake> start() async {
    final intake = _Intake(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    intake.server.listen(intake._handle);
    return intake;
  }

  DatadogFlagsConfiguration configuration({
    bool enabled = false,
    DatadogFlagsStore? store,
  }) => DatadogFlagsConfiguration(
    datadogConfig: const DatadogFlagsConfig(
      clientToken: 'local-test-token',
      env: 'local-test',
      site: DatadogFlagsSite.us1,
    ),
    customFlagsEndpoint: endpoint('/assignments'),
    customExposureEndpoint: endpoint('/exposures'),
    customEvaluationEndpoint: endpoint('/evaluations'),
    enableEvaluationTelemetryOptOutParameter: enabled,
    store: store,
  );

  Uri endpoint(String path) =>
      Uri.parse('http://127.0.0.1:${server.port}$path');

  Future<void> _handle(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    if (request.uri.path == '/assignments') {
      assignments.add(jsonDecode(body));
      if (!assignmentStarted.isCompleted) assignmentStarted.complete();
      await assignmentWait;
      request.response.statusCode = assignmentStatus;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'data': {
            'attributes': {
              'flags': {
                'default': {
                  'allocationKey': 'default',
                  'variationKey': 'on',
                  'variationType': 'boolean',
                  'variationValue': true,
                  'reason': 'DEFAULT',
                  'doLog': false,
                },
                'enabled': {
                  'allocationKey': 'allocation',
                  'variationKey': 'on',
                  'variationType': 'boolean',
                  'variationValue': true,
                  'reason': 'TARGETING_MATCH',
                  'doLog': true,
                },
              },
            },
          },
        }),
      );
    } else if (request.uri.path == '/evaluations') {
      evaluations.addAll(jsonDecode(body)['flagEvaluations'] as List);
    } else if (request.uri.path == '/exposures') {
      exposures.addAll(body.split('\n').map(jsonDecode));
    }
    await request.response.close();
  }

  Future<void> close() => server.close(force: true);
}
