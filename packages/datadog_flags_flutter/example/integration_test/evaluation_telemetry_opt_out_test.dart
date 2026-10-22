// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'common.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'intake preserves exposures and suppresses automatic RUM',
    (tester) async {
      final recordingServer = await startMockServer();
      final transport = http.Client();
      addTearDown(transport.close);
      final events = <String, List<dynamic>>{};
      final httpClient = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/assignments')) {
          final scenario =
              request.url.pathSegments[request.url.pathSegments.length - 2];
          events
              .putIfAbsent('/$scenario/assignments', () => [])
              .add(jsonDecode(request.body));
          return http.Response(
            jsonEncode({
              'data': {
                'attributes': {
                  'flags': {
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
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        // MockClient supplies a finalized request. Forward a fresh request so
        // the real transport can finalize and send the body exactly once.
        final forwarded = http.Request(request.method, request.url)
          ..headers.addAll(request.headers)
          ..bodyBytes = request.bodyBytes;
        return http.Response.fromStream(await transport.send(forwarded));
      });
      final base = recordingServer.sessionEndpoint;
      final sdk = DatadogSdk.instance;
      await sdk.initialize(
        DatadogConfiguration(
          clientToken: 'local-test-token',
          env: 'local-test',
          service: 'flags-telemetry-test',
          site: DatadogSite.us1,
          batchSize: BatchSize.small,
          uploadFrequency: UploadFrequency.frequent,
          rumConfiguration: DatadogRumConfiguration(
            applicationId: '00000000-0000-0000-0000-000000000001',
            customEndpoint: '${base}rum',
          ),
        )..additionalConfig['_dd.needsClearTextHttp'] = true,
        TrackingConsent.granted,
      );
      await tester.pumpWidget(
        const MaterialApp(home: Text('Local telemetry test')),
      );

      final expectedRumViews = <String, bool>{};
      for (final scenario in [
        'disabled',
        'allowed',
        'suppressed',
        'string-true',
        'transition',
      ]) {
        final enabled = scenario != 'disabled';
        final controls = <Object?>[
          if (scenario == 'transition') ...[
            false,
            true,
            false
          ] else if (scenario == 'string-true')
            'true'
          else
            scenario != 'allowed',
        ];
        final flags = DatadogFlags();
        final plugin = DatadogFlagsPlugin(
          sdk,
          flagsConfiguration: DatadogFlagsConfiguration(
            enableEvaluationTelemetryOptOutParameter: enabled,
            customFlagsEndpoint: Uri.parse('$base$scenario/assignments'),
            customEvaluationEndpoint: Uri.parse('$base$scenario/evaluations'),
            customExposureEndpoint: Uri.parse('$base$scenario/exposures'),
            httpClient: httpClient,
          ),
          rumIntegrationEnabled: true,
          flags: flags,
        );
        plugin.initialize();
        await plugin.ready;
        debugPrint('MOBILE INTAKE initializing $scenario');
        final client = plugin.sharedClient();
        for (var index = 0; index < controls.length; index++) {
          final view = controls.length == 1 ? scenario : '$scenario-$index';
          expectedRumViews[view] =
              !(enabled && controls[index] is bool && controls[index] == true);
          await client.initialize(
            FlagsEvaluationContext(
              targetingKey: scenario,
              attributes: {'dd_evaluation_telemetry_opt_out': controls[index]},
            ),
          );
          sdk.rum!.startView(view, view);
          await tester.pump(const Duration(milliseconds: 100));
          final details = client.getBooleanDetails(
            key: 'enabled',
            defaultValue: false,
          );
          expect(details.value, isTrue);
          expect(details.variant, 'on');
          client.getBooleanDetails(key: 'missing', defaultValue: false);
          client.getStringDetails(key: 'enabled', defaultValue: 'fallback');
          sdk.rum!.addFeatureFlagEvaluation('manual', 'unchanged');
          sdk.rum!.addAction(RumActionType.custom, 'unrelated-$view');
          await tester.pump(const Duration(milliseconds: 300));
          sdk.rum!.stopView(view);
        }
        await flags.disable();
        final requests = await recordingServer.fetchRequests(
          recordingServer.currentSession,
        );
        for (final kind in ['evaluations', 'exposures']) {
          events['/$scenario/$kind'] = requests
              .where((request) => Uri.parse(request.requestedUrl)
                  .path
                  .endsWith('/$scenario/$kind'))
              .expand(_decodeEvents)
              .toList();
        }
        final evaluations = events['/$scenario/evaluations'] ?? [];
        expect(evaluations.length, scenario == 'suppressed' ? 0 : 3);
        final count = evaluations.fold<int>(
          0,
          (sum, event) => sum + (event['evaluation_count'] as int),
        );
        expect(count, scenario == 'transition' ? 6 : evaluations.length);
        expect(events['/$scenario/exposures']!.length, 1);
        expect(events['/$scenario/assignments']!.length, controls.length);
        for (var index = 0; index < controls.length; index++) {
          expect(
            events['/$scenario/assignments']![index]['data']['attributes']
                ['subject']['targeting_attributes'],
            {'dd_evaluation_telemetry_opt_out': controls[index]},
          );
        }
        expect(
          events['/$scenario/exposures']!.single['subject']['attributes'],
          {'dd_evaluation_telemetry_opt_out': controls.first},
        );
        debugPrint(
          'MOBILE INTAKE $scenario: assignments=${controls.length} exposures=1 '
          'evaluation_count=$count',
        );
      }

      await recordingServer.pollSessionRequests(const Duration(seconds: 30), (
        requests,
      ) {
        events.putIfAbsent('/rum', () => []).addAll(
              requests
                  .where((request) =>
                      Uri.parse(request.requestedUrl).path.endsWith('/rum'))
                  .expand(_decodeEvents),
            );
        return (events['/rum'] ?? []).any(
          (event) =>
              (event['type'] == 'view' || event['type'] == 'view_update') &&
              event['view']['url'] == 'transition-2' &&
              (event['feature_flags'] as Map?)?['manual'] == 'unchanged',
        );
      });
      final rum = events['/rum'] ?? [];
      for (final expected in expectedRumViews.entries) {
        final scenario = expected.key;
        final viewIds = rum
            .where(
              (event) =>
                  event['type'] == 'view' && event['view']['name'] == scenario,
            )
            .map((event) => event['view']['id']);
        final views = rum
            .where(
              (event) =>
                  (event['type'] == 'view' || event['type'] == 'view_update') &&
                  viewIds.contains(event['view']['id']),
            )
            .toList();
        expect(
          views,
          isNotEmpty,
          reason: 'Native RUM intake must emit $scenario views.',
        );
        final annotated = views.where(
          (event) => (event['feature_flags'] as Map?)?['enabled'] == 'on',
        );
        expect(annotated, expected.value ? isNotEmpty : isEmpty);
        expect(
          views.any(
            (event) =>
                (event['feature_flags'] as Map?)?['manual'] == 'unchanged',
          ),
          isTrue,
        );
        expect(
          rum.any(
            (event) =>
                event['type'] == 'action' &&
                event['action']['target']['name'] == 'unrelated-$scenario',
          ),
          isTrue,
        );
        debugPrint(
          'MOBILE INTAKE $scenario: '
          'automatic_rum=${annotated.length} manual_rum=true unrelated_action=true',
        );
      }
    },
    skip: kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS),
  );
}

Iterable<dynamic> _decodeEvents(RequestLog request) sync* {
  for (final line
      in request.data.split('\n').where((line) => line.isNotEmpty)) {
    final decoded = jsonDecode(line);
    if (decoded is List) {
      yield* decoded;
    } else if (decoded is Map && decoded.containsKey('flagEvaluations')) {
      yield* decoded['flagEvaluations'] as List;
    } else {
      yield decoded;
    }
  }
}
