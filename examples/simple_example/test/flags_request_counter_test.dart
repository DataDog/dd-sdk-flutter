// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test_app/flags/forwarding_flags_counter.dart';

void main() {
  test('forwarding counter records flag request attempts and forwards them',
      () async {
    final forwarded = <http.Request>[];
    final client = CountingFlagsHttpClient(MockClient((request) async {
      forwarded.add(request);
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
    expect(client.exposureCount, 1);
    expect(client.evaluationRequestCount, 1);
    expect(client.evaluationEventCount, 2);
  });
}
