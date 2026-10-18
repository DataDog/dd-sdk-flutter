// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:test/test.dart';

void main() {
  for (final enabled in [false, true]) {
    test('real HTTP preserves exposures with activation $enabled', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requests = <String, List<dynamic>>{};
      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        final path = request.uri.path;
        final recorded = requests.putIfAbsent(path, () => []);
        request.response.headers.contentType = ContentType.json;
        if (path == '/assignments') {
          recorded.add(jsonDecode(body));
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
        } else if (path == '/evaluations') {
          recorded.addAll(jsonDecode(body)['flagEvaluations'] as List);
        } else {
          recorded.addAll(body.split('\n').map(jsonDecode));
        }
        await request.response.close();
      });
      final base = 'http://127.0.0.1:${server.port}';
      final sdk = DatadogFlags();
      addTearDown(sdk.disable);
      await sdk.enable(
        configuration: DatadogFlagsConfiguration(
          datadogConfig: const DatadogFlagsConfig(
            clientToken: 'local-test-token',
            env: 'local-test',
            site: DatadogFlagsSite.us1,
          ),
          customFlagsEndpoint: Uri.parse('$base/assignments'),
          customEvaluationEndpoint: Uri.parse('$base/evaluations'),
          customExposureEndpoint: Uri.parse('$base/exposures'),
          enableEvaluationTelemetryOptOutParameter: enabled,
        ),
      );
      final client = sdk.sharedClient();
      await client.initialize(
        const FlagsEvaluationContext(
          targetingKey: 'subject',
          attributes: {'dd_evaluation_telemetry_opt_out': true},
        ),
      );
      expect(
        client.getBooleanDetails(key: 'enabled', defaultValue: false).value,
        isTrue,
      );
      await sdk.disable();
      expect(requests['/assignments'], hasLength(1));
      expect(requests['/exposures'], hasLength(1));
      expect(requests['/evaluations'] ?? [], hasLength(enabled ? 0 : 1));
      expect(
        requests['/assignments']!
            .single['data']['attributes']['subject']['targeting_attributes']['dd_evaluation_telemetry_opt_out'],
        isTrue,
      );
      expect(
        requests['/exposures']!
            .single['subject']['attributes']['dd_evaluation_telemetry_opt_out'],
        isTrue,
      );
    });
  }
}
