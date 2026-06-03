// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'flags_request_counter.dart';

class ForwardingFlagsCounter implements FlagsRequestCounter {
  final CountingFlagsHttpClient httpClient;

  ForwardingFlagsCounter._(this.httpClient);

  factory ForwardingFlagsCounter.create() {
    return ForwardingFlagsCounter._(CountingFlagsHttpClient(http.Client()));
  }

  @override
  int get precomputeRequestCount => httpClient.precomputeRequestCount;

  @override
  int get exposureCount => httpClient.exposureCount;

  @override
  int get evaluationRequestCount => httpClient.evaluationRequestCount;

  @override
  int get evaluationEventCount => httpClient.evaluationEventCount;

  @override
  Future<void> stop() async {
    httpClient.close();
  }
}

class CountingFlagsHttpClient extends http.BaseClient {
  final http.Client _inner;

  int precomputeRequestCount = 0;
  int exposureCount = 0;
  int evaluationRequestCount = 0;
  int evaluationEventCount = 0;

  CountingFlagsHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final body = request is http.Request ? request.body : '';
    final path = request.url.path;
    if (path == '/precompute-assignments') {
      precomputeRequestCount += 1;
    } else if (path == '/api/v2/exposures') {
      exposureCount += _countExposureBody(body);
    } else if (path == '/api/v2/flagevaluation') {
      evaluationRequestCount += 1;
      evaluationEventCount += _tryCountEvaluationEvents(body);
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

int _countExposureBody(String body) {
  return body.split('\n').where((line) => line.trim().isNotEmpty).length;
}

int _tryCountEvaluationEvents(String body) {
  try {
    final decoded = jsonDecode(body) as Map<String, Object?>;
    final evaluations = decoded['flagEvaluations'] as List<Object?>;
    return evaluations.length;
  } catch (_) {
    return 0;
  }
}
