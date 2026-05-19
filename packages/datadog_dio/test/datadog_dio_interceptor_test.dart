// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_common_test/uri_matchers.dart';
import 'package:datadog_dio/datadog_dio.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class DatadogPlatformMock extends Mock implements DatadogSdkPlatform {}

class DatadogSdkMock extends Mock implements DatadogSdk {}

class RumMock extends Mock implements DatadogRum {}

class InternalLoggerMock extends Mock implements InternalLogger {}

class RequestInterceptionHandlerMock extends Mock
    implements RequestInterceptorHandler {}

class ResponseInterceptionHandlerMock extends Mock
    implements ResponseInterceptorHandler {}

class ErrorInterceptorHandlerMock extends Mock
    implements ErrorInterceptorHandler {}

class DatadogDioAttributeProviderMock extends Mock
    implements DatadogDioAttributeProvider {}

void verifyHeaders(
  TracingHeaderType type,
  Map<String, dynamic> metadata,
  bool sampled,
  TraceContextInjection traceContextInjection,
) {
  BigInt? traceInt;
  BigInt? spanInt;

  bool shouldInjectHeaders =
      sampled || traceContextInjection == TraceContextInjection.all;

  switch (type) {
    case TracingHeaderType.datadog:
      if (shouldInjectHeaders) {
        expect(metadata['x-datadog-sampling-priority'], sampled ? '1' : '0');
        traceInt = BigInt.tryParse(metadata['x-datadog-trace-id'] ?? '');
        spanInt = BigInt.tryParse(metadata['x-datadog-parent-id'] ?? '');
        final tagsHeader = metadata['x-datadog-tags'];
        final parts = tagsHeader?.split('=');
        expect(parts, isNotNull);
        expect(parts?[0], '_dd.p.tid');
        BigInt? highTraceInt = BigInt.tryParse(parts?[1] ?? '', radix: 16);
        expect(highTraceInt, isNotNull);
        expect(highTraceInt?.bitLength, lessThanOrEqualTo(64));
      } else {
        expect(metadata['x-datadog-origin'], isNull);
        expect(metadata['x-datadog-sampling-priority'], isNull);
        expect(metadata['x-datadog-trace-id'], isNull);
        expect(metadata['x-datadog-parent-id'], isNull);
        expect(metadata['x-datadog-tags'], isNull);
      }
      break;
    case TracingHeaderType.b3:
      var singleHeader = metadata['b3'];
      if (sampled) {
        var headerParts = singleHeader!.split('-');
        traceInt = BigInt.tryParse(headerParts[0], radix: 16);
        spanInt = BigInt.tryParse(headerParts[1], radix: 16);
        expect(headerParts[2], '1');
      } else if (shouldInjectHeaders) {
        expect(singleHeader, '0');
      } else {
        expect(singleHeader, isNull);
      }
      break;
    case TracingHeaderType.b3multi:
      if (shouldInjectHeaders) {
        expect(metadata['x-b3-sampled'], sampled ? '1' : '0');
        if (sampled) {
          traceInt = BigInt.tryParse(metadata['x-b3-traceid'] ?? '', radix: 16);
          spanInt = BigInt.tryParse(metadata['x-b3-spanid'] ?? '', radix: 16);
        }
      } else {
        expect(metadata['X-B3-Sampled'], isNull);
        expect(metadata['X-B3-TraceId'], isNull);
        expect(metadata['X-B3-SpanId'], isNull);
      }
      break;
    case TracingHeaderType.tracecontext:
      if (shouldInjectHeaders) {
        var parentHeader = metadata['traceparent']!;
        var headerParts = parentHeader.split('-');
        expect(headerParts[0], '00');
        traceInt = BigInt.tryParse(headerParts[1], radix: 16);
        spanInt = BigInt.tryParse(headerParts[2], radix: 16);
        expect(headerParts[3], sampled ? '01' : '00');

        final stateHeader = metadata['tracestate']!;
        final stateParts = getDdTraceState(stateHeader);
        expect(stateParts['s'], sampled ? '1' : '0');
        expect(stateParts['o'], 'rum');
        expect(stateParts['p'], headerParts[2]);
      } else {
        expect(metadata['traceparent'], isNull);
      }
      break;
  }

  if (sampled) {
    expect(traceInt, isNotNull);
  }
  if (traceInt != null) {
    if (type == TracingHeaderType.datadog) {
      expect(traceInt.bitLength, lessThanOrEqualTo(64));
    } else {
      expect(traceInt.bitLength, lessThanOrEqualTo(128));
    }
  }

  if (sampled) {
    expect(spanInt, isNotNull);
  }
  if (spanInt != null) {
    expect(spanInt.bitLength, lessThanOrEqualTo(63));
  }
}

void main() {
  late DatadogPlatformMock mockPlatform;
  late DatadogSdkMock mockDatadog;
  late RumMock mockRum;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(RumHttpMethod.get);
    registerFallbackValue(RumResourceType.beacon);
    registerFallbackValue(StackTrace.current);
    registerFallbackValue(RequestOptions());
    registerFallbackValue(Response(requestOptions: RequestOptions()));
    registerFallbackValue(DioException(requestOptions: RequestOptions()));
    registerFallbackValue(TracingId.zero());
  });

  setUp(() {
    mockPlatform = DatadogPlatformMock();

    mockDatadog = DatadogSdkMock();
    when(() => mockDatadog.platform).thenReturn(mockPlatform);
    when(() => mockDatadog
            .headerTypesForHost(any(that: HasHost(equals('test_url')))))
        .thenReturn({TracingHeaderType.datadog});
    //when(() => mockDatadog.platform).thenReturn(mockPlatform);
    // ignore: invalid_use_of_internal_member
    when(() => mockDatadog.internalLogger).thenReturn(InternalLoggerMock());

    mockRum = RumMock();
    when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(true);
    when(() => mockRum.traceSampleRate).thenReturn(50.0);
  });

  group('when rum is disabled', () {
    setUp(() {
      when(() => mockDatadog.rum).thenReturn(null);
    });

    test('the interceptor forwards request unaltered', () {
      // Given
      final interceptor = DatadogDioInterceptor(datadogSdk: mockDatadog);
      final requestOptions =
          RequestOptions(path: 'https://test_uri', headers: {});

      // When
      final handler = RequestInterceptionHandlerMock();
      interceptor.onRequest(requestOptions, handler);

      // Then
      verify(() => handler.next(requestOptions));
    });

    test('the interceptor forwards response unaltered', () {
      // Given
      final interceptor = DatadogDioInterceptor(datadogSdk: mockDatadog);
      final requestOptions =
          RequestOptions(path: 'https://test_uri', headers: {});
      final response = Response(requestOptions: requestOptions);

      // When
      final handler = ResponseInterceptionHandlerMock();
      interceptor.onResponse(response, handler);

      // Then
      verify(() => handler.next(response));
    });

    test('the interceptor forwards error unaltered', () {
      // Given
      final interceptor = DatadogDioInterceptor(datadogSdk: mockDatadog);
      final requestOptions =
          RequestOptions(path: 'https://test_uri', headers: {});
      final err = DioException(requestOptions: requestOptions);

      // When
      final handler = ErrorInterceptorHandlerMock();
      interceptor.onError(err, handler);

      // Then
      verify(() => handler.next(err));
    });

    test('the interceptor does not call the supplied listener on request', () {
      // Given
      final listener = DatadogDioAttributeProviderMock();
      final interceptor = DatadogDioInterceptor(
          datadogSdk: mockDatadog, attributesProvider: listener);
      final requestOptions =
          RequestOptions(path: 'https://test_uri', headers: {});

      // When
      final handler = RequestInterceptionHandlerMock();
      interceptor.onRequest(requestOptions, handler);

      // Then
      verifyZeroInteractions(listener);
    });

    test('the interceptor does not call the supplied listener on response', () {
      // Given
      final listener = DatadogDioAttributeProviderMock();
      final interceptor = DatadogDioInterceptor(
          datadogSdk: mockDatadog, attributesProvider: listener);
      final requestOptions =
          RequestOptions(path: 'https://test_uri', headers: {});
      final response = Response(requestOptions: requestOptions);

      // When
      final handler = ResponseInterceptionHandlerMock();
      interceptor.onResponse(response, handler);

      // Then
      verifyZeroInteractions(listener);
    });
  });

  group('when rum is enabled with no tracing', () {
    setUp(() {
      when(() => mockDatadog.rum).thenReturn(mockRum);

      when(() => mockDatadog.headerTypesForHost(any())).thenReturn({});
    });

    test('the interceptor starts the resource on request and adds a rum key',
        () {
      // Given
      final interceptor = DatadogDioInterceptor(datadogSdk: mockDatadog);
      final requestOptions =
          RequestOptions(path: 'https://test_uri', method: 'POST', headers: {});

      // When
      final handler = RequestInterceptionHandlerMock();
      interceptor.onRequest(requestOptions, handler);

      // Then
      expect(
          requestOptions.extra
              .containsKey(DatadogDioInterceptor.datadogRumExtraKey),
          isTrue);
      verify(() => mockRum.startResource(
          any(), RumHttpMethod.post, 'https://test_uri', any()));
      verify(() => handler.next(requestOptions));
    });

    test('the interceptor calls attribute provider on request', () {
      // Given
      final attributeProvider = DatadogDioAttributeProviderMock();
      when(() => attributeProvider.onRequest(any())).thenReturn(null);
      final interceptor = DatadogDioInterceptor(
          datadogSdk: mockDatadog, attributesProvider: attributeProvider);
      final requestOptions =
          RequestOptions(path: 'https://test_uri', method: 'POST', headers: {});

      // When
      final handler = RequestInterceptionHandlerMock();
      interceptor.onRequest(requestOptions, handler);

      // Then
      verify(() => attributeProvider.onRequest(requestOptions));
    });

    test('the interceptor adds provided attributes to startResource on request',
        () {
      // Given
      final attributeProvider = DatadogDioAttributeProviderMock();
      when(() => attributeProvider.onRequest(any()))
          .thenReturn({'my_attribute': 100});
      final interceptor = DatadogDioInterceptor(
          datadogSdk: mockDatadog, attributesProvider: attributeProvider);
      final requestOptions =
          RequestOptions(path: 'https://test_uri', method: 'POST', headers: {});

      // When
      final handler = RequestInterceptionHandlerMock();
      interceptor.onRequest(requestOptions, handler);

      // Then
      verify(() => mockRum.startResource(any(), RumHttpMethod.post,
          'https://test_uri', {'my_attribute': 100}));
    });

    test('the interceptor stops the resource on response', () {
      // Given
      final interceptor = DatadogDioInterceptor(datadogSdk: mockDatadog);
      final requestOptions =
          RequestOptions(path: 'https://test_uri', method: 'POST', headers: {});
      final rumKey = randomString();
      requestOptions.extra[DatadogDioInterceptor.datadogRumExtraKey] = rumKey;
      final response =
          Response(requestOptions: requestOptions, statusCode: 202);

      // When
      final handler = ResponseInterceptionHandlerMock();
      interceptor.onResponse(response, handler);

      // Then
      verify(() => mockRum.stopResource(rumKey, any(), any()));
      verify(() => handler.next(response));
    });

    test('the interceptor calls attribute provider on response', () {
      // Given
      final attributeProvider = DatadogDioAttributeProviderMock();
      when(() => attributeProvider.onResponse(any())).thenReturn(null);
      final interceptor = DatadogDioInterceptor(
          datadogSdk: mockDatadog, attributesProvider: attributeProvider);
      final requestOptions =
          RequestOptions(path: 'https://test_uri', method: 'POST', headers: {});
      final rumKey = randomString();
      requestOptions.extra[DatadogDioInterceptor.datadogRumExtraKey] = rumKey;
      final response =
          Response(requestOptions: requestOptions, statusCode: 202);

      // When
      final handler = ResponseInterceptionHandlerMock();
      interceptor.onResponse(response, handler);

      // Then
      verify(() => attributeProvider.onResponse(response));
    });

    test('the interceptor adds provided attributes to stopResource on response',
        () {
      // Given
      final attributeProvider = DatadogDioAttributeProviderMock();
      when(() => attributeProvider.onResponse(any()))
          .thenReturn({'my_attribute': 100});
      final interceptor = DatadogDioInterceptor(
          datadogSdk: mockDatadog, attributesProvider: attributeProvider);
      final requestOptions =
          RequestOptions(path: 'https://test_uri', method: 'POST', headers: {});
      final rumKey = randomString();
      requestOptions.extra[DatadogDioInterceptor.datadogRumExtraKey] = rumKey;

      final response =
          Response(requestOptions: requestOptions, statusCode: 202);

      // When
      final handler = ResponseInterceptionHandlerMock();
      interceptor.onResponse(response, handler);

      // Then
      verify(() => mockRum
          .stopResource(rumKey, 202, any(), any(), {'my_attribute': 100}));
    });

    test(
        'reports resource size from response body when Content-Length is missing (chunked)',
        () {
      // Given: chunked response with no content-length header but body in memory
      final interceptor = DatadogDioInterceptor(datadogSdk: mockDatadog);
      final requestOptions =
          RequestOptions(path: 'https://test_uri', method: 'GET', headers: {});
      final rumKey = randomString();
      requestOptions.extra[DatadogDioInterceptor.datadogRumExtraKey] = rumKey;
      final response = Response(
        requestOptions: requestOptions,
        statusCode: 200,
        data: [1, 2, 3, 4, 5],
        headers: Headers(),
      );

      // When
      final handler = ResponseInterceptionHandlerMock();
      interceptor.onResponse(response, handler);

      // Then
      verify(() => mockRum.stopResource(rumKey, 200, any(), 5, any()));
    });

    test('the interceptor stops resource with error on error', () {
      // Given
      final interceptor = DatadogDioInterceptor(datadogSdk: mockDatadog);
      final requestOptions =
          RequestOptions(path: 'https://test_uri', method: 'POST', headers: {});
      final rumKey = randomString();
      requestOptions.extra[DatadogDioInterceptor.datadogRumExtraKey] = rumKey;

      // When
      final dioException = DioException(requestOptions: requestOptions);
      interceptor.onError(dioException, ErrorInterceptorHandlerMock());

      // Then
      final dioErrorString = dioException.toString();
      final dioErrorTypeString = dioException.type.toString();
      verify(() => mockRum.stopResourceWithErrorInfo(
          rumKey, dioErrorString, dioErrorTypeString, {}));
    });

    test('the interceptor adds provided attributes to stopResource on error',
        () {
      // Given
      final attributeProvider = DatadogDioAttributeProviderMock();
      when(() => attributeProvider.onError(any()))
          .thenReturn({'my_attribute': 100});
      final interceptor = DatadogDioInterceptor(
          datadogSdk: mockDatadog, attributesProvider: attributeProvider);
      final requestOptions =
          RequestOptions(path: 'https://test_uri', method: 'POST', headers: {});
      final rumKey = randomString();
      requestOptions.extra[DatadogDioInterceptor.datadogRumExtraKey] = rumKey;

      // When
      final dioException = DioException(requestOptions: requestOptions);
      interceptor.onError(dioException, ErrorInterceptorHandlerMock());

      // Then
      final dioErrorString = dioException.toString();
      final dioErrorTypeString = dioException.type.toString();
      verify(() => mockRum.stopResourceWithErrorInfo(
          rumKey, dioErrorString, dioErrorTypeString, {'my_attribute': 100}));
    });

    test('the interceptor stops resources as non-errors on badResponse', () {
      // Given
      final interceptor = DatadogDioInterceptor(datadogSdk: mockDatadog);
      final requestOptions =
          RequestOptions(path: 'https://test_uri', method: 'POST', headers: {});
      final rumKey = randomString();
      requestOptions.extra[DatadogDioInterceptor.datadogRumExtraKey] = rumKey;
      final response =
          Response(requestOptions: requestOptions, statusCode: 404);

      // When
      final dioException = DioException.badResponse(
          statusCode: 404, requestOptions: requestOptions, response: response);
      final handler = ErrorInterceptorHandlerMock();
      interceptor.onError(dioException, handler);

      // Then
      verify(() => mockRum.stopResource(rumKey, 404, any()));
      verify(() => handler.next(dioException));
    });

    test('the interceptor adds provided attributes as non-error on badResponse',
        () {
      // Given
      final attributeProvider = DatadogDioAttributeProviderMock();
      when(() => attributeProvider.onResponse(any()))
          .thenReturn({'my_attribute': 100});
      final interceptor = DatadogDioInterceptor(
          datadogSdk: mockDatadog, attributesProvider: attributeProvider);
      final requestOptions =
          RequestOptions(path: 'https://test_uri', method: 'POST', headers: {});
      final rumKey = randomString();
      requestOptions.extra[DatadogDioInterceptor.datadogRumExtraKey] = rumKey;
      final response =
          Response(requestOptions: requestOptions, statusCode: 404);

      // When
      final dioException = DioException.badResponse(
          statusCode: 404, requestOptions: requestOptions, response: response);
      final handler = ErrorInterceptorHandlerMock();
      interceptor.onError(dioException, handler);

      // Then
      verify(() => mockRum
          .stopResource(rumKey, 404, any(), any(), {'my_attribute': 100}));
      verify(() => handler.next(dioException));
    });

    test('the interceptor ignores requests that match a regex', () {
      // Given
      final interceptor = DatadogDioInterceptor(
          datadogSdk: mockDatadog, ignoreUrlPatterns: [RegExp('.*/ignored')]);
      final requestOptions = RequestOptions(
          path: 'https://test_uri/ignored', method: 'POST', headers: {});

      // When
      final handler = RequestInterceptionHandlerMock();
      interceptor.onRequest(requestOptions, handler);

      // Then
      verifyZeroInteractions(mockRum);
    });

    test('the interceptor starts resources that do not that match a regex', () {
      // Given
      final interceptor = DatadogDioInterceptor(
          datadogSdk: mockDatadog, ignoreUrlPatterns: [RegExp('.*/ignored')]);
      final requestOptions =
          RequestOptions(path: 'https://test_uri', method: 'POST', headers: {});

      // When
      final handler = RequestInterceptionHandlerMock();
      interceptor.onRequest(requestOptions, handler);

      // Then
      verify(() => mockRum.startResource(
          any(), RumHttpMethod.post, 'https://test_uri', any()));
    });
  });

  for (final headerType in TracingHeaderType.values) {
    group('when rum is enabled with $headerType tracing headers', () {
      setUp(() {
        mockDatadog = DatadogSdkMock();
        when(() => mockDatadog.platform).thenReturn(mockPlatform);
        when(() => mockDatadog.headerTypesForHost(
            any(that: HasHost(equals('test_url'))))).thenReturn({headerType});
        when(() => mockDatadog.headerTypesForHost(
            any(that: HasHost(equals('non_first_party'))))).thenReturn({});
        when(() => mockRum.contextInjectionSetting)
            .thenReturn(TraceContextInjection.all);
        // ignore: invalid_use_of_internal_member
        when(() => mockDatadog.internalLogger).thenReturn(InternalLoggerMock());

        when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(true);
        when(() => mockRum.traceSampleRate).thenReturn(50.0);
        when(() => mockDatadog.rum).thenReturn(mockRum);
      });

      test('does not set trace attributes when should sample returns false',
          () {
        // Given
        when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(false);
        final interceptor = DatadogDioInterceptor(datadogSdk: mockDatadog);
        final request =
            RequestOptions(path: "https://test_url/post", method: 'POST');

        // When
        interceptor.onRequest(request, RequestInterceptorHandler());

        // Then
        final capturedAttrs = verify(
                () => mockRum.startResource(any(), any(), any(), captureAny()))
            .captured[0] as Map<String, Object?>;
        expect(capturedAttrs[DatadogRumPlatformAttributeKey.traceID], isNull);
        expect(capturedAttrs[DatadogRumPlatformAttributeKey.spanID], isNull);
        expect(capturedAttrs[DatadogRumPlatformAttributeKey.rulePsr], 0.50);
      });

      test('onRequest sets tracing attributes', () {
        // Given
        when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(true);
        final interceptor = DatadogDioInterceptor(datadogSdk: mockDatadog);
        final request =
            RequestOptions(path: "https://test_url/post", method: 'POST');

        // When
        interceptor.onRequest(request, RequestInterceptorHandler());

        // Then
        final capturedAttrs = verify(
                () => mockRum.startResource(any(), any(), any(), captureAny()))
            .captured[0] as Map<String, dynamic>;
        var traceId = BigInt.parse(
            capturedAttrs[DatadogRumPlatformAttributeKey.traceID],
            radix: 16);
        expect(traceId, isNotNull);
        expect(traceId.bitLength, lessThanOrEqualTo(128));

        var spanId =
            BigInt.parse(capturedAttrs[DatadogRumPlatformAttributeKey.spanID]);
        expect(spanId, isNotNull);
        expect(spanId.bitLength, lessThanOrEqualTo(63));
        expect(capturedAttrs[DatadogRumPlatformAttributeKey.rulePsr], 0.50);
      });

      test('does not set trace headers for third party urls', () async {
        when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(true);
        final interceptor = DatadogDioInterceptor(datadogSdk: mockDatadog);
        final request = RequestOptions(
            path: "https://non_first_party/post", method: 'POST');

        // When
        interceptor.onRequest(request, RequestInterceptorHandler());

        // Then
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
        final requestHeaders = request.headers;
        for (var header in headers) {
          expect(requestHeaders[header], isNull);
        }
      });

      test(
          'sets trace headers for first party urls { sampled, TraceContextInjection.all }',
          () {
        when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(true);
        when(() => mockRum.contextInjectionSetting)
            .thenReturn(TraceContextInjection.all);
        final interceptor = DatadogDioInterceptor(datadogSdk: mockDatadog);
        final request =
            RequestOptions(path: "https://test_url/post", method: 'POST');

        // When
        interceptor.onRequest(request, RequestInterceptorHandler());

        final requestHeaders = request.headers;
        verifyHeaders(
            headerType, requestHeaders, true, TraceContextInjection.all);
      });

      test(
          'sets trace headers for first party urls { sampled, TraceContextInjection.sampled }',
          () {
        when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(true);
        when(() => mockRum.contextInjectionSetting)
            .thenReturn(TraceContextInjection.sampled);
        final interceptor = DatadogDioInterceptor(datadogSdk: mockDatadog);
        final request =
            RequestOptions(path: "https://test_url/post", method: 'POST');

        // When
        interceptor.onRequest(request, RequestInterceptorHandler());

        final requestHeaders = request.headers;
        verifyHeaders(
            headerType, requestHeaders, true, TraceContextInjection.sampled);
      });

      test(
          'sets trace headers for first party urls { unsampled, TraceContextInjection.all }',
          () {
        when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(false);
        when(() => mockRum.contextInjectionSetting)
            .thenReturn(TraceContextInjection.all);
        final interceptor = DatadogDioInterceptor(datadogSdk: mockDatadog);
        final request =
            RequestOptions(path: "https://test_url/post", method: 'POST');

        // When
        interceptor.onRequest(request, RequestInterceptorHandler());

        final requestHeaders = request.headers;
        verifyHeaders(
            headerType, requestHeaders, false, TraceContextInjection.all);
      });

      test(
          'sets trace headers for first party urls { unsampled, TraceContextInjection.sampled }',
          () {
        when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(false);
        when(() => mockRum.contextInjectionSetting)
            .thenReturn(TraceContextInjection.sampled);
        final interceptor = DatadogDioInterceptor(datadogSdk: mockDatadog);
        final request =
            RequestOptions(path: "https://test_url/post", method: 'POST');

        // When
        interceptor.onRequest(request, RequestInterceptorHandler());

        final requestHeaders = request.headers;
        verifyHeaders(
            headerType, requestHeaders, false, TraceContextInjection.sampled);
      });
    });
  }

  group('with trackResourceHeaders', () {
    setUp(() {
      when(() => mockDatadog.rum).thenReturn(mockRum);
      when(() => mockDatadog.headerTypesForHost(any())).thenReturn({});
    });

    test('passes captured headers as internal attributes to stopResource', () {
      // ignore: invalid_use_of_internal_member
      when(() => mockRum.resourceHeadersExtractor)
          .thenReturn(ResourceHeadersExtractor());

      final interceptor = DatadogDioInterceptor(datadogSdk: mockDatadog);
      final requestOptions = RequestOptions(
          path: 'https://test_uri',
          method: 'GET',
          headers: {'content-type': 'application/json'});
      final rumKey = randomString();
      requestOptions.extra[DatadogDioInterceptor.datadogRumExtraKey] = rumKey;

      final response = Response(
        requestOptions: requestOptions,
        statusCode: 200,
        headers: Headers.fromMap({
          'content-type': ['image/png'],
          'etag': ['"abc123"'],
          'cookie': ['session=secret'], // forbidden, must be filtered
        }),
      );

      interceptor.onResponse(response, ResponseInterceptionHandlerMock());

      final captured = verify(() =>
              mockRum.stopResource(rumKey, 200, any(), any(), captureAny()))
          .captured[0] as Map<String, Object?>;

      final responseHeaders =
          captured['_dd.response_headers'] as Map<String, String>;
      expect(responseHeaders['content-type'], 'image/png');
      expect(responseHeaders['etag'], '"abc123"');
      expect(responseHeaders.containsKey('cookie'), isFalse);

      final requestHeaders =
          captured['_dd.request_headers'] as Map<String, String>;
      expect(requestHeaders['content-type'], 'application/json');
    });

    test('preserves multi-value request headers passed as a List', () {
      // ignore: invalid_use_of_internal_member
      when(() => mockRum.resourceHeadersExtractor)
          .thenReturn(ResourceHeadersExtractor());

      final interceptor = DatadogDioInterceptor(datadogSdk: mockDatadog);
      final requestOptions = RequestOptions(
        path: 'https://test_uri',
        method: 'GET',
        headers: {
          // Dio allows List values for multi-value headers — must be joined
          // with ", ", not stringified as "[no-cache, no-store]".
          'cache-control': ['no-cache', 'no-store'],
        },
      );
      final rumKey = randomString();
      requestOptions.extra[DatadogDioInterceptor.datadogRumExtraKey] = rumKey;
      final response =
          Response(requestOptions: requestOptions, statusCode: 200);

      interceptor.onResponse(response, ResponseInterceptionHandlerMock());

      final captured = verify(() =>
              mockRum.stopResource(rumKey, 200, any(), any(), captureAny()))
          .captured[0] as Map<String, Object?>;
      final requestHeaders =
          captured['_dd.request_headers'] as Map<String, String>;
      expect(requestHeaders['cache-control'], 'no-cache, no-store');
    });

    test('does not add header attributes when extractor is null', () {
      // ignore: invalid_use_of_internal_member
      when(() => mockRum.resourceHeadersExtractor).thenReturn(null);

      final interceptor = DatadogDioInterceptor(datadogSdk: mockDatadog);
      final requestOptions =
          RequestOptions(path: 'https://test_uri', method: 'GET', headers: {});
      final rumKey = randomString();
      requestOptions.extra[DatadogDioInterceptor.datadogRumExtraKey] = rumKey;
      final response =
          Response(requestOptions: requestOptions, statusCode: 200);

      interceptor.onResponse(response, ResponseInterceptionHandlerMock());

      final captured = verify(() =>
              mockRum.stopResource(rumKey, 200, any(), any(), captureAny()))
          .captured[0] as Map<String, Object?>;
      expect(captured.containsKey('_dd.request_headers'), isFalse);
      expect(captured.containsKey('_dd.response_headers'), isFalse);
    });
  });
}
