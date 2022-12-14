// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:async';
import 'dart:io';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_tracking_http_client/src/tracking_http_client.dart';
import 'package:datadog_tracking_http_client/src/tracking_http_client_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'test_utils.dart';

class MockDatadogSdk extends Mock implements DatadogSdk {}

class MockDatadogSdkPlatform extends Mock implements DatadogSdkPlatform {}

class MockDdRum extends Mock implements DdRum {}

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
  });

  setUp(() {
    mockPlatform = MockDatadogSdkPlatform();
    when(() => mockPlatform.updateTelemetryConfiguration(any(), any()))
        .thenAnswer((_) => Future<void>.value());

    mockDatadog = MockDatadogSdk();
    when(() => mockDatadog.isFirstPartyHost(
        any(that: HasHost(equals('test_url'))))).thenReturn(true);
    when(() => mockDatadog.isFirstPartyHost(
        any(that: HasHost(equals('non_first_party'))))).thenReturn(false);
    when(() => mockDatadog.platform).thenReturn(mockPlatform);

    mockRum = MockDdRum();
    when(() => mockRum.shouldSampleTrace()).thenReturn(true);
    when(() => mockRum.tracingSamplingRate).thenReturn(50.0);

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

  void verifyHeaders(HttpHeaders headers, TracingHeaderType type) {
    BigInt? traceInt;
    BigInt? spanInt;

    switch (type) {
      case TracingHeaderType.dd:
        verify(() => headers.add('x-datadog-sampling-priority', '1'));
        var traceValue =
            verify(() => headers.add('x-datadog-trace-id', captureAny()))
                .captured[0] as String;
        traceInt = BigInt.tryParse(traceValue);
        var spanValue =
            verify(() => headers.add('x-datadog-parent-id', captureAny()))
                .captured[0] as String;
        spanInt = BigInt.tryParse(spanValue);
        break;
      case TracingHeaderType.b3s:
        var singleHeader =
            verify(() => headers.add('b3', captureAny())).captured[0] as String;
        var headerParts = singleHeader.split('-');
        traceInt = BigInt.tryParse(headerParts[0], radix: 16);
        spanInt = BigInt.tryParse(headerParts[1], radix: 16);
        expect(headerParts[2], '1');
        break;
      case TracingHeaderType.b3m:
        verify(() => headers.add('X-B3-Sampled', '1'));
        var traceValue = verify(() => headers.add('X-B3-TraceId', captureAny()))
            .captured[0] as String;
        traceInt = BigInt.tryParse(traceValue, radix: 16);
        var spanValue = verify(() => headers.add('X-B3-SpanId', captureAny()))
            .captured[0] as String;
        spanInt = BigInt.tryParse(spanValue, radix: 16);
        break;
    }

    expect(traceInt, isNotNull);
    expect(traceInt?.bitLength, lessThanOrEqualTo(63));

    expect(spanInt, isNotNull);
    expect(spanInt?.bitLength, lessThanOrEqualTo(63));
  }

  group('when rum is disabled', () {
    setUp(() {
      when(() => mockDatadog.rum).thenReturn(null);
    });

    test('tracking client passes through properties', () {
      final client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(
          tracingHeaderTypes: {TracingHeaderType.dd},
        ),
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
        DdHttpTrackingPluginConfiguration(
          tracingHeaderTypes: {TracingHeaderType.dd},
        ),
        mockClient,
      );

      await client.openUrl('get', url);

      verify(() => mockClient.openUrl('get', url));
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
          tracingHeaderTypes: {TracingHeaderType.dd},
        ),
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
        () => mockRum.startResourceLoading(
            captureAny(), RumHttpMethod.get, url.toString(), any()),
      ).captured[0] as String;

      verifyNever(() => mockRum.stopResourceLoading(any(), any(), any()));

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
      verify(() => mockRum.stopResourceLoading(
          capturedKey, 200, RumResourceType.image, 88888, any()));
    });

    test('calls stop resource with status code', () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);

      var request = await client.openUrl('get', url);

      verify(() => mockClient.openUrl('get', url));
      var capturedKey = verify(
        () => mockRum.startResourceLoading(
            captureAny(), RumHttpMethod.get, url.toString(), any()),
      ).captured[0] as String;

      verifyNever(() => mockRum.stopResourceLoading(any(), any(), any()));

      final mockResponse = setupMockClientResponse(403);
      completer.complete(mockResponse);
      var response = await request.done;
      response.listen((event) {});
      await mockResponse.streamController.close();

      verify(() => mockRum.stopResourceLoading(
          capturedKey, 403, RumResourceType.image, 88888, any()));
    });

    test('sets resource type from headers', () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);

      var request = await client.openUrl('get', url);

      verify(() => mockClient.openUrl('get', url));
      var capturedKey = verify(
        () => mockRum.startResourceLoading(
            captureAny(), RumHttpMethod.get, url.toString(), any()),
      ).captured[0] as String;

      final mockResponse = setupMockClientResponse(200, mimeType: 'video/mp4');
      completer.complete(mockResponse);
      var response = await request.done;

      response.listen((event) {});
      await mockResponse.streamController.close();

      verify(() => mockRum.stopResourceLoading(
          capturedKey, 200, RumResourceType.media, 88888, any()));
    });

    test('calls stop resource with error connection error', () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);

      var request = await client.openUrl('get', url);
      var capturedKey = verify(
        () => mockRum.startResourceLoading(
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
      verify(() => mockRum.stopResourceLoadingWithErrorInfo(
          capturedKey, error.toString(), error.runtimeType.toString(), any()));
    });

    test('calls stop resource with error for response error', () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);

      var request = await client.openUrl('get', url);
      var capturedKey = verify(
        () => mockRum.startResourceLoading(
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
      verify(() => mockRum.stopResourceLoadingWithErrorInfo(
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
      when(() => mockRum.tracingSamplingRate).thenReturn(12.0);

      var request = await client.openUrl('get', url);
      var capturedStartArgs = verify(
        () => mockRum.startResourceLoading(
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

      final capturedEndArgs = verify(() => mockRum.stopResourceLoading(
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

    test('extracts b3s headers and sets attributes', () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);

      final mockHeaders = mockRequest.headers;
      // Randomly generated
      //  - 714e65427868bdc8 == 8164574510631665096
      //  - 7386a57f63c48531 == 8324522927794193713
      //
      mockHeaders.add(
          'b3', '0000000000000000714e65427868bdc8-7386a57f63c48531-1');
      when(() => mockRum.tracingSamplingRate).thenReturn(23.0);

      var request = await client.openUrl('get', url);
      var capturedStartArgs = verify(
        () => mockRum.startResourceLoading(
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

      var capturedEndArgs = verify(() => mockRum.stopResourceLoading(
            capturedKey,
            200,
            RumResourceType.image,
            12345,
            captureAny(),
          )).captured;
      final capturedAttributes = capturedEndArgs[0] as Map<String, dynamic>;

      var traceInt = BigInt.parse(
          capturedAttributes[DatadogRumPlatformAttributeKey.traceID]);
      expect(traceInt, BigInt.from(0x714e65427868bdc8));
      var spanInt = BigInt.parse(
          capturedAttributes[DatadogRumPlatformAttributeKey.spanID]);
      expect(spanInt, BigInt.from(0x7386a57f63c48531));
      expect(capturedAttributes[DatadogRumPlatformAttributeKey.rulePsr], 0.23);

      expect(mockHeaders.value('x-datadog-trace-id'), '8164574510631665096');
      expect(mockHeaders.value('x-datadog-parent-id'), '8324522927794193713');
    });

    test('extracts b3m headers and sets attributes', () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);

      final mockHeaders = mockRequest.headers;
      // Randomly generated
      //  - 714e65427868bdc8 == 8164574510631665096
      //  - 7386a57f63c48531 == 8324522927794193713
      //
      mockHeaders.add('X-B3-TraceId', '0000000000000000714e65427868bdc8');
      mockHeaders.add('X-B3-SpanId', '7386a57f63c48531');
      mockHeaders.add('X-B3-Sampled', '1');
      when(() => mockRum.tracingSamplingRate).thenReturn(23.0);

      var request = await client.openUrl('get', url);
      var capturedStartArgs = verify(
        () => mockRum.startResourceLoading(
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

      var capturedEndArgs = verify(() => mockRum.stopResourceLoading(
            capturedKey,
            200,
            RumResourceType.image,
            12345,
            captureAny(),
          )).captured;
      final capturedAttributes = capturedEndArgs[0] as Map<String, dynamic>;

      var traceInt = BigInt.parse(
          capturedAttributes[DatadogRumPlatformAttributeKey.traceID]);
      expect(traceInt, BigInt.from(0x714e65427868bdc8));
      var spanInt = BigInt.parse(
          capturedAttributes[DatadogRumPlatformAttributeKey.spanID]);
      expect(spanInt, BigInt.from(0x7386a57f63c48531));
      expect(capturedAttributes[DatadogRumPlatformAttributeKey.rulePsr], 0.23);

      expect(mockHeaders.value('x-datadog-trace-id'), '8164574510631665096');
      expect(mockHeaders.value('x-datadog-parent-id'), '8324522927794193713');
    });

    test('extracts b3m headers and sets attributes case insensitive', () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);

      final mockHeaders = mockRequest.headers;
      // Randomly generated
      //  - 714e65427868bdc8 == 8164574510631665096
      //  - 7386a57f63c48531 == 8324522927794193713
      //
      mockHeaders.add('x-b3-traceid', '0000000000000000714e65427868bdc8');
      mockHeaders.add('x-b3-spanid', '7386a57f63c48531');
      mockHeaders.add('x-b3-sampled', '1');
      when(() => mockRum.tracingSamplingRate).thenReturn(23.0);

      var request = await client.openUrl('get', url);
      var capturedStartArgs = verify(
        () => mockRum.startResourceLoading(
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

      var capturedEndArgs = verify(() => mockRum.stopResourceLoading(
            capturedKey,
            200,
            RumResourceType.image,
            12345,
            captureAny(),
          )).captured;
      final capturedAttributes = capturedEndArgs[0] as Map<String, dynamic>;

      var traceInt = BigInt.parse(
          capturedAttributes[DatadogRumPlatformAttributeKey.traceID]);
      expect(traceInt, BigInt.from(0x714e65427868bdc8));
      var spanInt = BigInt.parse(
          capturedAttributes[DatadogRumPlatformAttributeKey.spanID]);
      expect(spanInt, BigInt.from(0x7386a57f63c48531));
      expect(capturedAttributes[DatadogRumPlatformAttributeKey.rulePsr], 0.23);

      expect(mockHeaders.value('x-datadog-trace-id'), '8164574510631665096');
      expect(mockHeaders.value('x-datadog-parent-id'), '8324522927794193713');
    });

    test('extracts b3s unsampled to datadog unsampled', () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);

      final mockHeaders = mockRequest.headers;
      mockHeaders.add('b3', '0');
      when(() => mockRum.tracingSamplingRate).thenReturn(23.0);

      var request = await client.openUrl('get', url);
      var capturedStartArgs = verify(
        () => mockRum.startResourceLoading(
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

      var capturedEndArgs = verify(() => mockRum.stopResourceLoading(
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
      expect(capturedAttributes[DatadogRumPlatformAttributeKey.rulePsr], 0.23);

      expect(mockHeaders.value('x-datadog-sampling-priority'), '0');
    });

    test('extracts b3m unsampled to datadog unsampled', () async {
      var url = Uri.parse('https://test_url/path');
      final completer = setupMockRequest(url);

      final mockHeaders = mockRequest.headers;
      mockHeaders.add('X-B3-Sampled', '0');
      when(() => mockRum.tracingSamplingRate).thenReturn(23.0);

      var request = await client.openUrl('get', url);
      var capturedStartArgs = verify(
        () => mockRum.startResourceLoading(
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

      var capturedEndArgs = verify(() => mockRum.stopResourceLoading(
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
      expect(capturedAttributes[DatadogRumPlatformAttributeKey.rulePsr], 0.23);

      expect(mockHeaders.value('x-datadog-sampling-priority'), '0');
    });
  });

  for (final headerType in TracingHeaderType.values) {
    group('when rum is enabled with $headerType tracing headers', () {
      setUp(() {
        enableRum();
      });

      test('start and stop resource loading set tracing attributes', () async {
        when(() => mockRum.tracingSamplingRate).thenReturn(23.0);

        var url = Uri.parse('https://test_url/path');
        final completer = setupMockRequest(url);
        final client = DatadogTrackingHttpClient(
          mockDatadog,
          DdHttpTrackingPluginConfiguration(
            tracingHeaderTypes: {headerType},
          ),
          mockClient,
        );

        var request = await client.openUrl('get', url);
        var capturedStartArgs = verify(
          () => mockRum.startResourceLoading(
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

        var capturedEndArgs = verify(() => mockRum.stopResourceLoading(
              capturedKey,
              200,
              RumResourceType.image,
              12345,
              captureAny(),
            )).captured;
        final capturedAttributes = capturedEndArgs[0] as Map<String, dynamic>;

        var traceInt = BigInt.parse(
            capturedAttributes[DatadogRumPlatformAttributeKey.traceID]);
        expect(traceInt, isNotNull);
        expect(traceInt.bitLength, lessThanOrEqualTo(63));

        var spanInt = BigInt.parse(
            capturedAttributes[DatadogRumPlatformAttributeKey.spanID]);
        expect(spanInt, isNotNull);
        expect(spanInt.bitLength, lessThanOrEqualTo(63));

        expect(
            capturedAttributes[DatadogRumPlatformAttributeKey.rulePsr], 0.23);
      });

      test('sets trace headers for first party urls', () async {
        var url = Uri.parse('https://test_url/path');
        var completer = setupMockRequest(url);
        var mockResponse = setupMockClientResponse(200);

        final client = DatadogTrackingHttpClient(
          mockDatadog,
          DdHttpTrackingPluginConfiguration(
            tracingHeaderTypes: {headerType},
          ),
          mockClient,
        );

        var request = await client.openUrl('get', url);
        completer.complete(mockResponse);

        var _ = await request.done;

        final requestHeaders = request.headers;
        verifyHeaders(requestHeaders, headerType);
      });

      test('does not set trace headers for third party urls', () async {
        var url = Uri.parse('https://non_first_party/path');
        setupMockRequest(url);

        final client = DatadogTrackingHttpClient(
          mockDatadog,
          DdHttpTrackingPluginConfiguration(
            tracingHeaderTypes: {headerType},
          ),
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

      test('error on openUrl stops resource with error', () async {
        const error = SocketException('Mock socket exception');
        when(() => mockClient.openUrl(any(), any())).thenThrow(error);
        final client = DatadogTrackingHttpClient(
          mockDatadog,
          DdHttpTrackingPluginConfiguration(
            tracingHeaderTypes: {headerType},
          ),
          mockClient,
        );

        var url = Uri.parse('https://test_url/path');

        await expectLater(() async => await client.openUrl('get', url),
            throwsA(predicate((e) => e == error)));
        var capturedKey = verify(() => mockRum.startResourceLoading(
                captureAny(), RumHttpMethod.get, url.toString(), any()))
            .captured[0] as String;
        verify(() => mockRum.stopResourceLoadingWithErrorInfo(
              capturedKey,
              error.toString(),
              error.runtimeType.toString(),
            ));
      });
    });
  }

  group('when rum is enabled with datadog tracing headers', () {
    late DatadogTrackingHttpClient client;

    setUp(() {
      enableRum();

      client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(
          tracingHeaderTypes: {TracingHeaderType.dd},
        ),
        mockClient,
      );
    });

    test('does not set trace headers when should sample returns false',
        () async {
      when(() => mockRum.shouldSampleTrace()).thenReturn(false);
      var url = Uri.parse('https://test_url/path');
      var completer = setupMockRequest(url);
      var mockResponse = setupMockClientResponse(200);

      var request = await client.openUrl('get', url);
      completer.complete(mockResponse);

      var _ = await request.done;
      final requestHeaders = request.headers;

      verifyNever(() => requestHeaders.add('x-datadog-trace-id', any()));
      verifyNever(() => requestHeaders.add('x-datadog-parent-id', any()));
      verify(() => requestHeaders.add('x-datadog-sampling-priority', '0'));
    });
  });

  group('when rum is enabled with b3s tracing headers', () {
    setUp(() {
      enableRum();
    });

    test('does not set trace headers when should sample returns false',
        () async {
      when(() => mockRum.shouldSampleTrace()).thenReturn(false);
      var url = Uri.parse('https://test_url/path');
      var completer = setupMockRequest(url);
      var mockResponse = setupMockClientResponse(200);

      final client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(
          tracingHeaderTypes: {TracingHeaderType.b3s},
        ),
        mockClient,
      );

      var request = await client.openUrl('get', url);
      completer.complete(mockResponse);

      var _ = await request.done;
      final requestHeaders = request.headers;

      verify(() => requestHeaders.add('b3', '0'));
    });
  });

  group('when rum is enabled with b3m tracing headers', () {
    setUp(() {
      enableRum();
    });

    test('does not set trace headers when should sample returns false',
        () async {
      when(() => mockRum.shouldSampleTrace()).thenReturn(false);
      var url = Uri.parse('https://test_url/path');
      var completer = setupMockRequest(url);
      var mockResponse = setupMockClientResponse(200);

      final client = DatadogTrackingHttpClient(
        mockDatadog,
        DdHttpTrackingPluginConfiguration(
          tracingHeaderTypes: {TracingHeaderType.b3m},
        ),
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
}
