// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'request_log.dart';

typedef RequestHandler = bool Function(List<RequestLog> requests);

const uuid = Uuid();

const int _bindingPort = 2228;
String get _endpoint => 'http://localhost:$_bindingPort';

class RecordingHttpServer {
  late HttpServer server;
  final Map<String, List<RequestLog>> _recordedRequests = {};

  // Used for debugging sessions
  bool serializeSessions = false;
  bool printRequests = false;

  RecordingHttpServer();

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.anyIPv4, _bindingPort);
    unawaited(server.forEach((HttpRequest request) async {
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
    print('Server started, listening on port $_bindingPort');
  }

  Future<dynamic> _logRequest(HttpRequest request) async {
    try {
      var session = '';
      if (request.uri.pathSegments.isNotEmpty) {
        session = request.uri.pathSegments[0];
      }

      final parsed = await RequestLog.fromRequest(request);
      if (_recordedRequests[session] == null) {
        throw Exception('Trying to add logs to a dead session: $session');
      }
      _recordedRequests[session]!.add(parsed);
      if (serializeSessions) {
        final sessionFile = File('$session.session');
        await sessionFile.writeAsString('${parsed.data}\n',
            mode: FileMode.append, flush: true);
      }
      if (printRequests) {
        print('---- BEGIN REQUEST ----');
        print('Requested URL: ${parsed.requestedUrl}');
        print(parsed.data);
        print('---- END REQUEST ----');
      }
    } catch (e) {
      print('Failed parsing request: $e');
    }

    request.response.write('Hello, world!');
    return request.response.close();
  }

  Future<void> _respondToSessionRequest(HttpRequest request) async {
    switch (request.method.toLowerCase()) {
      case 'post':
        var sessionId = await _createNewSession();
        request.response.write(sessionId);
        break;
      case 'get':
        var session = '';
        if (request.uri.pathSegments.isNotEmpty) {
          session = request.uri.pathSegments[0];
        }

        var jsonRequests =
            _recordedRequests[session]?.map((e) => e.toJson()).toList();
        var responseString = json.encode(jsonRequests);
        request.response.write(responseString);
        break;
      default:
        request.response.write('Unknown method on /session: ${request.method}');
        break;
    }
    return request.response.close();
  }

  Future<String> _createNewSession() async {
    final newSessionId = uuid.v4();
    _recordedRequests[newSessionId.toString()] = [];
    print('New session created: $newSessionId');
    return newSessionId.toString();
  }
}

abstract class RecordingServerClient {
  var currentSession = '';

  String get sessionEndpoint => '$_endpoint/$currentSession/';

  Future<String> startNewSession();
  Future<List<RequestLog>> fetchRequests(String sessionId);

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
      var recordedRequests = await fetchRequests(currentSession);
      for (var i = lastProcessedRequest; i < recordedRequests.length; ++i) {
        final request = recordedRequests[i];
        newRequests.add(request);
      }
      lastProcessedRequest = recordedRequests.length;

      if (newRequests.isNotEmpty) {
        stopPolling = handler(newRequests);
      }

      if (!stopPolling) {
        await Future<void>.delayed(const Duration(milliseconds: 1000));
      }
    } while (!stopPolling && timeoutTime.isAfter(DateTime.now()));
  }
}

class LocalRecordingServerClient extends RecordingServerClient {
  final RecordingHttpServer _server;

  LocalRecordingServerClient(this._server);

  @override
  Future<List<RequestLog>> fetchRequests(String sessionId) async {
    return _server._recordedRequests[sessionId] ?? [];
  }

  @override
  Future<String> startNewSession() async {
    final sessionId = await _server._createNewSession();
    currentSession = sessionId;
    return sessionId;
  }
}

class RemoteRecordingServerClient extends RecordingServerClient {
  RemoteRecordingServerClient();

  @override
  Future<List<RequestLog>> fetchRequests(String sessionId) async {
    try {
      var session =
          await http.get(Uri.parse('${sessionEndpoint}session'), headers: {
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
  Future<String> startNewSession({int maxAttempts = 10}) async {
    await Future<void>.delayed(const Duration(seconds: 3));
    //for (int i = 0; i < maxAttempts; ++i) {
    try {
      var response = await http.post(Uri.parse('$_endpoint/session'));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to start a new test session');
      }
      currentSession = response.body;
      return currentSession;
    } on http.ClientException {
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    return '';
    //}
    //throw Exception('Was not able to start a new recording session');
  }
}
