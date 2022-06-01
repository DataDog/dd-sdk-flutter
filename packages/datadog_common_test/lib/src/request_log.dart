// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:json_annotation/json_annotation.dart';

part 'request_log.g.dart';

@JsonSerializable()
class RequestLog {
  final String requestedUrl;
  final String requestMethod;
  final Map<String, List<String>> requestHeaders;
  final String data;
  Object? get jsonData => json.decode(data);

  RequestLog({
    required this.requestedUrl,
    required this.requestMethod,
    required this.requestHeaders,
    required this.data,
  });

  factory RequestLog.fromJson(Map<String, dynamic> json) =>
      _$RequestLogFromJson(json);
  Map<String, dynamic> toJson() => _$RequestLogToJson(this);

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

    return RequestLog(
      requestedUrl: url,
      requestMethod: request.method,
      requestHeaders: headers,
      data: decoded,
    );
  }
}
