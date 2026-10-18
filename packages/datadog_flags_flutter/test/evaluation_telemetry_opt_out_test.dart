// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final enabled in [false, true]) {
    for (final control in <Object?>[null, false, 'true', 1, [], {}, true]) {
      test(
        'RUM uses explicit option $enabled and strict control $control',
        () async {
          final h = await _Harness.create(enabled: enabled);
          addTearDown(h.sdk.disable);
          await h.client.initialize(_context(control));
          expect(
            h.client.getBooleanDetails(key: 'flag', defaultValue: false).value,
            isTrue,
          );
          h.client.getBooleanDetails(key: 'missing', defaultValue: false);
          h.client.getStringDetails(key: 'flag', defaultValue: 'fallback');
          expect(
            h.rum,
            enabled && control is bool && control ? isEmpty : ['on'],
          );
          await h.sdk.disable();
          expect(h.requestedAttributes.single, {
            'dd_evaluation_telemetry_opt_out': control is List || control is Map
                ? jsonEncode(control)
                : control,
          });
          expect(
            h.exposures.single['subject']['attributes'],
            _context(control).attributes,
          );
          expect(
            h.evaluationCount,
            enabled && control is bool && control ? 0 : 3,
          );
        },
      );
    }
  }

  test(
    'RUM policy changes immediately while assignments remain pending',
    () async {
      final h = await _Harness.create(enabled: true);
      addTearDown(h.sdk.disable);
      await h.client.initialize(_context(false));
      h.client.getBooleanDetails(key: 'flag', defaultValue: false);
      h.wait = Completer<void>();
      h.started = Completer<void>();
      final refresh = h.client.initialize(_context(false));
      await h.started.future;
      final update = h.client.initialize(_context(true));
      h.client.getBooleanDetails(key: 'flag', defaultValue: false);
      h.wait!.complete();
      await Future.wait([refresh, update]);
      h.client.getBooleanDetails(key: 'flag', defaultValue: false);
      await h.client.initialize(_context(false));
      h.client.getBooleanDetails(key: 'flag', defaultValue: false);
      expect(h.rum, ['on', 'on']);
      expect(h.assignmentRequests, 4);
    },
  );

  for (final control in [false, true]) {
    test('RUM uses current control $control during a failed refresh', () async {
      final h = await _Harness.create(enabled: true);
      addTearDown(h.sdk.disable);
      await h.client.initialize(_context(!control));
      h.wait = Completer<void>();
      addTearDown(() {
        if (!h.wait!.isCompleted) h.wait!.complete();
      });
      h.started = Completer<void>();
      h.assignmentStatus = 400;
      final refresh = h.client.initialize(_context(control));
      expect(
        h.client.getBooleanDetails(key: 'flag', defaultValue: false).value,
        isTrue,
      );
      await h.started.future;
      h.wait!.complete();
      await refresh;
      expect(
        h.client.getBooleanDetails(key: 'flag', defaultValue: false).error,
        FlagEvaluationError.providerNotReady,
      );
      await h.sdk.disable();
      expect(h.rum, control ? isEmpty : ['on']);
      expect(h.evaluationCount, control ? 0 : 2);
      expect(h.assignmentRequests, 2);
      expect(h.exposures, hasLength(1));
    });
  }

  for (final latestControl in [false, true]) {
    test(
      'late delegate resolution keeps latest policy $latestControl',
      () async {
        final h = await _Harness.create(enabled: true);
        addTearDown(h.sdk.disable);
        final firstResolution = Completer<DatadogFlagsClient>();
        var resolutions = 0;
        h.client = DatadogFlutterFlagsClient(
          name: 'default',
          resolveDelegate: () {
            resolutions++;
            return resolutions == 1
                ? firstResolution.future
                : Future.value(h.sdk.sharedClient());
          },
          enableEvaluationTelemetryOptOutParameter: true,
          addRumFeatureFlagEvaluation: (key, value) => h.rum.add(value),
        );
        final earlier = h.client.initialize(_context(!latestControl));
        final latest = h.client.initialize(_context(latestControl));
        await Future<void>.delayed(Duration.zero);
        firstResolution.complete(h.sdk.sharedClient());
        await Future.wait([earlier, latest]);
        h.client.getBooleanDetails(key: 'flag', defaultValue: false);
        await h.sdk.disable();
        expect(resolutions, 1);
        expect(h.assignmentRequests, 1);
        expect(h.rum, latestControl ? isEmpty : ['on']);
        expect(h.evaluationCount, latestControl ? 0 : 1);
      },
    );
  }

  test(
    'ready client updates core and RUM policy before returning its future',
    () async {
      final h = await _Harness.create(enabled: true);
      addTearDown(h.sdk.disable);
      await h.client.initialize(_context(false));
      final update = h.client.initialize(_context(true));
      h.client.getBooleanDetails(key: 'flag', defaultValue: false);
      await update;
      await h.sdk.disable();
      expect(h.rum, isEmpty);
      expect(h.evaluationCount, 0);
      expect(h.assignmentRequests, 2);
    },
  );

  test('named wrappers retain separate telemetry policies', () async {
    final h = await _Harness.create(enabled: true);
    addTearDown(h.sdk.disable);
    final other = DatadogFlutterFlagsClient(
      name: 'other',
      resolveDelegate: () async => h.sdk.sharedClient(name: 'other'),
      enableEvaluationTelemetryOptOutParameter: true,
      addRumFeatureFlagEvaluation: (key, value) => h.rum.add(value),
    );
    await h.client.initialize(_context(true));
    await other.initialize(_context(false));
    h.client.getBooleanDetails(key: 'flag', defaultValue: false);
    other.getBooleanDetails(key: 'flag', defaultValue: false);
    await h.sdk.disable();
    expect(h.rum, ['on']);
    expect(h.evaluationCount, 1);
    expect(h.assignmentRequests, 2);
  });
}

FlagsEvaluationContext _context(Object? control) => FlagsEvaluationContext(
  targetingKey: 'user',
  attributes: {'dd_evaluation_telemetry_opt_out': control},
);

class _Harness {
  final sdk = DatadogFlags();
  final rum = <Object>[];
  late DatadogFlutterFlagsClient client;
  Completer<void>? wait;
  Completer<void> started = Completer<void>();
  int assignmentRequests = 0;
  int evaluationCount = 0;
  int assignmentStatus = 200;
  final requestedAttributes = <dynamic>[];
  final exposures = <dynamic>[];

  static Future<_Harness> create({required bool enabled}) async {
    final h = _Harness();
    await h.sdk.enable(
      configuration: DatadogFlagsConfiguration(
        datadogConfig: const DatadogFlagsConfig(
          clientToken: 'local-token',
          env: 'test',
          site: DatadogFlagsSite.us1,
        ),
        enableEvaluationTelemetryOptOutParameter: enabled,
        httpClient: MockClient((request) async {
          if (!request.url.path.contains('precompute')) {
            if (request.url.path.contains('evaluation')) {
              for (final line in request.body.split('\n')) {
                final decoded = jsonDecode(line);
                final evaluations = decoded.containsKey('flagEvaluations')
                    ? decoded['flagEvaluations'] as List
                    : [decoded];
                for (final evaluation in evaluations) {
                  h.evaluationCount += evaluation['evaluation_count'] as int;
                }
              }
            } else if (request.url.path.contains('exposures')) {
              h.exposures.addAll(request.body.split('\n').map(jsonDecode));
            }
            return http.Response('{}', 202);
          }
          h.assignmentRequests++;
          h.requestedAttributes.add(
            jsonDecode(
              request.body,
            )['data']['attributes']['subject']['targeting_attributes'],
          );
          if (!h.started.isCompleted) h.started.complete();
          await h.wait?.future;
          return http.Response(
            jsonEncode({
              'data': {
                'attributes': {
                  'flags': {
                    'flag': {
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
            h.assignmentStatus,
          );
        }),
      ),
    );
    h.client = DatadogFlutterFlagsClient(
      name: 'default',
      resolveDelegate: () async => h.sdk.sharedClient(),
      enableEvaluationTelemetryOptOutParameter: enabled,
      addRumFeatureFlagEvaluation: (key, value) => h.rum.add(value),
    );
    return h;
  }
}
