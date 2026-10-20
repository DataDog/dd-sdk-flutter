// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/flags_store.dart'
    show InMemoryDatadogFlagsStore;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  for (final status in [200, 400]) {
    test('subject opt-out remains active during B refresh ($status)', () async {
      final intake = await _Intake.start();
      addTearDown(intake.close);
      final sdk = DatadogFlags();
      addTearDown(sdk.disable);
      await sdk.enable(configuration: intake.configuration(enabled: true));
      final client = sdk.sharedClient();
      await client.initialize(_context(true, subject: 'A'));
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      intake.assignmentWait = release.future;
      intake.assignmentStarted = Completer<void>();
      intake.assignmentStatus = status;
      final pending = client.initialize(_context(false, subject: 'B'));
      await intake.assignmentStarted.future;
      expect(
        client.getBooleanDetails(key: 'enabled', defaultValue: false).value,
        isTrue,
      );
      expect(
        client.getBooleanDetails(key: 'enabled', defaultValue: false).value,
        isTrue,
      );
      release.complete();
      await pending;
      if (status == 200) {
        expect(
          client.getBooleanDetails(key: 'enabled', defaultValue: false).value,
          isTrue,
        );
      }
      await sdk.disable();
      expect(intake.evaluationCount, status == 200 ? 1 : 0);
      expect(intake.exposures, hasLength(status == 200 ? 2 : 1));
    });
  }

  test('subject opt-in survives switching to B before its refresh', () async {
    final intake = await _Intake.start();
    addTearDown(intake.close);
    final sdk = DatadogFlags();
    addTearDown(sdk.disable);
    await sdk.enable(configuration: intake.configuration(enabled: true));
    final client = sdk.sharedClient();
    await client.initialize(_context(true, subject: 'A'));
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    intake.assignmentWait = release.future;
    final first = client.initialize(_context(false, subject: 'A'));
    final second = client.initialize(_context(false, subject: 'B'));
    expect(
      client.getBooleanDetails(key: 'enabled', defaultValue: false).value,
      isTrue,
    );
    release.complete();
    await Future.wait([first, second]);
    await sdk.disable();
    expect(intake.evaluationCount, 1);
    expect(intake.exposures, hasLength(1));
  });

  test(
    'disabled opt-out emits evaluations and exposures through the HTTP client',
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
        'Baseline: assignments=1 evaluation_count=1 exposures=1 value=true',
      );
    },
  );

  for (final enabled in [false, true]) {
    test(
      'attribute targets assignments and exposures with activation $enabled',
      () async {
        final intake = await _Intake.start();
        addTearDown(intake.close);
        final sdk = DatadogFlags();
        addTearDown(sdk.disable);
        await sdk.enable(configuration: intake.configuration(enabled: enabled));
        final client = sdk.sharedClient();
        for (final control in [false, true, false]) {
          await client.initialize(_context(control));
          final details = client.getBooleanDetails(
            key: 'targeted',
            defaultValue: false,
          );
          expect(details.value, control);
          expect(details.variant, control ? 'on' : 'off');
          expect(details.reason, 'TARGETING_MATCH');
          // Repeated evaluation uses the ordinary exposure deduplication rule.
          client.getBooleanDetails(key: 'targeted', defaultValue: false);
        }
        await sdk.disable();
        expect(intake.assignments, hasLength(3));
        expect(intake.exposures, hasLength(3));
        expect(intake.evaluationCount, enabled ? 4 : 6);
        for (var index = 0; index < 3; index++) {
          final attributes = _context([false, true, false][index]).attributes;
          expect(
            intake
                .assignments[index]['data']['attributes']['subject']['targeting_attributes'],
            attributes,
          );
          expect(intake.exposures[index]['subject']['attributes'], attributes);
        }
      },
    );
  }

  for (final control in <Object?>[false, null, 'true', 1, [], {}, true]) {
    test(
      'only boolean true suppresses evaluation telemetry: $control',
      () async {
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
          client
              .getStringDetails(key: 'enabled', defaultValue: 'fallback')
              .value,
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
          {
            'ordinary': 'attribute',
            'dd_evaluation_telemetry_opt_out': control is List || control is Map
                ? jsonEncode(control)
                : control,
          },
        );
        expect(
          intake.exposures.single['subject']['attributes'],
          _context(control).attributes,
        );
      },
    );
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
      expect(intake.assignments, hasLength(3));
      await sdk.disable();
      expect(intake.evaluationCount, 2);
      expect(intake.exposures, hasLength(1));
      print('Transitions: assignments=3 evaluation_count=2 exposures=1');
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
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      intake.assignmentWait = release.future;
      final sdk = DatadogFlags();
      addTearDown(sdk.disable);
      await sdk.enable(configuration: intake.configuration(enabled: true));
      final client = sdk.sharedClient();
      final pending = client.initialize(_context(false));
      await intake.assignmentStarted.future;
      intake.assignmentWait = null;
      await client.initialize(_context(true));
      expect(
        client.getBooleanDetails(key: 'enabled', defaultValue: false).value,
        isTrue,
      );
      release.complete();
      await pending;
      expect(
        client.getBooleanDetails(key: 'enabled', defaultValue: false).value,
        isTrue,
      );
      await sdk.disable();
      expect(intake.assignments, hasLength(2));
      expect(intake.evaluationCount, 0);
      expect(intake.exposures, hasLength(1));
    },
  );

  test(
    'failed loading keeps current policy and supports resuming telemetry',
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
      expect(intake.assignments, hasLength(2));
      expect(intake.evaluationCount, 1);
      expect(intake.evaluations.single['error'], {
        'message': 'PROVIDER_NOT_READY',
      });
      expect(intake.exposures, isEmpty);
    },
  );

  test(
    'matching cached contexts retain the attribute and named clients remain independent',
    () async {
      final intake = await _Intake.start();
      addTearDown(intake.close);
      final store = InMemoryDatadogFlagsStore();
      final first = DatadogFlags();
      await first.enable(configuration: intake.configuration(store: store));
      await first.sharedClient().initialize(_context(true));
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
      expect(cached.reason, 'CACHED');
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
      expect(
        intake.exposures.first['subject']['attributes'],
        _context(true).attributes,
      );
      expect(
        (await store.read('default'))!.context.attributes,
        _context(true).attributes,
      );
    },
  );

  test('different attribute values do not match stored assignments', () async {
    final intake = await _Intake.start();
    addTearDown(intake.close);
    final store = InMemoryDatadogFlagsStore();
    final first = DatadogFlags();
    await first.enable(
      configuration: intake.configuration(enabled: true, store: store),
    );
    await first.sharedClient().initialize(_context(false));
    await first.disable();
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
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
    expect(intake.evaluationCount, 0);
    expect(
      intake.exposures.single['subject']['attributes'],
      _context(true).attributes,
    );
  });

  for (final control in [false, true]) {
    for (final status in [200, 400]) {
      test(
        'current control $control applies during refresh and response $status',
        () async {
          final intake = await _Intake.start();
          addTearDown(intake.close);
          final sdk = DatadogFlags();
          addTearDown(sdk.disable);
          await sdk.enable(configuration: intake.configuration(enabled: true));
          final client = sdk.sharedClient();
          await client.initialize(_context(!control));
          final release = Completer<void>();
          addTearDown(() {
            if (!release.isCompleted) release.complete();
          });
          intake.assignmentWait = release.future;
          intake.assignmentStarted = Completer<void>();
          intake.assignmentStatus = status;
          final pending = client.initialize(_context(control));
          // Current consent applies before the request completes.
          expect(
            client.getBooleanDetails(key: 'enabled', defaultValue: false).value,
            isTrue,
          );
          await intake.assignmentStarted.future;
          release.complete();
          await pending;
          final details = client.getBooleanDetails(
            key: 'enabled',
            defaultValue: false,
          );
          expect(
            details.error,
            status == 200 ? isNull : FlagEvaluationError.providerNotReady,
          );
          await sdk.disable();
          expect(intake.assignments, hasLength(2));
          expect(intake.evaluationCount, control ? 0 : 2);
          expect(intake.exposures, hasLength(1));
          expect(
            intake.exposures.single['subject']['attributes'],
            _context(!control).attributes,
          );
        },
      );
    }
  }

  test(
    'exposure tracking remains disabled when the attribute is present',
    () async {
      final intake = await _Intake.start();
      addTearDown(intake.close);
      final sdk = DatadogFlags();
      addTearDown(sdk.disable);
      await sdk.enable(
        configuration: intake.configuration(
          enabled: true,
          trackExposures: false,
        ),
      );
      final client = sdk.sharedClient();
      await client.initialize(_context(true));
      expect(
        client.getBooleanDetails(key: 'targeted', defaultValue: false).value,
        isTrue,
      );
      await sdk.disable();
      expect(intake.exposures, isEmpty);
      expect(intake.evaluationCount, 0);
    },
  );
}

FlagsEvaluationContext _context(Object? control, {String subject = 'user'}) =>
    FlagsEvaluationContext(
      targetingKey: subject,
      attributes: {
        'ordinary': 'attribute',
        'dd_evaluation_telemetry_opt_out': control,
      },
    );

class _Intake {
  late final http.Client client = MockClient(_handle);
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

  static Future<_Intake> start() async => _Intake();

  DatadogFlagsConfiguration configuration({
    bool enabled = false,
    bool trackExposures = true,
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
    trackExposures: trackExposures,
    store: store,
    httpClient: client,
  );

  Uri endpoint(String path) => Uri.parse('https://flags.test$path');

  Future<http.Response> _handle(http.Request request) async {
    final body = request.body;
    if (request.url.path == '/assignments') {
      final assignment = jsonDecode(body);
      assignments.add(assignment);
      final control =
          assignment['data']['attributes']['subject']['targeting_attributes']['dd_evaluation_telemetry_opt_out'];
      final targeted = control is bool && control;
      if (!assignmentStarted.isCompleted) assignmentStarted.complete();
      await assignmentWait;
      return http.Response(
        jsonEncode({
          'data': {
            'attributes': {
              'flags': {
                'targeted': {
                  'allocationKey': 'allocation',
                  'variationKey': targeted ? 'on' : 'off',
                  'variationType': 'boolean',
                  'variationValue': targeted,
                  'reason': 'TARGETING_MATCH',
                  'doLog': true,
                },
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
        assignmentStatus,
        headers: {'content-type': 'application/json'},
      );
    } else if (request.url.path == '/evaluations') {
      for (final line in body.split('\n').where((line) => line.isNotEmpty)) {
        final decoded = jsonDecode(line);
        evaluations.addAll(
          decoded.containsKey('flagEvaluations')
              ? decoded['flagEvaluations'] as List
              : [decoded],
        );
      }
    } else if (request.url.path == '/exposures') {
      exposures.addAll(body.split('\n').map(jsonDecode));
    }
    return http.Response('{}', 202);
  }

  void close() => client.close();
}
