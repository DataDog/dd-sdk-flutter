// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:async';
import 'dart:io';

import 'package:datadog_common_test/uri_matchers.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_tracking_http_client/src/tracking_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'test_helpers.dart';

class MockDatadogSdk extends Mock implements DatadogSdk {}

class MockDatadogSdkPlatform extends Mock implements DatadogSdkPlatform {}

class MockDdRum extends Mock implements DatadogRum {}

class MockClient extends Mock implements http.Client {}

class MockStreamedResponse extends Mock implements http.StreamedResponse {}

class FakeBaseRequest extends Fake implements http.BaseRequest {}

void main() {
  late MockDatadogSdk mockDatadog;
  late MockDatadogSdkPlatform mockPlatform;
  late MockClient mockClient;
  late MockStreamedResponse mockResponse;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(FakeBaseRequest());
    registerFallbackValue(RumResourceType.image);
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

    mockResponse = MockStreamedResponse();
    when(() => mockResponse.stream)
        .thenAnswer((_) => http.ByteStream.fromBytes([]));
    when(() => mockResponse.statusCode).thenReturn(200);
    when(() => mockResponse.persistentConnection).thenReturn(false);
    when(() => mockResponse.request).thenReturn(FakeBaseRequest());
    when(() => mockResponse.headers).thenReturn({});
    when(() => mockResponse.isRedirect).thenReturn(false);

    mockClient = MockClient();
    when(() => mockClient.send(any()))
        .thenAnswer((_) => Future.value(mockResponse));
  });

  group('when rum is disabled', () {
    setUp(() {
      when(() => mockDatadog.rum).thenReturn(null);
    });

    test('tracking client passes through send calls', () async {
      final client =
          DatadogClient(datadogSdk: mockDatadog, innerClient: mockClient);
      final testUri = Uri.parse('https://test_url/test');
      await client.get(testUri, headers: {'x-datadog-header': 'header'});

      final captured = verify(() => mockClient.send(captureAny())).captured[0]
          as http.BaseRequest;
      expect(captured.url, testUri);
      expect(captured.headers, {'x-datadog-header': 'header'});
    });

    test('attributes provider is not called', () async {
      var attributesProviderCalled = false;
      final client = DatadogClient(
        datadogSdk: mockDatadog,
        innerClient: mockClient,
        attributesProvider: (request, response, error) {
          attributesProviderCalled = true;
          return {};
        },
      );
      final testUri = Uri.parse('https://test_url/test');
      await client.get(testUri, headers: {'x-datadog-header': 'header'});

      expect(attributesProviderCalled, isFalse);
    });
  });

  group('when rum is enabled', () {
    late MockDdRum mockRum;

    setUp(() {
      mockRum = MockDdRum();
      when(() => mockRum.shouldSampleTrace()).thenReturn(true);
      when(() => mockRum.contextInjectionSetting)
          .thenReturn(TraceContextInjection.all);
      when(() => mockRum.traceSampleRate).thenReturn(50.0);

      when(() => mockDatadog.rum).thenReturn(mockRum);
    });

    test('calls startResource on initial request', () async {
      final client =
          DatadogClient(datadogSdk: mockDatadog, innerClient: mockClient);
      final testUri = Uri.parse('https://test_url/test');
      final _ = client.get(testUri, headers: {'x-datadog-header': 'header'});

      verify(() => mockRum.startResource(
          any(), RumHttpMethod.get, testUri.toString(), any()));
    });

    test('calls stopResource on completion', () async {
      final client =
          DatadogClient(datadogSdk: mockDatadog, innerClient: mockClient);
      final testUri = Uri.parse('https://test_url/test');
      final future =
          client.get(testUri, headers: {'x-datadog-header': 'header'});

      await future;

      final key = verify(() => mockRum.startResource(
              captureAny(), RumHttpMethod.get, testUri.toString(), any()))
          .captured[0] as String;

      verify(() =>
          mockRum.stopResource(key, 200, RumResourceType.native, any(), any()));
    });

    test('calls stopResource with size and deduced content type', () async {
      final client =
          DatadogClient(datadogSdk: mockDatadog, innerClient: mockClient);
      final testUri = Uri.parse('https://test_url/test');

      when(() => mockResponse.contentLength).thenReturn(88888);
      when(() => mockResponse.headers).thenReturn({
        HttpHeaders.contentTypeHeader: ContentType('image', 'png').toString()
      });
      final future =
          client.get(testUri, headers: {'x-datadog-header': 'header'});

      await future;

      final key = verify(() => mockRum.startResource(
              captureAny(), RumHttpMethod.get, testUri.toString(), any()))
          .captured[0] as String;

      verify(() =>
          mockRum.stopResource(key, 200, RumResourceType.image, 88888, any()));
    });

    test('calls stopResource with provided attributes', () async {
      http.BaseRequest? providedRequest;
      http.StreamedResponse? providedResponse;
      final attributes = {'attribute_a': 'my_value', 'attribute_b': 32.1};
      final client = DatadogClient(
        datadogSdk: mockDatadog,
        innerClient: mockClient,
        attributesProvider: (request, response, error) {
          providedRequest = request;
          providedResponse = response;
          return attributes;
        },
      );
      final testUri = Uri.parse('https://test_url/test');

      final future =
          client.get(testUri, headers: {'x-datadog-header': 'header'});

      await future;

      expect(providedRequest, isNotNull);
      expect(providedResponse, isNotNull);
      verify(
          () => mockRum.stopResource(any(), any(), any(), any(), attributes));
    });

    test('send throwingError rethrows and calls stopResourceWithErrorInfo',
        () async {
      final client =
          DatadogClient(datadogSdk: mockDatadog, innerClient: mockClient);
      final testUri = Uri.parse('https://test_url/test');

      final errorToThrow = Error();
      Object? thrownError;
      when(() => mockClient.send(any())).thenThrow(errorToThrow);
      try {
        final _ =
            await client.get(testUri, headers: {'x-datadog-header': 'header'});
      } catch (e) {
        thrownError = e;
      }

      final key = verify(() => mockRum.startResource(
              captureAny(), RumHttpMethod.get, testUri.toString(), any()))
          .captured[0] as String;

      expect(thrownError, thrownError);
      verify(() => mockRum.stopResourceWithErrorInfo(
          key, thrownError.toString(), thrownError.runtimeType.toString()));
    });

    test(
        'send throwingError calls attributesProvider with error and sends provided attributes',
        () async {
      http.BaseRequest? providedRequest;
      http.StreamedResponse? providedResponse;
      Object? providedError;
      final attributes = {
        'error_attribute': 'attributeValue',
        'secondary_attribute': 5549,
      };
      final client = DatadogClient(
        datadogSdk: mockDatadog,
        innerClient: mockClient,
        attributesProvider: (request, response, error) {
          providedRequest = request;
          providedResponse = response;
          providedError = error;
          return attributes;
        },
      );
      final testUri = Uri.parse('https://test_url/test');

      final errorToThrow = Error();
      Object? thrownError;
      when(() => mockClient.send(any())).thenThrow(errorToThrow);
      try {
        final _ =
            await client.get(testUri, headers: {'x-datadog-header': 'header'});
      } catch (e) {
        thrownError = e;
      }

      expect(providedRequest, isNotNull);
      expect(providedResponse, isNull);
      expect(providedError, thrownError);

      verify(() => mockRum.stopResourceWithErrorInfo(
          any(),
          thrownError.toString(),
          thrownError.runtimeType.toString(),
          attributes));
    });

    test('passes through stream data', () async {
      final client =
          DatadogClient(datadogSdk: mockDatadog, innerClient: mockClient);
      final testUri = Uri.parse('https://test_url/test');

      when(() => mockResponse.stream).thenAnswer(
          (_) => http.ByteStream.fromBytes([1, 2, 3, 4, 5, 122, 121, 120]));

      final response =
          await client.get(testUri, headers: {'x-datadog-header': 'header'});

      expect(response.bodyBytes.toList(), [1, 2, 3, 4, 5, 122, 121, 120]);
    });

    test('error in stream and calls stopResourceWithErrorInfo', () async {
      final client =
          DatadogClient(datadogSdk: mockDatadog, innerClient: mockClient);
      final testUri = Uri.parse('https://test_url/test');

      final errorToThrow = Error();
      final streamController = StreamController<List<int>>();
      Object? thrownError;
      when(() => mockResponse.stream)
          .thenAnswer((_) => http.ByteStream(streamController.stream));

      final future =
          client.get(testUri, headers: {'x-datadog-header': 'header'});

      try {
        streamController.sink.addError(errorToThrow);

        await future;
      } catch (e) {
        thrownError = e;
      }

      expect(errorToThrow, thrownError);
      final key = verify(() => mockRum.startResource(
              captureAny(), RumHttpMethod.get, testUri.toString(), any()))
          .captured[0] as String;

      verify(() => mockRum.stopResourceWithErrorInfo(
          key, errorToThrow.toString(), errorToThrow.runtimeType.toString()));
    });

    test(
        'error in stream and calls attributeProvider with error and sends provided attributes',
        () async {
      http.BaseRequest? providedRequest;
      http.StreamedResponse? providedResponse;
      Object? providedError;
      final attributes = {
        'error_attribute': 'attributeValue',
        'another_attr': 5549,
      };
      final client = DatadogClient(
        datadogSdk: mockDatadog,
        innerClient: mockClient,
        attributesProvider: (request, response, error) {
          providedRequest = request;
          providedResponse = response;
          providedError = error;
          return attributes;
        },
      );
      final testUri = Uri.parse('https://test_url/test');

      final errorToThrow = Error();
      final streamController = StreamController<List<int>>();
      Object? thrownError;
      when(() => mockResponse.stream)
          .thenAnswer((_) => http.ByteStream(streamController.stream));

      final future =
          client.get(testUri, headers: {'x-datadog-header': 'header'});

      try {
        streamController.sink.addError(errorToThrow);

        await future;
      } catch (e) {
        thrownError = e;
      }

      expect(providedRequest, isNotNull);
      expect(providedResponse, isNotNull);
      expect(providedError, thrownError);

      verify(() => mockRum.stopResourceWithErrorInfo(
          any(),
          errorToThrow.toString(),
          errorToThrow.runtimeType.toString(),
          attributes));
    });

    test('ignorUrlPatterns does not perform tracking on matching url',
        () async {
      final client = DatadogClient(
        datadogSdk: mockDatadog,
        innerClient: mockClient,
        ignoreUrlPatterns: [
          RegExp('ignore_me.com/a/b'),
        ],
      );
      final testUri = Uri.parse('https://ignore_me.com/a/b/c');

      final future =
          client.get(testUri, headers: {'x-datadog-header': 'header'});

      await future;

      verifyNoMoreInteractions(mockRum);
    });

    test('ignoreUrlPatterns performs tracking when urls do not match',
        () async {
      final client = DatadogClient(
        datadogSdk: mockDatadog,
        innerClient: mockClient,
        ignoreUrlPatterns: [
          RegExp('test_url/my_endpoint'),
        ],
      );
      final testUri = Uri.parse('https://test_url/test');

      final future =
          client.get(testUri, headers: {'x-datadog-header': 'header'});

      await future;

      verify(
          () => mockRum.startResource(any(), RumHttpMethod.get, any(), any()));
      verify(() => mockRum.stopResource(any(), any(), any(), any(), any()));
    });

    for (final headerType in TracingHeaderType.values) {
      group('when rum is enabled with $headerType tracing headers', () {
        setUp(() {
          when(() => mockDatadog.headerTypesForHost(
              any(that: HasHost(equals('test_url'))))).thenReturn({headerType});
        });

        test(
            'adds tracing headers to request { sampled, TraceContextInjection.all }',
            () async {
          final client = DatadogClient(
            datadogSdk: mockDatadog,
            innerClient: mockClient,
          );
          final testUri = Uri.parse('https://test_url/test');
          final _ =
              client.get(testUri, headers: {'x-datadog-header': 'header'});

          final captured = verify(() => mockClient.send(captureAny()))
              .captured[0] as http.BaseRequest;
          expect(captured.url, testUri);

          final headers = captured.headers;

          verifyHeaders(headers, headerType, true, TraceContextInjection.all);
        });

        test(
            'adds tracing headers to request { sampled, TraceContextInjection.sampled }',
            () async {
          final client = DatadogClient(
            datadogSdk: mockDatadog,
            innerClient: mockClient,
          );
          final testUri = Uri.parse('https://test_url/test');
          final _ =
              client.get(testUri, headers: {'x-datadog-header': 'header'});

          final captured = verify(() => mockClient.send(captureAny()))
              .captured[0] as http.BaseRequest;
          expect(captured.url, testUri);

          final headers = captured.headers;

          verifyHeaders(
              headers, headerType, true, TraceContextInjection.sampled);
        });

        test(
            'adds tracing headers to request { unsampled, TraceContextInjection.all }',
            () async {
          when(() => mockRum.shouldSampleTrace()).thenReturn(false);
          final client = DatadogClient(
            datadogSdk: mockDatadog,
            innerClient: mockClient,
          );
          final testUri = Uri.parse('https://test_url/test');
          final _ =
              client.get(testUri, headers: {'x-datadog-header': 'header'});

          final captured = verify(() => mockClient.send(captureAny()))
              .captured[0] as http.BaseRequest;
          expect(captured.url, testUri);

          final headers = captured.headers;

          verifyHeaders(headers, headerType, false, TraceContextInjection.all);
        });

        test(
            'does not add tracing headers to request { unsampled, TraceContextInjection.sampled }',
            () async {
          when(() => mockRum.shouldSampleTrace()).thenReturn(false);
          when(() => mockRum.contextInjectionSetting)
              .thenReturn(TraceContextInjection.sampled);
          final client = DatadogClient(
            datadogSdk: mockDatadog,
            innerClient: mockClient,
          );
          final testUri = Uri.parse('https://test_url/test');
          final _ =
              client.get(testUri, headers: {'x-datadog-header': 'header'});

          final captured = verify(() => mockClient.send(captureAny()))
              .captured[0] as http.BaseRequest;
          expect(captured.url, testUri);

          final headers = captured.headers;

          verifyHeaders(
              headers, headerType, false, TraceContextInjection.sampled);
        });

        test('adds tracing attributes to startResource', () async {
          final client = DatadogClient(
            datadogSdk: mockDatadog,
            innerClient: mockClient,
          );
          final testUri = Uri.parse('https://test_url/test');
          final _ =
              client.get(testUri, headers: {'x-datadog-header': 'header'});

          final callAttributes = verify(() => mockRum.startResource(
                  any(), RumHttpMethod.get, testUri.toString(), captureAny()))
              .captured[0] as Map<String, Object?>;

          final traceValue = callAttributes['_dd.trace_id'] as String?;
          final traceInt = traceValue != null
              ? BigInt.tryParse(traceValue, radix: 16)
              : null;
          expect(traceInt, isNotNull);
          expect(traceInt?.bitLength, lessThanOrEqualTo(128));

          final spanValue = callAttributes['_dd.span_id'] as String?;
          final spanInt = spanValue != null ? BigInt.tryParse(spanValue) : null;
          expect(spanInt, isNotNull);
          expect(spanInt?.bitLength, lessThanOrEqualTo(63));
        });

        test('does not trace 3rd party requests', () async {
          final client = DatadogClient(
            datadogSdk: mockDatadog,
            innerClient: mockClient,
          );
          final testUri = Uri.parse('https://non_first_party/test');
          final _ =
              client.get(testUri, headers: {'x-datadog-header': 'header'});

          final captured = verify(() => mockClient.send(captureAny()))
              .captured[0] as http.BaseRequest;
          expect(captured.url, testUri);

          final headers = captured.headers;
          expect(headers['x-datadog-header'], 'header');

          expect(headers['x-datadog-sampling-priority'], isNull);
          expect(headers['x-datadog-trace-id'], isNull);
          expect(headers['x-datadog-parent-id'], isNull);
          expect(headers['b3'], isNull);
          expect(headers['X-B3-TraceId'], isNull);
          expect(headers['X-B3-SpanId'], isNull);
          expect(headers['X-B3-ParentSpanId'], isNull);
          expect(headers['X-B3-Sampled'], isNull);

          final callAttributes = verify(() => mockRum.startResource(
                  any(), RumHttpMethod.get, testUri.toString(), captureAny()))
              .captured[0] as Map<String, Object?>;
          expect(callAttributes['_dd.trace_id'], isNull);
          expect(callAttributes['_dd.parent_id'], isNull);
        });
      });
    }

    test('different hosts can send different tracing headers', () async {
      when(() => mockDatadog
              .headerTypesForHost(any(that: HasHost(equals('test_url_a')))))
          .thenReturn({TracingHeaderType.datadog});
      when(() => mockDatadog
              .headerTypesForHost(any(that: HasHost(equals('test_url_b')))))
          .thenReturn({TracingHeaderType.b3});

      final client = DatadogClient(
        datadogSdk: mockDatadog,
        innerClient: mockClient,
      );
      final testUriA = Uri.parse('https://test_url_a/test');
      await client.get(testUriA);

      final testUriB = Uri.parse('https://test_url_b/test');
      await client.get(testUriB);

      void verifyCall(Uri uri) {
        final callAttributes = verify(() => mockRum.startResource(
                any(), RumHttpMethod.get, uri.toString(), captureAny()))
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
      }

      verifyCall(testUriA);
      verifyCall(testUriB);

      final captured = verify(() => mockClient.send(captureAny())).captured;

      final capturedA = captured[0] as http.BaseRequest;
      expect(capturedA.url, testUriA);
      verifyHeaders(capturedA.headers, TracingHeaderType.datadog, true,
          TraceContextInjection.all);

      final capturedB = captured[1] as http.BaseRequest;
      expect(capturedB.url, testUriB);
      verifyHeaders(capturedB.headers, TracingHeaderType.b3, true,
          TraceContextInjection.all);
    });

    test('different tracing headers are same trace id', () async {
      // Given
      when(() => mockDatadog
              .headerTypesForHost(any(that: HasHost(equals('test_url_a')))))
          .thenReturn(
              {TracingHeaderType.datadog, TracingHeaderType.tracecontext});

      // When
      final client = DatadogClient(
        datadogSdk: mockDatadog,
        innerClient: mockClient,
      );
      final testUri = Uri.parse('https://test_url_a/test');
      await client.get(testUri);

      // Then
      final callAttributes = verify(() => mockRum.startResource(
              any(), RumHttpMethod.get, testUri.toString(), captureAny()))
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

      final captured = verify(() => mockClient.send(captureAny())).captured[0]
          as http.BaseRequest;

      var datadogTraceInt =
          BigInt.tryParse(captured.headers['x-datadog-trace-id']!);
      final parts = captured.headers['x-datadog-tags']?.split('=');
      expect(parts?[0], '_dd.p.tid');
      BigInt? highTraceInt = BigInt.tryParse(parts?[1] ?? '', radix: 16);
      expect(highTraceInt, isNotNull);
      datadogTraceInt = (highTraceInt! << 64) + datadogTraceInt!;
      expect(traceInt, datadogTraceInt);

      final datadogSpanInt =
          BigInt.tryParse(captured.headers['x-datadog-parent-id']!);
      expect(spanInt, datadogSpanInt);

      final tracecontextParts = captured.headers['traceparent']!.split('-');
      final contextTraceInt = BigInt.tryParse(tracecontextParts[1], radix: 16);
      expect(traceInt, contextTraceInt);
      final contextSpanInt = BigInt.tryParse(tracecontextParts[2], radix: 16);
      expect(spanInt, contextSpanInt);
    });
  });
}
