// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test_app/flags/forwarding_flags_counter.dart';

void main() {
  test('forwarding counter records flag request attempts and forwards them',
      () async {
    final forwarded = <http.Request>[];
    final precomputeResponseBody = jsonEncode({
      'data': {
        'attributes': {
          'flags': {
            'flag-a': {},
            'flag-b': {},
          },
        },
      },
    });
    final client = CountingFlagsHttpClient(MockClient((request) async {
      forwarded.add(request);
      if (request.url.path == '/precompute-assignments') {
        return http.Response(precomputeResponseBody, 200);
      }
      return http.Response('{}', 202);
    }));

    await client.post(
      Uri.https(
        'preview.ff-cdn.datad0g.com',
        '/precompute-assignments',
      ),
      body: '{}',
    );
    await client.post(
      Uri.https(
        'browser-intake-datad0g.com',
        '/api/v2/exposures',
        {'ddsource': 'flutter'},
      ),
      body: '{"flag":{"key":"flag-a"}}',
    );
    await client.post(
      Uri.https(
        'browser-intake-datad0g.com',
        '/api/v2/flagevaluation',
        {'ddsource': 'flutter'},
      ),
      body: jsonEncode({
        'flagEvaluations': [
          {'flag_key': 'flag-a'},
          {'flag_key': 'flag-b'},
        ],
      }),
    );

    expect(forwarded, hasLength(3));
    expect(client.precomputeRequestCount, 1);
    expect(client.lastPrecomputeFlagCount, 2);
    expect(client.lastPrecomputePayloadBytes,
        utf8.encode(precomputeResponseBody).length);
    expect(client.exposureCount, 1);
    expect(client.evaluationRequestCount, 1);
    expect(client.evaluationEventCount, 2);
  });

  test('forwarding counter records assignment fetch timing diagnostics',
      () async {
    final counter = ForwardingFlagsCounter.create();
    addTearDown(counter.stop);

    counter.recordAssignmentsFetch(DatadogFlagsAssignmentsFetchDiagnostics(
      endpoint: Uri.https(
        'preview.ff-cdn.datadoghq.com',
        '/precompute-assignments',
      ),
      statusCode: 200,
      httpDuration: const Duration(milliseconds: 250),
      deserializationDuration: const Duration(milliseconds: 12),
      responseBodyBytes: 1234,
      receivedFlagCount: 10,
      assignmentCount: 9,
    ));

    expect(
        counter.lastPrecomputeHttpDuration, const Duration(milliseconds: 250));
    expect(counter.lastPrecomputeDeserializationDuration,
        const Duration(milliseconds: 12));
    expect(counter.lastPrecomputePayloadBytes, 1234);
    expect(counter.lastPrecomputeFlagCount, 10);
  });
}
