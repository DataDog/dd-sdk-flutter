// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'flags_request_counter.dart';
import 'local_flags_payloads.dart';

class LocalFlagsCollector implements FlagsRequestCounter {
  final http.Client httpClient;
  @override
  int precomputeRequestCount = 0;
  @override
  int exposureCount = 0;
  @override
  int evaluationRequestCount = 0;
  @override
  int evaluationEventCount = 0;

  LocalFlagsCollector._() : httpClient = _LocalFlagsClient();

  Uri get _baseUri => Uri.parse('https://local.datadog.flags');

  Uri get precomputeEndpoint =>
      _baseUri.replace(path: '/precompute-assignments');
  Uri get exposureEndpoint => _baseUri.replace(path: '/api/v2/exposures');
  Uri get evaluationEndpoint =>
      _baseUri.replace(path: '/api/v2/flagevaluation');

  static Future<LocalFlagsCollector?> start() async {
    final collector = LocalFlagsCollector._();
    (collector.httpClient as _LocalFlagsClient)._collector = collector;
    return collector;
  }

  @override
  Future<void> stop() async {
    httpClient.close();
  }
}

class _LocalFlagsClient extends http.BaseClient {
  LocalFlagsCollector? _collector;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = utf8.decode(await request.finalize().toBytes());
    final path = request.url.path;
    if (path == '/precompute-assignments') {
      _collector?.precomputeRequestCount += 1;
      return _jsonResponse(localPrecomputeResponse());
    }
    if (path == '/api/v2/exposures') {
      _collector?.exposureCount += countExposureBody(body);
      return _jsonResponse({'ok': true});
    }
    if (path == '/api/v2/flagevaluation') {
      _collector?.evaluationRequestCount += 1;
      _collector?.evaluationEventCount += tryCountEvaluationEvents(body);
      return _jsonResponse({'ok': true});
    }
    return _jsonResponse({'error': 'not found'}, statusCode: 404);
  }

  http.StreamedResponse _jsonResponse(
    Object body, {
    int statusCode = 200,
  }) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }
}
