// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:http/http.dart' as http;

import 'flags_request_counter.dart';

class ForwardingFlagsCounter implements FlagsRequestCounter {
  final CountingFlagsHttpClient httpClient;
  DatadogFlagsAssignmentsFetchDiagnostics? _lastAssignmentsFetchDiagnostics;

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
  int? get lastPrecomputeFlagCount =>
      _lastAssignmentsFetchDiagnostics?.receivedFlagCount ??
      httpClient.lastPrecomputeFlagCount;

  @override
  int? get lastPrecomputePayloadBytes =>
      _lastAssignmentsFetchDiagnostics?.responseBodyBytes ??
      httpClient.lastPrecomputePayloadBytes;

  @override
  Duration? get lastPrecomputeHttpDuration =>
      _lastAssignmentsFetchDiagnostics?.httpDuration;

  @override
  Duration? get lastPrecomputeDeserializationDuration =>
      _lastAssignmentsFetchDiagnostics?.deserializationDuration;

  void recordAssignmentsFetch(
    DatadogFlagsAssignmentsFetchDiagnostics diagnostics,
  ) {
    _lastAssignmentsFetchDiagnostics = diagnostics;
  }

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
  int? lastPrecomputeFlagCount;
  int? lastPrecomputePayloadBytes;

  CountingFlagsHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = request is http.Request ? request.body : '';
    final path = request.url.path;
    if (path == '/precompute-assignments') {
      precomputeRequestCount += 1;
      final response = await _inner.send(request);
      final bodyBytes = await response.stream.toBytes();
      lastPrecomputePayloadBytes = bodyBytes.length;
      lastPrecomputeFlagCount = _tryCountPrecomputeFlags(bodyBytes);
      return _copyResponseWithBytes(response, bodyBytes);
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

int? _tryCountPrecomputeFlags(List<int> bodyBytes) {
  try {
    final decoded = jsonDecode(utf8.decode(bodyBytes)) as Map<String, Object?>;
    final data = decoded['data'] as Map<String, Object?>;
    final attributes = data['attributes'] as Map<String, Object?>;
    final flags = attributes['flags'] as Map<String, Object?>;
    return flags.length;
  } catch (_) {
    return null;
  }
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

http.StreamedResponse _copyResponseWithBytes(
  http.StreamedResponse response,
  List<int> bodyBytes,
) {
  return http.StreamedResponse(
    Stream.value(bodyBytes),
    response.statusCode,
    contentLength: response.contentLength,
    request: response.request,
    headers: response.headers,
    isRedirect: response.isRedirect,
    persistentConnection: response.persistentConnection,
    reasonPhrase: response.reasonPhrase,
  );
}
