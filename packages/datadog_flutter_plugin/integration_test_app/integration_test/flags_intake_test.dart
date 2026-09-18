// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flags/datadog_flags.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'common.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('flag evaluation intake does not send a CORS preflight request', (
    WidgetTester tester,
  ) async {
    final recordingServer = await startMockServer();
    final flags = DatadogFlags();
    addTearDown(flags.disable);

    await flags.enable(
      configuration: DatadogFlagsConfiguration(
        datadogConfig: const DatadogFlagsConfig(
          clientToken: 'client-token',
          env: 'integration',
          site: DatadogFlagsSite.us1,
          applicationId: 'application-id',
          service: 'integration-service',
          version: '1.2.3',
        ),
        customEvaluationEndpoint: Uri.parse(
          '${recordingServer.sessionEndpoint}api/v2/flagevaluation',
        ),
        trackExposures: false,
      ),
    );

    flags.sharedClient().getBooleanDetails(
          key: 'web-intake-test',
          defaultValue: false,
        );
    await flags.disable();

    final recordedRequests = <RequestLog>[];
    await recordingServer.pollSessionRequests(const Duration(seconds: 15), (
      requests,
    ) {
      recordedRequests.addAll(requests);
      return recordedRequests.any(
        (request) =>
            request.requestedUrl.contains('/api/v2/flagevaluation') &&
            request.requestMethod == 'POST',
      );
    });

    final intakeRequests = recordedRequests
        .where(
          (request) => request.requestedUrl.contains('/api/v2/flagevaluation'),
        )
        .toList();
    debugPrint(
      'Recorded flag evaluation intake methods: '
      '${intakeRequests.map((request) => request.requestMethod).toList()}',
    );
    expect(intakeRequests.map((request) => request.requestMethod), ['POST']);

    final request = intakeRequests.single;
    expect(
      request.requestHeaders['content-type']?.single,
      startsWith('text/plain'),
    );
    expect(request.requestHeaders, isNot(contains('dd-api-key')));
    expect(request.requestHeaders, isNot(contains('dd-evp-origin')));
    expect(request.requestHeaders, isNot(contains('dd-evp-origin-version')));
    expect(request.requestHeaders, isNot(contains('dd-request-id')));
    expect(request.queryParameters['dd-api-key'], 'client-token');
    expect(request.queryParameters['dd-evp-origin'], 'dart-client');
    expect(request.queryParameters['dd-evp-origin-version'], isNotEmpty);
    expect(request.queryParameters['dd-request-id'], isNotEmpty);
    expect(request.queryParameters['ddsource'], 'dart-client');

    final event = jsonDecode(request.data) as Map<String, Object?>;
    expect(event['flag'], {'key': 'web-intake-test'});
    expect(event['runtime_default_used'], isTrue);
    expect(event['error'], {'message': 'PROVIDER_NOT_READY'});
    final context = event['context'] as Map<String, Object?>;
    expect(context['dd'], {
      'env': 'integration',
      'service': 'integration-service',
      'version': '1.2.3',
      'rum': {
        'application': {'id': 'application-id'},
      },
    });
  }, skip: !kIsWeb);
}
