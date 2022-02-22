// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:async';
import 'dart:io';

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:datadog_sdk/src/datadog_tracking_http_client.dart';
import 'package:datadog_sdk/src/internal_attributes.dart';
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

  MockHttpClientResponse _setupMockClientResponse(int statusCode,
      {String mimeType = 'image/png', int size = 88888}) {
    final mockResponse = MockHttpClientResponse();
    when(() => mockResponse.statusCode).thenReturn(statusCode);
    when(() => mockResponse.reasonPhrase)
        .thenReturn('The only winning move is not to play');
    final mockHeaders = MockHttpHeaders();
    when(() => mockResponse.headers).thenReturn(mockHeaders);
    final contentType = ContentType.parse(mimeType);
    when(() => mockHeaders.contentType).thenReturn(contentType);
    when(() => mockResponse.contentLength).thenReturn(size);

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

  // Although mocked, these are the real headers we expect from tracing
  const fakeTraceHeaders = {
    'x-datadog-trace-id': 'fake-trace-id',
    'x-datadog-parent-id': 'fake-span-id',
    'x-datadog-sampling-priority': '1',
    'x-datadog-sampled': '1',
  };

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
    when(() => span.setTag(any(), any())).thenAnswer((_) => Future.value());
    when(() => span.setErrorInfo(any(), any(), any()))
        .thenAnswer((_) => Future.value());
    when(() => mockDatadog.traces).thenReturn(mockTraces);

    return span;
  }

  group('when only tracing is enabled', () {
    setUp(() {
      when(() => mockDatadog.rum).thenReturn(null);
    });

    test('rum is not called', () async {
      final completer = _setupMockRequest();
      _enableTracing();

      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://test_url/path');
      var request = await client.openUrl('get', url);

      completer.complete(MockHttpClientResponse());
      var _ = await request.done;
      verifyZeroInteractions(mockRum);
    });

    test('open starts trace and calls through for first party url', () async {
      final completer = _setupMockRequest();
      final mockSpan = _enableTracing();

      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://test_url/path');
      var request = await client.openUrl('get', url);

      verify(() => mockClient.openUrl('get', url));
      verify(() => mockTraces.startSpan('flutter.http_client', tags: {
            'http.method': 'GET',
            'http.url': url.toString(),
          }));
      final requestHeaders = request.headers;
      for (var header in fakeTraceHeaders.entries) {
        verify(() => requestHeaders.add(header.key, header.value));
      }

      // Finish not called until response is closed
      verifyNever(() => mockSpan.finish());

      final mockResponse = _setupMockClientResponse(200);
      completer.complete(mockResponse);
      var response = await request.done;

      // Still not done...
      verifyNever(() => mockSpan.finish());
      response.listen((event) {});
      await mockResponse.streamController.close();
      verify(() => mockSpan.setTag(OTTags.httpStatusCode, 200));
      verify(() => mockSpan.finish());
    });

    test('tracing still passes through data on stream', () async {
      final completer = _setupMockRequest();
      _enableTracing();

      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://test_url/path');
      var request = await client.openUrl('get', url);
      final mockResponse = _setupMockClientResponse(200);

      completer.complete(mockResponse);
      var response = await request.done;
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

      completer.complete(MockHttpClientResponse());
      var _ = await request.done;

      verifyNever(() => mockTraces.startSpan(
            any(),
            parentSpan: any(named: 'parentSpan'),
            tags: any(named: 'tags'),
            startTime: any(named: 'startTime'),
          ));
    });

    test('error opening passes sets trace errors', () async {
      final completer = _setupMockRequest();
      var mockSpan = _enableTracing();

      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://test_url/path');
      var request = await client.openUrl('get', url);

      var error = Error();
      Object? caughtError;
      completer.completeError(error);
      try {
        await request.done;
      } catch (e) {
        caughtError = e;
      }

      expect(caughtError, error, reason: 'Error should be rethrown');
      verify(() => mockSpan.setErrorInfo(
          error.runtimeType.toString(), error.toString(), any()));
    });

    test('error status codes set errors on trace', () async {
      final completer = _setupMockRequest();
      var mockSpan = _enableTracing();

      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://test_url/path');
      var request = await client.openUrl('get', url);

      var mockResponse = _setupMockClientResponse(403);
      completer.complete(mockResponse);
      var response = await request.done;

      // Listen / close the response
      response.listen((event) {});
      await mockResponse.streamController.close();

      expect(response.statusCode, 403);
      verify(() => mockSpan.setTag(OTTags.httpStatusCode, 403));
      verify(() => mockSpan.setErrorInfo(
          'HttpStatusCode', '403 - ${response.reasonPhrase}', any()));
    });

    test('error in stream sets errors on trace', () async {
      final completer = _setupMockRequest();
      var mockSpan = _enableTracing();

      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://test_url/path');
      var request = await client.openUrl('get', url);

      var mockResponse = _setupMockClientResponse(200);
      completer.complete(mockResponse);
      var response = await request.done;

      // Listen / close the response
      var error = Error();
      Object? caughtError;
      response.listen((event) {}, onError: (e) {
        caughtError = e;
      });
      mockResponse.streamController.addError(error);
      await mockResponse.streamController.close();

      expect(caughtError, error);
      verify(() => mockSpan.setTag(OTTags.httpStatusCode, 200));
      verify(() => mockSpan.setErrorInfo(
          error.runtimeType.toString(), error.toString(), any()));
    });
  });

  void _enableRum() {
    when(() => mockDatadog.traces).thenReturn(null);
    when(() => mockDatadog.rum).thenReturn(mockRum);
    when(() => mockRum.startResourceLoading(any(), any(), any(), any()))
        .thenAnswer((_) => Future.value());
    when(() => mockRum.stopResourceLoading(any(), any(), any(), any(), any()))
        .thenAnswer((_) => Future.value());
    when(() => mockRum.stopResourceLoadingWithErrorInfo(any(), any(), any()))
        .thenAnswer((_) => Future.value());
  }

  group('when only rum is enabled', () {
    setUp(() {
      _enableRum();
    });

    test('calls start resource and stop resource and calls through', () async {
      final completer = _setupMockRequest();

      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://test_url/path');
      var request = await client.openUrl('get', url);
      var requestHeaders = request.headers;
      verify(() => requestHeaders.add('x-datadog-origin', 'rum'));

      verify(() => mockClient.openUrl('get', url));
      var capturedKey = verify(
        () => mockRum.startResourceLoading(
            captureAny(), RumHttpMethod.get, url.toString()),
      ).captured[0] as String;

      verifyNever(() => mockRum.stopResourceLoading(any(), any(), any()));

      final mockResponse = _setupMockClientResponse(200);
      completer.complete(mockResponse);
      var response = await request.done;

      var gotData = false;
      response.listen((event) {
        gotData = true;
      });
      mockResponse.streamController.sink.add([12]);
      await mockResponse.streamController.close();
      expect(gotData, isTrue);
      verify(() => mockRum.stopResourceLoading(
          capturedKey, 200, RumResourceType.image, 88888));
    });

    test('calls stop resource with status code', () async {
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

      final mockResponse = _setupMockClientResponse(403);
      completer.complete(mockResponse);
      var response = await request.done;
      response.listen((event) {});
      await mockResponse.streamController.close();

      verify(() => mockRum.stopResourceLoading(
          capturedKey, 403, RumResourceType.image, 88888));
    });

    test('sets resource type from headers', () async {
      final completer = _setupMockRequest();

      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://test_url/path');
      var request = await client.openUrl('get', url);

      verify(() => mockClient.openUrl('get', url));
      var capturedKey = verify(
        () => mockRum.startResourceLoading(
            captureAny(), RumHttpMethod.get, url.toString()),
      ).captured[0] as String;

      final mockResponse = _setupMockClientResponse(200, mimeType: 'video/mp4');
      completer.complete(mockResponse);
      var response = await request.done;

      response.listen((event) {});
      await mockResponse.streamController.close();

      verify(() => mockRum.stopResourceLoading(
          capturedKey, 200, RumResourceType.media, 88888));
    });

    test('calls stop resource with error connection error', () async {
      final completer = _setupMockRequest();

      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://test_url/path');
      var request = await client.openUrl('get', url);
      var capturedKey = verify(
        () => mockRum.startResourceLoading(
            captureAny(), RumHttpMethod.get, url.toString()),
      ).captured[0] as String;

      var error = Error();
      Object? caughtError;
      completer.completeError(error);
      try {
        await request.done;
      } catch (e) {
        caughtError = e;
      }

      expect(caughtError, error);
      verify(() => mockRum.stopResourceLoadingWithErrorInfo(
            capturedKey,
            error.toString(),
          ));
    });

    test('calls stop resource with error for response error', () async {
      final completer = _setupMockRequest();
      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://test_url/path');
      var request = await client.openUrl('get', url);
      var capturedKey = verify(
        () => mockRum.startResourceLoading(
            captureAny(), RumHttpMethod.get, url.toString()),
      ).captured[0] as String;

      var mockResponse = _setupMockClientResponse(200);

      completer.complete(mockResponse);
      var response = await request.done;

      // Listen / close the response
      var error = Error();
      Object? caughtError;
      response.listen((event) {}, onError: (e) {
        caughtError = e;
      });
      mockResponse.streamController.addError(error);
      await mockResponse.streamController.close();

      expect(caughtError, error);
      verify(() => mockRum.stopResourceLoadingWithErrorInfo(
            capturedKey,
            error.toString(),
          ));
    });
  });

  group('when rum and tracing are enabled', () {
    late DdSpan span;
    setUp(() {
      _enableRum();
      span = _enableTracing();
    });

    test('start and stop resource loading set tracing attributes', () async {
      final completer = _setupMockRequest();
      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://test_url/path');
      var request = await client.openUrl('get', url);
      var capturedStartArgs = verify(
        () => mockRum.startResourceLoading(
          captureAny(),
          RumHttpMethod.get,
          url.toString(),
          captureAny(),
        ),
      ).captured;
      var capturedKey = capturedStartArgs[0] as String;
      var capturedStartAttributes =
          capturedStartArgs[1] as Map<String, dynamic>;

      var mockResponse = _setupMockClientResponse(200, size: 12345);

      completer.complete(mockResponse);
      var response = await request.done;
      response.listen((event) {});
      await mockResponse.streamController.close();

      verify(() => mockRum.stopResourceLoading(
          capturedKey, 200, RumResourceType.image, 12345));

      expect(capturedStartAttributes[DatadogPlatformAttributeKey.traceID],
          'fake-trace-id');
      expect(capturedStartAttributes[DatadogPlatformAttributeKey.spanID],
          'fake-span-id');
    });

    test('does not start perform operations on spans', () async {
      final completer = _setupMockRequest();
      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://test_url/path');
      var request = await client.openUrl('get', url);
      var mockResponse = _setupMockClientResponse(200);

      completer.complete(mockResponse);
      var response = await request.done;
      response.listen((event) {});
      await mockResponse.streamController.close();
      // Drain any awaiting futures.
      await Future.microtask(() {});
      verifyZeroInteractions(span);
    });

    test('sets trace headers for first party urls', () async {
      _setupMockRequest();
      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://test_url/path');
      var request = await client.openUrl('get', url);
      final requestHeaders = request.headers;
      for (var header in fakeTraceHeaders.entries) {
        verify(() => requestHeaders.add(header.key, header.value));
      }
    });

    test('does not set trace headers for third party urls', () async {
      _setupMockRequest();
      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://non_first_party/path');
      var request = await client.openUrl('get', url);
      final requestHeaders = request.headers;
      for (var header in fakeTraceHeaders.entries) {
        verifyNever(() => requestHeaders.add(header.key, header.value));
      }
    });

    test('error on openUrl stops resource with error', () async {
      const error = SocketException('Mock socket exception');
      when(() => mockClient.openUrl(any(), any())).thenThrow(error);
      final client = DatadogTrackingHttpClient(mockDatadog, mockClient);

      var url = Uri.parse('https://test_url/path');

      await expectLater(() async => await client.openUrl('get', url),
          throwsA(predicate((e) => e == error)));
      var capturedKey = verify(() => mockRum.startResourceLoading(
              captureAny(), RumHttpMethod.get, url.toString(), any()))
          .captured[0] as String;
      verify(() => mockRum.stopResourceLoadingWithErrorInfo(
          capturedKey, error.toString()));
    });
  });
}
