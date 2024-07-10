// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:async';
import 'dart:io';

import 'package:datadog_common_test/uri_matchers.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_tracking_http_client/datadog_tracking_http_client.dart';
import 'package:datadog_tracking_http_client/src/tracking_http_client_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'test_helpers.dart';

class MockDatadogSdk extends Mock implements DatadogSdk {}

class MockDatadogSdkPlatform extends Mock implements DatadogSdkPlatform {}

class MockDdRum extends Mock implements DatadogRum {}

class MockHttpClient extends Mock implements HttpClient {}

class MockHttpHeaders extends Mock implements HttpHeaders {}

class MockHttpClientRequest extends Mock implements HttpClientRequest {}

class MockTrackingHttpClientListener extends Mock
    implements DatadogTrackingHttpClientListener {}

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

void main() {
  late MockDatadogSdk mockDatadog;
  late MockDatadogSdkPlatform mockPlatform;
  late MockDdRum mockRum;
  late MockHttpClient mockClient;
  late MockHttpClientRequest mockRequest;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(RumHttpMethod.get);
    registerFallbackValue(RumResourceType.beacon);
    registerFallbackValue(MockHttpClientRequest());
    registerFallbackValue(MockHttpClientResponse());
  });

  setUp(() {
    mockPlatform = MockDatadogSdkPlatform();
    when(() => mockPlatform.updateTelemetryConfiguration(any(), any()))
        .thenAnswer((_) => Future<void>.value());

    mockDatadog = MockDatadogSdk();
    when(() => mockDatadog
            .headerTypesForHost(any(that: HasHost(equals('test_url')))))
        .thenReturn({TracingHeaderType.datadog});
    when(() => mockDatadog.headerTypesForHost(
        any(that: HasHost(equals('non_first_party'))))).thenReturn({});
    when(() => mockDatadog.platform).thenReturn(mockPlatform);
    // ignore: invalid_use_of_internal_member
    when(() => mockDatadog.internalLogger).thenReturn(InternalLogger());

    mockRum = MockDdRum();
    when(() => mockRum.shouldSampleTrace()).thenReturn(true);
    when(() => mockRum.contextInjectionSetting)
        .thenReturn(TraceContextInjection.all);
    when(() => mockRum.traceSampleRate).thenReturn(50.0);

    mockClient = MockHttpClient();
    when(() => mockClient.autoUncompress).thenReturn(true);
    when(() => mockClient.idleTimeout).thenReturn(const Duration());
  });

  Completer<HttpClientResponse> setupMockRequest(Uri url) {
    mockRequest = MockHttpClientRequest();
    when(() => mockRequest.uri).thenReturn(url);

    final mockHeaders = MockHttpHeaders();
    Map<String, String> headerCache = {};
    when(() => mockHeaders.value(any())).thenAnswer(
        (invocation) => headerCache[invocation.positionalArguments[0]]);
    when(() => mockHeaders.forEach(any())).thenAnswer((invocation) {
      void Function(String, List<String>) arg =
          invocation.positionalArguments[0];
      headerCache.forEach((key, value) {
        arg(key, [value]);
      });
    });
    when(() => mockHeaders.add(any(), any())).thenAnswer((invocation) {
      headerCache[invocation.positionalArguments[0]] =
          invocation.positionalArguments[1].toString();
    });
    when(() => mockRequest.headers).thenReturn(mockHeaders);

    when(() => mockClient.openUrl(any(), any()))
        .thenAnswer((_) => Future.value(mockRequest));

    var completer = Completer<HttpClientResponse>();
    when(() => mockRequest.done).thenAnswer((_) => completer.future);
    when(() => mockRequest.close()).thenAnswer((_) => completer.future);

    return completer;
  }

  MockHttpClientResponse setupMockClientResponse(int statusCode,
      {String mimeType = 'image/png', int size = 88888}) {
    final mockResponse = MockHttpClientResponse();
    when(() => mockResponse.statusCode).thenReturn(statusCode);
    when(() => mockResponse.reasonPhrase)
        .thenReturn('The only winning move is not to play');

    var mockHeaders = MockHttpHeaders();
    final contentType = ContentType.parse(mimeType);
    when(() => mockHeaders.contentType).thenReturn(contentType);

    when(() => mockResponse.headers).thenReturn(mockHeaders);
    when(() => mockResponse.contentLength).thenReturn(size);

    return mockResponse;
  }

  group('when rum is disabled', () {
    setUp(() {
      when(() => mockDatadog.rum).thenReturn(null);
    });

    test('tracking client passes through properties', () {
      final client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(),
        mockClient,
      );

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
      var url = Uri.parse('https://test_url/path');
      setupMockRequest(url);
      final client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(),
        mockClient,
      );

      await client.openUrl('get', url);

      verify(() => mockClient.openUrl('get', url));
    });

    test('listeners are not called', () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);
      var mockListener = MockTrackingHttpClientListener();
      final client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(clientListener: mockListener),
        mockClient,
      );

      final request = await client.openUrl('get', url);
      var mockResponse = setupMockClientResponse(200);
      completer.complete(mockResponse);
      var response = await request.done;

      // Listen / close the response
      response.listen((event) {});
      await mockResponse.streamController.close();

      verifyZeroInteractions(mockListener);
    });
  });

  void enableRum() {
    when(() => mockDatadog.rum).thenReturn(mockRum);
  }

  group('when rum is enabled with tracing headers', () {
    late DatadogTrackingHttpClient client;

    setUp(() {
      enableRum();

      client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(
            ignoreUrlPatterns: [RegExp('test_url/ignored/')]),
        mockClient,
      );
    });

    test('calls start resource and stop resource and calls through', () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);

      when(() => mockRequest.uri).thenReturn(url);

      var request = await client.openUrl('get', url);

      verify(() => mockClient.openUrl('get', url));
      var capturedKey = verify(
        () => mockRum.startResource(
            captureAny(), RumHttpMethod.get, url.toString(), any()),
      ).captured[0] as String;

      verifyNever(() => mockRum.stopResource(any(), any(), any()));

      final mockResponse = setupMockClientResponse(200);
      completer.complete(mockResponse);
      var response = await request.done;

      var requestHeaders = request.headers;
      verify(() => requestHeaders.add('x-datadog-origin', 'rum'));

      var gotData = false;
      response.listen((event) {
        gotData = true;
      });
      mockResponse.streamController.sink.add([12]);
      await mockResponse.streamController.close();
      expect(gotData, isTrue);
      verify(() => mockRum.stopResource(
          capturedKey, 200, RumResourceType.image, 88888, any()));
    });

    test('calls stop resource with status code', () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);

      var request = await client.openUrl('get', url);

      verify(() => mockClient.openUrl('get', url));
      var capturedKey = verify(
        () => mockRum.startResource(
            captureAny(), RumHttpMethod.get, url.toString(), any()),
      ).captured[0] as String;

      verifyNever(() => mockRum.stopResource(any(), any(), any()));

      final mockResponse = setupMockClientResponse(403);
      completer.complete(mockResponse);
      var response = await request.done;
      response.listen((event) {});
      await mockResponse.streamController.close();

      verify(() => mockRum.stopResource(
          capturedKey, 403, RumResourceType.image, 88888, any()));
    });

    test('sets resource type from headers', () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);

      var request = await client.openUrl('get', url);

      verify(() => mockClient.openUrl('get', url));
      var capturedKey = verify(
        () => mockRum.startResource(
            captureAny(), RumHttpMethod.get, url.toString(), any()),
      ).captured[0] as String;

      final mockResponse = setupMockClientResponse(200, mimeType: 'video/mp4');
      completer.complete(mockResponse);
      var response = await request.done;

      response.listen((event) {});
      await mockResponse.streamController.close();

      verify(() => mockRum.stopResource(
          capturedKey, 200, RumResourceType.media, 88888, any()));
    });

    test('calls stop resource with error connection error', () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);

      var request = await client.openUrl('get', url);
      var capturedKey = verify(
        () => mockRum.startResource(
            captureAny(), RumHttpMethod.get, url.toString(), any()),
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
      verify(() => mockRum.stopResourceWithErrorInfo(
          capturedKey, error.toString(), error.runtimeType.toString(), any()));
    });

    test('calls stop resource with error for response error', () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);

      var request = await client.openUrl('get', url);
      var capturedKey = verify(
        () => mockRum.startResource(
            captureAny(), RumHttpMethod.get, url.toString(), any()),
      ).captured[0] as String;

      var mockResponse = setupMockClientResponse(200);

      completer.complete(mockResponse);
      var response = await request.done;

      // Listen / close the response
      var error = Error();
      Object? caughtError;
      response.listen((event) {}, onError: (Object e) {
        caughtError = e;
      });
      mockResponse.streamController.addError(error);
      await mockResponse.streamController.close();

      expect(caughtError, error);
      verify(() => mockRum.stopResourceWithErrorInfo(
            capturedKey,
            error.toString(),
            error.runtimeType.toString(),
            any(),
          ));
    });

    test('calls on error with error for dynamic parameter', () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);

      var request = await client.openUrl('get', url);
      var capturedKey = verify(
        () => mockRum.startResource(
            captureAny(), RumHttpMethod.get, url.toString(), any()),
      ).captured[0] as String;

      var mockResponse = setupMockClientResponse(200);

      completer.complete(mockResponse);
      var response = await request.done;

      // Listen / close the response
      var error = Error();
      Object? caughtError;
      response.listen((event) {}, onError: (dynamic e) {
        caughtError = e;
      });
      mockResponse.streamController.addError(error);
      await mockResponse.streamController.close();

      expect(caughtError, error);
      verify(() => mockRum.stopResourceWithErrorInfo(
            capturedKey,
            error.toString(),
            error.runtimeType.toString(),
            any(),
          ));
    });

    test('does not throw when listen provides non-standard onError function',
        () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);

      var request = await client.openUrl('get', url);
      var capturedKey = verify(
        () => mockRum.startResource(
            captureAny(), RumHttpMethod.get, url.toString(), any()),
      ).captured[0] as String;

      var mockResponse = setupMockClientResponse(200);

      completer.complete(mockResponse);
      var response = await request.done;

      // Listen / close the response
      var error = Error();
      dynamic caughtError;
      response.listen((event) {}, onError: (int i, double f) {
        caughtError = i;
      });
      mockResponse.streamController.addError(error);
      await mockResponse.streamController.close();

      expect(caughtError, isNull);
      verify(() => mockRum.stopResourceWithErrorInfo(
            capturedKey,
            error.toString(),
            error.runtimeType.toString(),
            any(),
          ));
    });

    test(
        'start and stop resource loading do not set tracing attributes if shouldSample returns false',
        () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);

      when(() => mockRum.shouldSampleTrace()).thenReturn(false);
      when(() => mockRum.traceSampleRate).thenReturn(12.0);

      var request = await client.openUrl('get', url);
      var capturedStartArgs = verify(
        () => mockRum.startResource(
          captureAny(),
          RumHttpMethod.get,
          url.toString(),
          any(),
        ),
      ).captured;
      var capturedKey = capturedStartArgs[0] as String;
      var mockResponse = setupMockClientResponse(200, size: 12345);

      completer.complete(mockResponse);
      var response = await request.done;
      response.listen((event) {});
      await mockResponse.streamController.close();

      final capturedEndArgs = verify(() => mockRum.stopResource(
            capturedKey,
            200,
            RumResourceType.image,
            12345,
            captureAny(),
          )).captured;
      final capturedAttributes = capturedEndArgs[0] as Map<String, dynamic>;

      expect(
          capturedAttributes[DatadogRumPlatformAttributeKey.traceID], isNull);
      expect(capturedAttributes[DatadogRumPlatformAttributeKey.spanID], isNull);
      expect(capturedAttributes[DatadogRumPlatformAttributeKey.rulePsr], 0.12);
    });

    test('ignoreUrlPatterns does not perform tracking on matching url',
        () async {
      var url = Uri.parse('https://test_url/ignored/test');
      final completer = setupMockRequest(url);

      // when(() => mockRum.shouldSampleTrace()).thenReturn(false);
      // when(() => mockRum.traceSampleRate).thenReturn(12.0);

      var request = await client.openUrl('get', url);
      var mockResponse = setupMockClientResponse(200, size: 12345);

      completer.complete(mockResponse);
      var response = await request.done;
      response.listen((event) {});
      await mockResponse.streamController.close();

      verifyNoMoreInteractions(mockRum);
    });

    test(
        'ignoreUrlPatterns does not perform tracking on matching url even though innerClient throw error',
        () async {
      const error = SocketException('Mock socket exception');
      when(() => mockClient.openUrl(any(), any())).thenThrow(error);
      final client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(ignoreUrlPatterns: [
          RegExp('test_url/path'),
        ]),
        mockClient,
      );

      var url = Uri.parse('https://test_url/path');

      await expectLater(() async => await client.openUrl('get', url),
          throwsA(predicate((e) => e == error)));

      verifyNoMoreInteractions(mockRum);
    });

    test('error on openUrl stops resource with error', () async {
      const error = SocketException('Mock socket exception');
      when(() => mockClient.openUrl(any(), any())).thenThrow(error);
      final client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(),
        mockClient,
      );

      var url = Uri.parse('https://test_url/path');

      await expectLater(() async => await client.openUrl('get', url),
          throwsA(predicate((e) => e == error)));
      var capturedKey = verify(() => mockRum.startResource(
              captureAny(), RumHttpMethod.get, url.toString(), any()))
          .captured[0] as String;
      verify(() => mockRum.stopResourceWithErrorInfo(
            capturedKey,
            error.toString(),
            error.runtimeType.toString(),
          ));
    });

    test('error on close stops resource with error preserving stack', () async {
      const error = SocketException('Mock socket exception');
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);

      when(() => mockRequest.uri).thenReturn(url);

      var request = await client.openUrl('get', url);
      verify(() => mockClient.openUrl('get', url));
      var capturedKey = verify(
        () => mockRum.startResource(
            captureAny(), RumHttpMethod.get, url.toString(), any()),
      ).captured[0] as String;

      final stack = StackTrace.current;
      completer.completeError(error, stack);
      try {
        await request.close();
      } catch (e, st) {
        expect(st, stack);
        expect(e, error);
      }
      verify(() => mockRum.stopResourceWithErrorInfo(
            capturedKey,
            error.toString(),
            error.runtimeType.toString(),
            any(),
          ));
    });

    test('error on done stops resource with error preserving stack', () async {
      const error = SocketException('Mock socket exception');
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);

      when(() => mockRequest.uri).thenReturn(url);

      var request = await client.openUrl('get', url);
      verify(() => mockClient.openUrl('get', url));
      var capturedKey = verify(
        () => mockRum.startResource(
            captureAny(), RumHttpMethod.get, url.toString(), any()),
      ).captured[0] as String;

      final stack = StackTrace.current;
      completer.completeError(error, stack);
      try {
        await request.done;
      } catch (e, st) {
        expect(st, stack);
        expect(e, error);
      }
      verify(() => mockRum.stopResourceWithErrorInfo(
            capturedKey,
            error.toString(),
            error.runtimeType.toString(),
            any(),
          ));
    });
  });

  for (final headerType in TracingHeaderType.values) {
    group('when rum is enabled with $headerType tracing headers', () {
      setUp(() {
        enableRum();

        when(() => mockDatadog.headerTypesForHost(
            any(that: HasHost(equals('test_url'))))).thenReturn({headerType});
      });

      test('start and stop resource loading set tracing attributes', () async {
        when(() => mockRum.traceSampleRate).thenReturn(23.0);

        var url = Uri.parse('https://test_url/path');
        final completer = setupMockRequest(url);
        final client = DatadogTrackingHttpClient(
          mockDatadog,
          DdHttpTrackingPluginConfiguration(),
          mockClient,
        );

        var request = await client.openUrl('get', url);
        var capturedStartArgs = verify(
          () => mockRum.startResource(
            captureAny(),
            RumHttpMethod.get,
            url.toString(),
            any(),
          ),
        ).captured;
        var capturedKey = capturedStartArgs[0] as String;

        var mockResponse = setupMockClientResponse(200, size: 12345);

        completer.complete(mockResponse);
        var response = await request.done;
        response.listen((event) {});
        await mockResponse.streamController.close();

        var capturedEndArgs = verify(() => mockRum.stopResource(
              capturedKey,
              200,
              RumResourceType.image,
              12345,
              captureAny(),
            )).captured;
        final capturedAttributes = capturedEndArgs[0] as Map<String, dynamic>;

        var traceInt = BigInt.parse(
            capturedAttributes[DatadogRumPlatformAttributeKey.traceID],
            radix: 16);
        expect(traceInt, isNotNull);
        expect(traceInt.bitLength, lessThanOrEqualTo(128));

        var spanInt = BigInt.parse(
            capturedAttributes[DatadogRumPlatformAttributeKey.spanID]);
        expect(spanInt, isNotNull);
        expect(spanInt.bitLength, lessThanOrEqualTo(63));

        expect(
            capturedAttributes[DatadogRumPlatformAttributeKey.rulePsr], 0.23);
      });

      test(
          'sets trace headers for first party urls { sampled, TraceContextInjection.all }',
          () async {
        var url = Uri.parse('https://test_url/path');
        var completer = setupMockRequest(url);
        var mockResponse = setupMockClientResponse(200);

        final client = DatadogTrackingHttpClient(
          mockDatadog,
          DdHttpTrackingPluginConfiguration(),
          mockClient,
        );

        var request = await client.openUrl('get', url);
        completer.complete(mockResponse);

        var _ = await request.done;

        final requestHeaders = request.headers.toMap();
        verifyHeaders(
            requestHeaders, headerType, true, TraceContextInjection.all);
      });

      test(
          'sets trace headers for first party urls { unsampled, TraceContextInjection.all }',
          () async {
        when(() => mockRum.shouldSampleTrace()).thenReturn(false);
        var url = Uri.parse('https://test_url/path');
        var completer = setupMockRequest(url);
        var mockResponse = setupMockClientResponse(200);

        final client = DatadogTrackingHttpClient(
          mockDatadog,
          DdHttpTrackingPluginConfiguration(),
          mockClient,
        );

        var request = await client.openUrl('get', url);
        completer.complete(mockResponse);

        var _ = await request.done;

        final requestHeaders = request.headers.toMap();
        verifyHeaders(
            requestHeaders, headerType, false, TraceContextInjection.all);
      });

      test(
          'sets trace headers for first party urls { sampled, TraceContextInjection.sampled }',
          () async {
        when(() => mockRum.contextInjectionSetting)
            .thenReturn(TraceContextInjection.sampled);
        var url = Uri.parse('https://test_url/path');
        var completer = setupMockRequest(url);
        var mockResponse = setupMockClientResponse(200);

        final client = DatadogTrackingHttpClient(
          mockDatadog,
          DdHttpTrackingPluginConfiguration(),
          mockClient,
        );

        var request = await client.openUrl('get', url);
        completer.complete(mockResponse);

        var _ = await request.done;

        final requestHeaders = request.headers.toMap();
        verifyHeaders(
            requestHeaders, headerType, true, TraceContextInjection.sampled);
      });

      test(
          'sets trace headers for first party urls { unsampled, TraceContextInjection.sampled }',
          () async {
        when(() => mockRum.shouldSampleTrace()).thenReturn(false);
        when(() => mockRum.contextInjectionSetting)
            .thenReturn(TraceContextInjection.sampled);
        var url = Uri.parse('https://test_url/path');
        var completer = setupMockRequest(url);
        var mockResponse = setupMockClientResponse(200);

        final client = DatadogTrackingHttpClient(
          mockDatadog,
          DdHttpTrackingPluginConfiguration(),
          mockClient,
        );

        var request = await client.openUrl('get', url);
        completer.complete(mockResponse);

        var _ = await request.done;

        final requestHeaders = request.headers.toMap();
        verifyHeaders(
            requestHeaders, headerType, false, TraceContextInjection.sampled);
      });

      test('does not set trace headers for third party urls', () async {
        var url = Uri.parse('https://non_first_party/path');
        setupMockRequest(url);

        final client = DatadogTrackingHttpClient(
          mockDatadog,
          DdHttpTrackingPluginConfiguration(),
          mockClient,
        );

        var request = await client.openUrl('get', url);
        final requestHeaders = request.headers;

        var headers = [
          'x-datadog-sampling-priority',
          'x-datadog-trace-id',
          'x-datadog-parent-id',
          'b3',
          'X-B3-TraceId',
          'X-B3-SpanId',
          'X-B3-ParentSpanId',
          'X-B3-Sampled',
        ];
        for (var header in headers) {
          verifyNever(() => requestHeaders.add(header, any()));
        }
      });
    });
  }

  test('different hosts can send different tracing headers', () async {
    enableRum();

    when(() => mockDatadog
            .headerTypesForHost(any(that: HasHost(equals('test_url_a')))))
        .thenReturn({TracingHeaderType.datadog});
    when(() => mockDatadog
            .headerTypesForHost(any(that: HasHost(equals('test_url_b')))))
        .thenReturn({TracingHeaderType.b3});

    final client = DatadogTrackingHttpClient(
      mockDatadog,
      DdHttpTrackingPluginConfiguration(),
      mockClient,
    );

    final testUriA = Uri.parse('https://test_url_a/test');
    final testUriB = Uri.parse('https://test_url_b/test');

    Future<void> verifyCall(Uri uri, TracingHeaderType headerType) async {
      final completer = setupMockRequest(uri);
      var mockResponse = setupMockClientResponse(200);

      var request = await client.openUrl('get', uri);
      completer.complete(mockResponse);

      var _ = await request.done;

      final requestHeaders = request.headers.toMap();
      verifyHeaders(
          requestHeaders, headerType, true, TraceContextInjection.all);
    }

    await verifyCall(testUriA, TracingHeaderType.datadog);
    await verifyCall(testUriB, TracingHeaderType.b3);
  });

  test('different tracing headers are same trace id', () async {
    // Given
    enableRum();
    when(() => mockDatadog
            .headerTypesForHost(any(that: HasHost(equals('test_url_a')))))
        .thenReturn(
            {TracingHeaderType.datadog, TracingHeaderType.tracecontext});

    // When
    final client = DatadogTrackingHttpClient(
      mockDatadog,
      DdHttpTrackingPluginConfiguration(),
      mockClient,
    );
    final testUri = Uri.parse('https://test_url_a/test');
    final completer = setupMockRequest(testUri);
    var mockResponse = setupMockClientResponse(200);
    var request = await client.openUrl('get', testUri);
    completer.complete(mockResponse);

    var response = await request.done;
    response.listen((event) {});
    await mockResponse.streamController.close();

    // Then
    final callAttributes = verify(() =>
            mockRum.stopResource(any(), any(), any(), any(), captureAny()))
        .captured[0] as Map<String, Object?>;

    final traceValue = callAttributes['_dd.trace_id'] as String?;
    final traceInt =
        traceValue != null ? BigInt.tryParse(traceValue, radix: 16) : null;
    expect(traceInt, isNotNull);
    expect(traceInt?.bitLength, lessThanOrEqualTo(128));

    final spanValue = callAttributes['_dd.span_id'] as String?;
    final spanInt = spanValue != null ? BigInt.tryParse(spanValue) : null;
    expect(spanInt, isNotNull);
    expect(spanInt?.bitLength, lessThanOrEqualTo(63));

    final headers = request.headers;
    final datadogTraceString =
        verify(() => headers.add('x-datadog-trace-id', captureAny()))
            .captured[0];
    final datadogTraceInt = BigInt.tryParse(datadogTraceString);
    expect(traceInt! & lowTraceMask, datadogTraceInt);
    final datadogTagString =
        verify(() => headers.add('x-datadog-tags', captureAny())).captured[0]
            as String?;
    final parts = datadogTagString?.split('=');
    expect(parts?[0], '_dd.p.tid');
    BigInt? highTraceInt = BigInt.tryParse(parts?[1] ?? '', radix: 16);
    expect(highTraceInt, isNotNull);
    expect(highTraceInt, traceInt >> 64);

    final datadogSpanString =
        verify(() => headers.add('x-datadog-parent-id', captureAny()))
            .captured[0];
    final datadogSpanInt = BigInt.tryParse(datadogSpanString);
    expect(spanInt, datadogSpanInt);

    final traceContextString =
        verify(() => headers.add('traceparent', captureAny())).captured[0]
            as String;
    final tracecontextParts = traceContextString.split('-');
    final contextTraceInt = BigInt.tryParse(tracecontextParts[1], radix: 16);
    expect(traceInt, contextTraceInt);
    final contextSpanInt = BigInt.tryParse(tracecontextParts[2], radix: 16);
    expect(spanInt, contextSpanInt);
  });

  group('when rum is enabled with b3 tracing headers', () {
    setUp(() {
      enableRum();

      when(() => mockDatadog
              .headerTypesForHost(any(that: HasHost(equals('test_url')))))
          .thenReturn({TracingHeaderType.b3});
    });

    test('does not set trace headers when should sample returns false',
        () async {
      when(() => mockRum.shouldSampleTrace()).thenReturn(false);
      var url = Uri.parse('https://test_url/path');
      var completer = setupMockRequest(url);
      var mockResponse = setupMockClientResponse(200);

      final client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(),
        mockClient,
      );

      var request = await client.openUrl('get', url);
      completer.complete(mockResponse);

      var _ = await request.done;
      final requestHeaders = request.headers;

      verify(() => requestHeaders.add('b3', '0'));
    });
  });

  group('when rum is enabled with b3multi tracing headers', () {
    setUp(() {
      enableRum();

      when(() => mockDatadog
              .headerTypesForHost(any(that: HasHost(equals('test_url')))))
          .thenReturn({TracingHeaderType.b3multi});
    });

    test('does not set trace headers when should sample returns false',
        () async {
      when(() => mockRum.shouldSampleTrace()).thenReturn(false);
      var url = Uri.parse('https://test_url/path');
      var completer = setupMockRequest(url);
      var mockResponse = setupMockClientResponse(200);

      final client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(),
        mockClient,
      );

      var request = await client.openUrl('get', url);
      completer.complete(mockResponse);

      var _ = await request.done;
      final requestHeaders = request.headers;

      verifyNever(() => requestHeaders.add('X-B3-TraceId', any()));
      verifyNever(() => requestHeaders.add('X-B3-SpanId', any()));
      verify(() => requestHeaders.add('X-B3-Sampled', '0'));
    });
  });

  group('when rum is enabled with a client listener', () {
    setUp(() {
      enableRum();
    });

    test('listener is called with the request after the request starts',
        () async {
      var url = Uri.parse('https://test_url/path');
      setupMockRequest(url);
      final mockListener = MockTrackingHttpClientListener();
      final client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(clientListener: mockListener),
        mockClient,
      );
      final request = await client.openUrl('get', url);

      verify(() => mockListener.requestStarted(
          resourceKey: any(named: 'resourceKey'),
          request: request,
          userAttributes: {}));
    });

    test('attributes returned from resourceStarted are added to stopResource',
        () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);
      final mockListener = MockTrackingHttpClientListener();
      when(() => mockListener.requestStarted(
            resourceKey: any(named: 'resourceKey'),
            request: any(named: 'request'),
            userAttributes: any(named: 'userAttributes'),
          )).thenAnswer((invocation) {
        var attrs = invocation.namedArguments[const Symbol('userAttributes')]
            as Map<String, Object?>;
        attrs['my_parameter'] = 'my_value';
        attrs['other_parameter'] = 123;
      });

      final client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(clientListener: mockListener),
        mockClient,
      );
      final request = await client.openUrl('get', url);

      final mockResponse = setupMockClientResponse(403);
      completer.complete(mockResponse);
      var response = await request.done;
      response.listen((event) {});
      await mockResponse.streamController.close();

      final captured = verify(() =>
              mockRum.stopResource(any(), 403, any(), any(), captureAny()))
          .captured;
      expect(captured[0]['my_parameter'], 'my_value');
      expect(captured[0]['other_parameter'], 123);
    });

    test(
        'attributes returned from resourceStarted are added to stopResource if resource fails',
        () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);
      final mockListener = MockTrackingHttpClientListener();
      when(() => mockListener.requestStarted(
              resourceKey: any(named: 'resourceKey'),
              request: any(named: 'request'),
              userAttributes: any(named: 'userAttributes')))
          .thenAnswer((invocation) {
        var attrs = invocation.namedArguments[const Symbol('userAttributes')]
            as Map<String, Object?>;
        attrs['my_parameter'] = 'my_value';
        attrs['other_parameter'] = 123;
      });
      final client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(clientListener: mockListener),
        mockClient,
      );
      final request = await client.openUrl('get', url);
      final mockResponse = setupMockClientResponse(200);
      completer.complete(mockResponse);
      var response = await request.done;

      // Listen / close the response
      var error = Error();
      response.listen((event) {});
      mockResponse.streamController.addError(error);
      await mockResponse.streamController.close();

      var capturedAttributes = verify(() => mockRum.stopResourceWithErrorInfo(
            any(),
            error.toString(),
            error.runtimeType.toString(),
            captureAny(),
          )).captured[0];
      expect(capturedAttributes['my_parameter'], 'my_value');
      expect(capturedAttributes['other_parameter'], 123);
    });

    test('listener is called with response when response finishes successfully',
        () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);
      final mockListener = MockTrackingHttpClientListener();

      final client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(clientListener: mockListener),
        mockClient,
      );
      final request = await client.openUrl('get', url);

      final mockResponse = setupMockClientResponse(200);
      completer.complete(mockResponse);
      var response = await request.done;
      response.listen((event) {});
      await mockResponse.streamController.close();

      verify(() => mockListener.responseFinished(
            resourceKey: any(named: 'resourceKey'),
            response: response,
            userAttributes: any(named: 'userAttributes'),
            error: null,
          ));
    });

    test('listener is called with response when response finishes with error',
        () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);
      final mockListener = MockTrackingHttpClientListener();

      final client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(clientListener: mockListener),
        mockClient,
      );
      final request = await client.openUrl('get', url);

      final mockResponse = setupMockClientResponse(500);
      completer.complete(mockResponse);
      var response = await request.done;
      response.listen((event) {});
      var error = Error();
      mockResponse.streamController.addError(error);
      await mockResponse.streamController.close();

      verify(() => mockListener.responseFinished(
            resourceKey: any(named: 'resourceKey'),
            response: response,
            userAttributes: any(named: 'userAttributes'),
            error: error,
          ));
    });

    test('attributes returned from resourceFinished are added to stopResource',
        () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);
      final mockListener = MockTrackingHttpClientListener();
      final client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(clientListener: mockListener),
        mockClient,
      );
      final request = await client.openUrl('get', url);

      final mockResponse = setupMockClientResponse(200);
      when(() => mockListener.responseFinished(
              resourceKey: any(named: 'resourceKey'),
              response: any(named: 'response'),
              userAttributes: any(named: 'userAttributes')))
          .thenAnswer((invocation) {
        var attrs = invocation.namedArguments[const Symbol('userAttributes')]
            as Map<String, Object?>;
        attrs['my_parameter'] = 'my_value';
        attrs['other_parameter'] = 123;
      });

      completer.complete(mockResponse);
      var response = await request.done;

      // Listen / close the response
      response.listen((event) {});
      await mockResponse.streamController.close();

      var capturedAttributes = verify(() =>
              mockRum.stopResource(any(), 200, any(), any(), captureAny()))
          .captured[0];
      expect(capturedAttributes['my_parameter'], 'my_value');
      expect(capturedAttributes['other_parameter'], 123);
    });

    test(
        'attributes returned from resourceFinished are added to stopResource if resource fails',
        () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);
      final mockListener = MockTrackingHttpClientListener();
      when(() => mockListener.requestStarted(
              resourceKey: any(named: 'resourceKey'),
              request: any(named: 'request'),
              userAttributes: any(named: 'userAttributes')))
          .thenAnswer((invocation) {
        var attrs = invocation.namedArguments[const Symbol('userAttributes')]
            as Map<String, Object?>;
        attrs['my_parameter'] = 'my_value';
        attrs['other_parameter'] = 123;
      });

      final client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(clientListener: mockListener),
        mockClient,
      );
      final request = await client.openUrl('get', url);

      final mockResponse = setupMockClientResponse(200);
      completer.complete(mockResponse);
      var response = await request.done;

      // Listen / close the response
      var error = Error();
      response.listen((event) {});
      mockResponse.streamController.addError(error);
      await mockResponse.streamController.close();

      var capturedAttributes = verify(() => mockRum.stopResourceWithErrorInfo(
          any(),
          error.toString(),
          error.runtimeType.toString(),
          captureAny())).captured[0];
      expect(capturedAttributes['my_parameter'], 'my_value');
      expect(capturedAttributes['other_parameter'], 123);
    });

    test(
        'attributes returned from resourceStarted and resourceFinished are merged',
        () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);
      final mockListener = MockTrackingHttpClientListener();
      Object? requestKey;
      when(() => mockListener.requestStarted(
              resourceKey: any(named: 'resourceKey'),
              request: any(named: 'request'),
              userAttributes: any(named: 'userAttributes')))
          .thenAnswer((invocation) {
        requestKey = invocation.namedArguments[const Symbol('resourceKey')];
        var attrs = invocation.namedArguments[const Symbol('userAttributes')]
            as Map<String, Object?>;
        attrs['my_parameter'] = 'my_value';
        attrs['other_parameter'] = 123;
      });

      final client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(clientListener: mockListener),
        mockClient,
      );
      final request = await client.openUrl('get', url);

      final mockResponse = setupMockClientResponse(200);
      completer.complete(mockResponse);

      Object? responseKey;
      when(() => mockListener.responseFinished(
            resourceKey: any(named: 'resourceKey'),
            response: any(named: 'response'),
            userAttributes: any(named: 'userAttributes'),
            error: any(named: 'error'),
          )).thenAnswer((invocation) {
        responseKey = invocation.namedArguments[const Symbol('resourceKey')];

        var attrs = invocation.namedArguments[const Symbol('userAttributes')]
            as Map<String, Object?>;
        attrs['response_parameter'] = 'second_value';
        attrs['extra_parameter'] = 1928;
      });

      var response = await request.done;

      // Listen / close the response
      response.listen((event) {});
      await mockResponse.streamController.close();

      expect(requestKey, isNotNull);
      expect(requestKey, responseKey);
      var capturedAttributes = verify(() =>
              mockRum.stopResource(any(), any(), any(), any(), captureAny()))
          .captured[0];
      expect(capturedAttributes['my_parameter'], 'my_value');
      expect(capturedAttributes['other_parameter'], 123);
      expect(capturedAttributes['response_parameter'], 'second_value');
      expect(capturedAttributes['extra_parameter'], 1928);
    });

    test('attributes can be overwritten in resourceFinished', () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);
      final mockListener = MockTrackingHttpClientListener();
      Object? requestKey;
      when(() => mockListener.requestStarted(
              resourceKey: any(named: 'resourceKey'),
              request: any(named: 'request'),
              userAttributes: any(named: 'userAttributes')))
          .thenAnswer((invocation) {
        requestKey = invocation.namedArguments[const Symbol('resourceKey')];
        var attrs = invocation.namedArguments[const Symbol('userAttributes')]
            as Map<String, Object?>;
        attrs['my_parameter'] = 'my_value';
        attrs['other_parameter'] = 123;
      });

      final client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(clientListener: mockListener),
        mockClient,
      );
      final request = await client.openUrl('get', url);

      final mockResponse = setupMockClientResponse(200);
      completer.complete(mockResponse);
      Object? responseKey;
      when(() => mockListener.responseFinished(
            resourceKey: any(named: 'resourceKey'),
            response: any(named: 'response'),
            userAttributes: any(named: 'userAttributes'),
            error: any(named: 'error'),
          )).thenAnswer((invocation) {
        responseKey = invocation.namedArguments[const Symbol('resourceKey')];
        var attrs = invocation.namedArguments[const Symbol('userAttributes')]
            as Map<String, Object?>;
        attrs['my_parameter'] = 'second_value';
        attrs['extra_parameter'] = 1928;
      });

      var response = await request.done;

      // Listen / close the response
      response.listen((event) {});
      await mockResponse.streamController.close();

      expect(requestKey, isNotNull);
      expect(requestKey, responseKey);
      var capturedAttributes = verify(() =>
              mockRum.stopResource(any(), any(), any(), any(), captureAny()))
          .captured[0];
      expect(capturedAttributes['my_parameter'], 'second_value');
      expect(capturedAttributes['other_parameter'], 123);
      expect(capturedAttributes['extra_parameter'], 1928);
    });
  });

  group(
    'when is an attach configuration',
    () {
      test(
        'should add ignoreUrlPatterns to DdHttpTrackingPluginConfiguration',
        () {
          final ignoreUrlPatterns = [RegExp('teste')];

          final configuration = DatadogAttachConfiguration()
            ..enableHttpTracking(
              ignoreUrlPatterns: ignoreUrlPatterns,
            );

          expect(
              (configuration.additionalPlugins.first
                      as DdHttpTrackingPluginConfiguration)
                  .ignoreUrlPatterns,
              ignoreUrlPatterns);
        },
      );
    },
  );
}
