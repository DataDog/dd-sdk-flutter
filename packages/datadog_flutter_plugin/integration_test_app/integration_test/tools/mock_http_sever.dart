// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;

import 'request_log.dart';

typedef RequestHandler = bool Function(List<RequestLog> requests);

class RecordingHttpServer {
  static const int bindingPort = 2228;

  static String get endpoint => 'http://localhost:$bindingPort';

  late HttpServer server;
  final List<RequestLog> _recordedRequests = [];
  List<RequestLog> get recordedRequests =>
      UnmodifiableListView(_recordedRequests);

  RecordingHttpServer();

  void startNewSession() {
    _recordedRequests.clear();
  }

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.anyIPv4, bindingPort);
    unawaited(server.forEach((HttpRequest request) async {
      // print('Request for ${request.uri}');
      request.response.headers
        ..add(HttpHeaders.accessControlAllowOriginHeader, '*')
        ..add(HttpHeaders.accessControlAllowHeadersHeader, '*')
        ..add(HttpHeaders.accessControlAllowMethodsHeader, 'GET, POST');
      if (request.requestedUri.path.endsWith('session')) {
        return _respondToSessionRequest(request);
      } else {
        return _logRequest(request);
      }
    }));
    print('Server started, listening on port $bindingPort');
  }

  Future<dynamic> _logRequest(HttpRequest request) async {
    try {
      final parsed = await RequestLog.fromRequest(request);
      print('parsed request is ${parsed.data}');
      _recordedRequests.add(parsed);
    } catch (e) {
      print('Failed parsing request');
    }

    request.response.write('Hello, world!');
    return request.response.close();
  }

  Future<void> _respondToSessionRequest(HttpRequest request) {
    switch (request.method.toLowerCase()) {
      case 'post':
        startNewSession();
        break;
      case 'get':
        var jsonRequests = recordedRequests.map((e) => e.toJson()).toList();
        var responseString = json.encode(jsonRequests);
        request.response.write(responseString);
        break;
      default:
        request.response.write('Unknown method on /session: ${request.method}');
        break;
    }
    return request.response.close();
  }
}

abstract class RecordingServerClient {
  Future<void> startNewSession();
  Future<List<RequestLog>> fetchRequests();

  /// Poll for all requests sent to this server for the current session (started
  /// with [startNewSession]). Requests are sent to [handler] until the
  /// [timeout] has expired, or until [handler] returns true, signaling it is
  /// done processing the requests.
  Future<void> pollSessionRequests(
      Duration timeout, RequestHandler handler) async {
    DateTime timeoutTime = DateTime.now().add(timeout);
    int lastProcessedRequest = 0;

    var stopPolling = false;
    do {
      var newRequests = <RequestLog>[];
      var recordedRequests = await fetchRequests();
      for (var i = lastProcessedRequest; i < recordedRequests.length; ++i) {
        final request = recordedRequests[i];
        newRequests.add(request);
      }
      lastProcessedRequest = recordedRequests.length;

      if (newRequests.isNotEmpty) {
        stopPolling = handler(newRequests);
      }

      if (!stopPolling) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    } while (!stopPolling && timeoutTime.isAfter(DateTime.now()));
  }
}

class LocalRecordingServerClient extends RecordingServerClient {
  final RecordingHttpServer _server;

  LocalRecordingServerClient(this._server);

  @override
  Future<List<RequestLog>> fetchRequests() async {
    return _server.recordedRequests;
  }

  @override
  Future<void> startNewSession() async {
    // For now, just clear
    _server.startNewSession();
  }
}

class RemoteRecordingServerClient extends RecordingServerClient {
  final String endpoint;

  RemoteRecordingServerClient(this.endpoint);

  @override
  Future<List<RequestLog>> fetchRequests() async {
    try {
      var session = await http.get(Uri.parse('$endpoint/session'), headers: {
        HttpHeaders.accessControlAllowOriginHeader: '*',
        HttpHeaders.contentTypeHeader: 'application/json',
        HttpHeaders.acceptHeader: 'application/json',
      });
      var sessionBody = json.decode(session.body) as List;
      var requests = <RequestLog>[];
      for (var requestJson in sessionBody) {
        requests.add(RequestLog.fromJson(requestJson));
      }

      return requests;
    } catch (e) {
      // TODO : Figure out how to connect to the driver first?
      //print('FAIL :( ${e.toString()}');
    }
    return [];
  }

  @override
  Future<void> startNewSession() async {
    var response = await http.post(Uri.parse('$endpoint/session'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to start a new test session');
    }
  }
}
