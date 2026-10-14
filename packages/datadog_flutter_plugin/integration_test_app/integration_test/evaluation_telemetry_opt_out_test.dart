// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real mobile intake preserves exposures and suppresses automatic RUM',
    (tester) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final events = <String, List<dynamic>>{};
      server.listen((request) async {
        final body = (await RequestLog.fromRequest(request)).data;
        final path = request.uri.path;
        debugPrint('MOBILE INTAKE received $path');
        final recorded = events.putIfAbsent(path, () => []);
        if (path.endsWith('/assignments')) {
          recorded.add(jsonDecode(body));
          request.response.headers.contentType = ContentType.json;
          request.response.write(
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
          );
        } else if (path.endsWith('/evaluations')) {
          recorded.addAll(jsonDecode(body)['flagEvaluations'] as List);
          request.response.statusCode = HttpStatus.accepted;
          request.response.write('{}');
        } else {
          recorded.addAll(
            body.split('\n').where((line) => line.isNotEmpty).map(jsonDecode),
          );
          request.response.statusCode = HttpStatus.accepted;
          request.response.write('{}');
        }
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      final base = 'http://127.0.0.1:${server.port}';
      final sdk = DatadogSdk.instance;
      await sdk.initialize(
        DatadogConfiguration(
          clientToken: 'local-test-token',
          env: 'local-test',
          site: DatadogSite.us1,
          batchSize: BatchSize.small,
          uploadFrequency: UploadFrequency.frequent,
          rumConfiguration: DatadogRumConfiguration(
            applicationId: '00000000-0000-0000-0000-000000000001',
            customEndpoint: '$base/rum',
          ),
        ),
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
        'transition'
      ]) {
        final enabled = scenario != 'disabled';
        final controls = scenario == 'transition'
            ? [false, true, false]
            : [scenario != 'allowed'];
        final flags = DatadogFlags();
        final plugin = DatadogFlagsPlugin(
          sdk,
          flagsConfiguration: DatadogFlagsConfiguration(
            enableEvaluationTelemetryOptOutParameter: enabled,
            customFlagsEndpoint: Uri.parse('$base/$scenario/assignments'),
            customEvaluationEndpoint: Uri.parse('$base/$scenario/evaluations'),
            customExposureEndpoint: Uri.parse('$base/$scenario/exposures'),
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
          expectedRumViews[view] = !(enabled && controls[index]);
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
        final evaluations = events['/$scenario/evaluations'] ?? [];
        expect(evaluations.length, scenario == 'suppressed' ? 0 : 3);
        final count = evaluations.fold<int>(
          0,
          (sum, event) => sum + (event['evaluation_count'] as int),
        );
        expect(count, scenario == 'transition' ? 6 : evaluations.length);
        expect(events['/$scenario/exposures']!.length, 1);
        expect(events['/$scenario/assignments']!.length, 1);
        debugPrint('MOBILE INTAKE $scenario: assignments=1 exposures=1 '
            'evaluation_count=$count');
      }

      // Let the native uploader run without blocking the Flutter platform thread.
      // A synchronous native flush can prevent the in-app intake from replying.
      for (var attempt = 0; attempt < 60; attempt++) {
        await tester.pump(const Duration(milliseconds: 500));
        if ((events['/rum'] ?? []).any(
          (event) =>
              (event['type'] == 'view' || event['type'] == 'view_update') &&
              event['view']['url'] == 'transition-2' &&
              (event['feature_flags'] as Map?)?['manual'] == 'unchanged',
        )) {
          break;
        }
      }
      final rum = events['/rum'] ?? [];
      for (final expected in expectedRumViews.entries) {
        final scenario = expected.key;
        final viewIds = rum
            .where((event) =>
                event['type'] == 'view' && event['view']['name'] == scenario)
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
  );
}
