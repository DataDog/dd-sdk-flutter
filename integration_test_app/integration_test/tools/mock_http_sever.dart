// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef RequestHandler = bool Function(List<RequestLog> requests);

class RequestLog {
  final String requestedUrl;
  final String requestMethod;
  final Map<String, List<String>> requestHeaders;
  final String data;
  Object? get jsonData => json.decode(data);

  RequestLog._({
    required this.requestedUrl,
    required this.requestMethod,
    required this.requestHeaders,
    required this.data,
  });

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

    return RequestLog._(
      requestedUrl: url,
      requestMethod: request.method,
      requestHeaders: headers,
      data: decoded,
    );
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
      await request.response.close();
    }));
  }

  void startNewSession() {
    // For now, just clear
    _recordedRequests.clear();
  }

  /// Poll for all requests sent to this server for the current session (started
  /// with [startNewSession]). Requests are sent to [handler] until the
  /// [timeout] has expired, or until [handler] returns true, signaling it is
  /// done processing the requests.
  Future<void> pollRequests(Duration timeout, RequestHandler handler) async {
    DateTime timeoutTime = DateTime.now().add(timeout);
    int lastProcessedRequest = 0;

    var stopPolling = false;
    do {
      var newRequests = <RequestLog>[];
      for (var i = lastProcessedRequest; i < _recordedRequests.length; ++i) {
        final request = _recordedRequests[i];
        newRequests.add(request);
      }
      lastProcessedRequest = _recordedRequests.length;

      if (newRequests.isNotEmpty) {
        stopPolling = handler(newRequests);
      }

      if (!stopPolling) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } while (!stopPolling && timeoutTime.isAfter(DateTime.now()));
  }
}
