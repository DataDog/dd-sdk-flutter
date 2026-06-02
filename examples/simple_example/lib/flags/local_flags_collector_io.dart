// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'local_flags_payloads.dart';

class LocalFlagsCollector {
  final HttpServer _server;
  int exposureCount = 0;
  int evaluationRequestCount = 0;
  int evaluationEventCount = 0;

  LocalFlagsCollector._(this._server) {
    _server.listen(_handleRequest);
  }

  Uri get _baseUri => Uri(
        scheme: 'http',
        host: InternetAddress.loopbackIPv4.address,
        port: _server.port,
      );

  Uri get precomputeEndpoint =>
      _baseUri.replace(path: '/precompute-assignments');
  Uri get exposureEndpoint => _baseUri.replace(path: '/api/v2/exposures');
  Uri get evaluationEndpoint =>
      _baseUri.replace(path: '/api/v2/flagevaluation');
  http.Client? get httpClient => null;

  static Future<LocalFlagsCollector?> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return LocalFlagsCollector._(server);
  }

  Future<void> stop() {
    return _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    if (path == '/precompute-assignments') {
      await utf8.decoder.bind(request).join();
      _writeJson(request.response, localPrecomputeResponse());
    } else if (path == '/api/v2/exposures') {
      final body = await utf8.decoder.bind(request).join();
      exposureCount += countExposureBody(body);
      _writeJson(request.response, {'ok': true});
    } else if (path == '/api/v2/flagevaluation') {
      final body = await utf8.decoder.bind(request).join();
      evaluationRequestCount += 1;
      evaluationEventCount += countEvaluationEvents(body);
      _writeJson(request.response, {'ok': true});
    } else {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }

  void _writeJson(HttpResponse response, Object body) {
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    response.close();
  }
}
