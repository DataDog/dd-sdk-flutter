// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:async';
import 'dart:io';

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:datadog_sdk/src/datadog_tracking_http_client.dart';
import 'package:datadog_sdk/src/rum/ddrum.dart';
import 'package:datadog_sdk/src/traces/ddtraces.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDatadogSdk extends Mock implements DatadogSdk {}

class MockDdRum extends Mock implements DdRum {}

class MockDdTraces extends Mock implements DdTraces {}

class MockDdSpan extends Mock implements DdSpan {}

class FakeDdSpan extends Fake implements DdSpan {}

class MockHttpClient extends Mock implements HttpClient {}

class MockHttpHeaders extends Mock implements HttpHeaders {}

class MockHttpClientRequest extends Mock implements HttpClientRequest {}

class MockHttpClientResponse extends Mock implements HttpClientResponse {
  final StreamController<List<int>> streamController =
      StreamController<List<int>>(sync: true);

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return streamController.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class HasHost extends CustomMatcher {
  HasHost(Matcher matcher) : super('Uri with host that is', 'host', matcher);

  @override
  Object? featureValueOf(actual) {
    return (actual as Uri).host;
  }
}

void main() {
  late MockDatadogSdk mockDatadog;
  late MockDdTraces mockTraces;
  late MockDdRum mockRum;
  late MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(FakeDdSpan());
    registerFallbackValue(RumHttpMethod.get);
    registerFallbackValue(RumResourceType.beacon);
  });

  setUp(() {
    mockDatadog = MockDatadogSdk();
    when(() => mockDatadog.isFirstPartyHost(
        any(that: HasHost(equals('test_url'))))).thenReturn(true);
    when(() => mockDatadog.isFirstPartyHost(
        any(that: HasHost(equals('non_first_party'))))).thenReturn(false);
    mockTraces = MockDdTraces();
    mockRum = MockDdRum();

    mockClient = MockHttpClient();
    when(() => mockClient.autoUncompress).thenReturn(true);
    when(() => mockClient.idleTimeout).thenReturn(const Duration());
  });

  Completer<HttpClientResponse> _setupMockRequest() {
    final mockRequest = MockHttpClientRequest();
    final mockHeaders = MockHttpHeaders();
    var completer = Completer<HttpClientResponse>();
    when(() => mockClient.openUrl(any(), any()))
        .thenAnswer((_) => Future.value(mockRequest));
    when(() => mockRequest.headers).thenReturn(mockHeaders);
    when(() => mockRequest.done).thenAnswer((_) => completer.future);
    when(() => mockRequest.close()).thenAnswer((_) => completer.future);

    return completer;
  }

  MockHttpClientResponse _setupMockClientResponse() {
    final mockResponse = MockHttpClientResponse();

    return mockResponse;
  }

  group('when tracing and rum are disabled', () {
    setUp(() {
      when(() => mockDatadog.traces).thenReturn(null);
      when(() => mockDatadog.rum).thenReturn(null);
    });

    test('tracking client passes through properties', () {
      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      client.autoUncompress;
      client.autoUncompress = true;
      verify(() => mockClient.autoUncompress);
      verify(() => mockClient.autoUncompress = true);

      client.connectionTimeout;
      client.connectionTimeout = const Duration();
      verify(() => mockClient.connectionTimeout);
      verify(() => mockClient.connectionTimeout = const Duration());

      client.idleTimeout;
      client.idleTimeout = const Duration();
      verify(() => mockClient.idleTimeout);
      verify(() => mockClient.idleTimeout = const Duration());

      client.maxConnectionsPerHost;
      client.maxConnectionsPerHost = 3;
      verify(() => mockClient.maxConnectionsPerHost);
      verify(() => mockClient.maxConnectionsPerHost = 3);

      client.userAgent;
      client.userAgent = 'test';
      verify(() => mockClient.userAgent);
      verify(() => mockClient.userAgent = 'test');
    });

    test('open calls through when tracing and rum are disabled', () async {
      _setupMockRequest();
      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://test_url/path');
      var _ = await client.openUrl('get', url);

      verify(() => mockClient.openUrl('get', url));
    });
  });

  group('when only tracing is enabled', () {
    // Although mocked, these are the real headers we expect from tracing
    const fakeTraceHeaders = {
      'x-datadog-trace-id': 'mock-value',
      'x-datadog-parent-id': 'mock-value',
      'x-datadog-sampling-priority': '1',
      'x-datadog-sampled': '1',
    };
    setUp(() {
      when(() => mockDatadog.rum).thenReturn(null);
    });

    MockDdSpan _enableTracing() {
      final span = MockDdSpan();
      when(() => mockTraces.startSpan(
            any(),
            parentSpan: any(named: 'parentSpan'),
            tags: any(named: 'tags'),
            startTime: any(named: 'startTime'),
          )).thenAnswer((_) => Future.value(span));
      when(() => mockTraces.getTracePropagationHeaders(any()))
          .thenAnswer((_) => Future.value(fakeTraceHeaders));
      when(() => mockDatadog.traces).thenReturn(mockTraces);
      when(() => span.finish()).thenAnswer((_) => Future.value());

      when(() => mockDatadog.traces).thenReturn(mockTraces);

      return span;
    }

    test('rum is not called', () async {
      // No interactions for the whole test
      verifyNoMoreInteractions(mockRum);

      final completer = _setupMockRequest();
      _enableTracing();

      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://test_url/path');
      var request = await client.openUrl('get', url);

      completer.complete(MockHttpClientResponse());
      var _ = await request.done;
    });

    test('open starts trace and calls through for first party url', () async {
      final completer = _setupMockRequest();
      final mockSpan = _enableTracing();

      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://test_url/path');
      var request = await client.openUrl('get', url);

      verify(() => mockClient.openUrl('get', url));
      verify(() => mockTraces.startSpan('flutter.http_client',
          tags: {'http.method': 'get', 'http.url': url.toString()}));
      final mockHeaders = request.headers;
      for (var header in fakeTraceHeaders.entries) {
        verify(() => mockHeaders.add(header.key, header.value));
      }

      // Finish not called until response is closed
      verifyNever(() => mockSpan.finish());

      final mockResponse = _setupMockClientResponse();
      completer.complete(mockResponse);
      var response = await request.done;

      // Still not done...
      verifyNever(() => mockSpan.finish());
      response.listen((event) {});
      await mockResponse.streamController.close();
      verify(() => mockSpan.finish());
    });

    test('tracing still passes through data on stream', () async {
      final completer = _setupMockRequest();
      _enableTracing();

      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://test_url/path');
      var request = await client.openUrl('get', url);

      verify(() => mockClient.openUrl('get', url));
      verify(() => mockTraces.startSpan('flutter.http_client',
          tags: {'http.method': 'get', 'http.url': url.toString()}));
      final mockHeaders = request.headers;
      for (var header in fakeTraceHeaders.entries) {
        verify(() => mockHeaders.add(header.key, header.value));
      }

      final mockResponse = _setupMockClientResponse();
      completer.complete(mockResponse);
      var response = await request.done;

      // Still not done...
      List<int>? data;
      response.listen((event) {
        data = event;
      });
      mockResponse.streamController.sink.add([12, 1, 2]);
      await mockResponse.streamController.close();
      expect(data, [12, 1, 2]);
    });

    test('open does not start trace and calls through for non-first party url',
        () async {
      final completer = _setupMockRequest();
      // ignore: unused_local_variable
      final mockSpan = _enableTracing();

      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://non_first_party/path');
      var request = await client.openUrl('get', url);

      verify(() => mockClient.openUrl('get', url));
      verifyNever(() => mockTraces.startSpan(
            any(),
            parentSpan: any(named: 'parentSpan'),
            tags: any(named: 'tags'),
            startTime: any(named: 'startTime'),
          ));

      completer.complete(MockHttpClientResponse());
      var _ = await request.done;
    });
  });

  group('when only rum is enabled', () {
    setUp(() {
      when(() => mockDatadog.traces).thenReturn(null);
      when(() => mockDatadog.rum).thenReturn(mockRum);
      when(() => mockRum.startResourceLoading(any(), any(), any()))
          .thenAnswer((_) => Future.value());
      when(() => mockRum.stopResourceLoading(any(), any(), any()))
          .thenAnswer((_) => Future.value());
    });

    test('calls start resource and stop resource and calls through', () async {
      final completer = _setupMockRequest();

      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://test_url/path');
      var request = await client.openUrl('get', url);

      verify(() => mockClient.openUrl('get', url));
      var capturedKey = verify(
        () => mockRum.startResourceLoading(
            captureAny(), RumHttpMethod.get, url.toString()),
      ).captured[0] as String;

      verifyNever(() => mockRum.stopResourceLoading(any(), any(), any()));

      final mockResponse = _setupMockClientResponse();
      when(() => mockResponse.statusCode).thenReturn(200);
      completer.complete(mockResponse);
      var response = await request.done;

      var gotData = false;
      response.listen((event) {
        gotData = true;
      });
      mockResponse.streamController.sink.add([12]);
      await mockResponse.streamController.close();
      expect(gotData, isTrue);
      verify(() =>
          mockRum.stopResourceLoading(capturedKey, 200, RumResourceType.image));
    });
  });
}
