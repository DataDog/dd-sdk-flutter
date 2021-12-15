// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef RequestMatcher = bool Function(List<RequestLog> requests);

class RequestLog {
  final String requestedUrl;
  final Map<String, List<String>> requestHeaders;
  final Object? requestJson;

  RequestLog._(this.requestedUrl, this.requestHeaders, this.requestJson);

  static Future<RequestLog> fromRequest(HttpRequest request) async {
    final url = request.requestedUri.path;
    final headers = <String, List<String>>{};
    request.headers.forEach((name, values) {
      headers[name] = values;
    });

    var decoded = '';
    var contentEncoding = headers['content-encoding'];
    var isZipped = contentEncoding != null &&
        (contentEncoding.contains('deflate') ||
            contentEncoding.contains('gzip'));
    if (isZipped) {
      decoded = await utf8.fuse(gzip).decoder.bind(request).single;
    } else {
      decoded = await utf8.decodeStream(request);
    }

    final decodedJson = json.decode(decoded);
    return RequestLog._(url, headers, decodedJson);
  }
}

class MockHttpServer {
  static const int bindingPort = 2228;

  late HttpServer server;

  final List<RequestLog> _recordedRequests = [];
  String get endpoint => 'http://localhost:$bindingPort';

  MockHttpServer();

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.anyIPv4, bindingPort);
    unawaited(server.forEach((HttpRequest request) async {
      try {
        final parsed = await RequestLog.fromRequest(request);
        _recordedRequests.add(parsed);
      } catch (e) {
        print('Failed parsing request');
      }

      request.response.write('Hello, world!');
      request.response.close();
    }));
  }

  void startNewSession() {
    // For now, just clear
    _recordedRequests.clear();
  }

  Future<bool> pullRecordedRequests(
      Duration timeout, RequestMatcher matcher) async {
    DateTime timeoutTime = DateTime.now().add(timeout);
    int lastProcessedReqest = 0;

    var conditionsMet = false;
    do {
      var newRequests = <RequestLog>[];
      for (var i = lastProcessedReqest; i < _recordedRequests.length; ++i) {
        final request = _recordedRequests[i];
        newRequests.add(request);
      }
      lastProcessedReqest = _recordedRequests.length;
      conditionsMet = matcher(newRequests);

      if (!conditionsMet) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } while (!conditionsMet && timeoutTime.isAfter(DateTime.now()));

    return conditionsMet;
  }
}
