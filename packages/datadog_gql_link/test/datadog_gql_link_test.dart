// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:async';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_gql_link/datadog_gql_link.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gql/language.dart' as lang;
import 'package:gql_exec/gql_exec.dart';
import 'package:mocktail/mocktail.dart';

class MockDatadogSdk extends Mock implements DatadogSdk {}

class MockDatadogSdkPlatform extends Mock implements DatadogSdkPlatform {}

class MockDdRum extends Mock implements DdRum {}

class MockDatadogGqlListener extends Mock implements DatadogGqlListener {}

class MockResponse extends Mock implements Response {}

class FakeRequest extends Fake implements Request {}

void main() {
  late MockDatadogSdk mockDatadog;
  late MockDatadogSdkPlatform mockPlatform;
  late MockDdRum mockRum;

  final query = lang.parseString(r'''
query UserInfo($id: ID!) {
  user(id: $id) {
    id
    name
  }
}''');

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(RumHttpMethod.get);
    registerFallbackValue(RumResourceType.beacon);
    registerFallbackValue(FakeRequest());
  });

  setUp(() {
    mockPlatform = MockDatadogSdkPlatform();
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
    when(() => mockRum.tracingSamplingRate).thenReturn(50.0);
  });

  group('when rum is disabled', () {
    setUp(() {
      when(() => mockDatadog.rum).thenReturn(null);
    });

    test('the link forwards request unaltered', () {
      // Given
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'));
      final request = Request(operation: Operation(document: query));

      // When
      Request? chainedRequest;
      Stream<Response> returnStream = const Stream<Response>.empty();
      final returnedStream = link.request(request, (request) {
        chainedRequest = request;
        return returnStream;
      });

      // Then
      expect(request, chainedRequest);
      expect(returnStream, returnedStream);
    });

    test('the link does not call the supplied listener', () {
      // Given
      final listener = MockDatadogGqlListener();
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'),
          listener: listener);
      final request = Request(
          operation: Operation(document: query, operationName: 'operation'));

      // When
      Stream<Response> returnStream = const Stream<Response>.empty();
      link.request(request, (request) {
        return returnStream;
      });

      // Then
      verifyZeroInteractions(listener);
    });
  });

  group('when rum is enabled with no tracing', () {
    setUp(() {
      when(() => mockDatadog.rum).thenReturn(mockRum);

      when(() => mockDatadog.headerTypesForHost(any())).thenReturn({});
    });

    test('link starts the resource automatically', () {
      // Given
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'));
      final request = Request(
          operation: Operation(document: query, operationName: 'operation'));

      // When
      link.request(request, (request) {
        return const Stream<Response>.empty();
      });

      // Then
      verify(() => mockRum.startResourceLoading(
          any(), RumHttpMethod.post, 'https://test_uri', any()));
    });

    test('link adds GraphQL custom parameters on start resource', () {
      // Given
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'));
      final request = Request(
          operation: Operation(document: query, operationName: 'UserInfo'));

      // When
      link.request(request, (request) {
        return const Stream<Response>.empty();
      });

      // Then
      final capturedAttributes = verify(() => mockRum.startResourceLoading(
              any(), RumHttpMethod.post, 'https://test_uri', captureAny()))
          .captured[0] as Map<String, Object?>;
      Map<String, dynamic> dd =
          capturedAttributes['_dd'] as Map<String, dynamic>;
      expect(dd['graphql']['operation_type'], 'query');
      expect(dd['graphql']['operation_name'], 'UserInfo');
    });

    test('link calls listener on start resource', () {
      // Given
      final listener = MockDatadogGqlListener();
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'),
          listener: listener);
      final request = Request(
          operation: Operation(document: query, operationName: 'UserInfo'));

      // When
      link.request(request, (request) {
        return const Stream<Response>.empty();
      });

      // Then
      verify(() => listener.requestStarted(request, {}));
    });

    test('link adds attributes from listener to startResource', () {
      // Given
      final listener = MockDatadogGqlListener();
      when(() => listener.requestStarted(any(), any()))
          .thenAnswer((invocation) {
        final attributes =
            invocation.positionalArguments[1] as Map<String, Object?>;
        attributes['user_attribute'] = 1234;
      });
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'),
          listener: listener);
      final request = Request(
          operation: Operation(document: query, operationName: 'UserInfo'));

      // When
      link.request(request, (request) {
        return const Stream<Response>.empty();
      });

      // Then
      var attributes =
          verify(() => listener.requestStarted(request, captureAny()))
              .captured[0] as Map<String, Object?>;
      expect(attributes['user_attribute'], 1234);
    });

    test('link calls stopsResource on response', () async {
      // Given
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'));
      final request = Request(
          operation: Operation(document: query, operationName: 'UserInfo'));
      final response = MockResponse();
      when(() => response.context).thenReturn(const Context());
      String? capturedKey;
      when(() => mockRum.startResourceLoading(any(), any(), any(), any()))
          .thenAnswer((i) {
        capturedKey = i.positionalArguments[0] as String;
      });

      // When
      final responseController = StreamController<Response>();
      final stream = link.request(request, (request) {
        return responseController.stream;
      });

      responseController.sink.add(response);
      unawaited(responseController.sink.close());
      await stream.drain();

      // Then
      verify(() => mockRum.stopResourceLoading(
          capturedKey!, null, RumResourceType.native, null, any()));
    });

    test('link calls stopResource with properties from http context', () async {
      // Given
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'));
      final request = Request(
          operation: Operation(document: query, operationName: 'UserInfo'));
      final response = MockResponse();
      var responseContext = const Context();
      responseContext = responseContext.updateEntry<HttpLinkResponseContext>(
        (entry) {
          return const HttpLinkResponseContext(
            statusCode: 418,
            headers: {
              'content-length': '66219',
            },
          );
        },
      );
      when(() => response.context).thenReturn(responseContext);
      String? capturedKey;
      when(() => mockRum.startResourceLoading(any(), any(), any(), any()))
          .thenAnswer((i) {
        capturedKey = i.positionalArguments[0] as String;
      });

      // When
      final responseController = StreamController<Response>();
      final stream = link.request(request, (request) {
        return responseController.stream;
      });

      responseController.sink.add(response);
      unawaited(responseController.sink.close());
      await stream.drain();

      // Then
      verify(() => mockRum.stopResourceLoading(
          capturedKey!, 418, RumResourceType.native, 66219, any()));
    });

    test('link calls listener on response recieved', () async {
      // Given
      final mockListener = MockDatadogGqlListener();
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'),
          listener: mockListener);
      final request = Request(
          operation: Operation(document: query, operationName: 'UserInfo'));
      final response = MockResponse();
      when(() => response.context).thenReturn(const Context());

      // When
      final responseController = StreamController<Response>();
      final stream = link.request(request, (request) {
        return responseController.stream;
      });

      responseController.sink.add(response);
      unawaited(responseController.sink.close());
      await stream.drain();

      // Then
      verify(() => mockListener.responseRecieved(response, {}));
    });

    test('link adds attributes from listener to stopResource', () async {
      // Given
      final mockListener = MockDatadogGqlListener();
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'),
          listener: mockListener);
      final request = Request(
          operation: Operation(document: query, operationName: 'UserInfo'));
      final response = MockResponse();
      when(() => mockListener.responseRecieved(response, any()))
          .thenAnswer((invocation) {
        final attrs = invocation.positionalArguments[1];
        attrs['response_attribute'] = [1, 2, 3, 4];
      });
      when(() => response.context).thenReturn(const Context());
      String? capturedKey;
      when(() => mockRum.startResourceLoading(any(), any(), any(), any()))
          .thenAnswer((i) {
        capturedKey = i.positionalArguments[0] as String;
      });

      // When
      final responseController = StreamController<Response>();
      final stream = link.request(request, (request) {
        return responseController.stream;
      });

      responseController.sink.add(response);
      unawaited(responseController.sink.close());
      await stream.drain();

      // Then
      final captured = verify(() => mockRum.stopResourceLoading(
          capturedKey!, any(), RumResourceType.native, any(), captureAny()));
      final capturedAttrs = captured.captured[0] as Map<String, dynamic>;
      expect(capturedAttrs['response_attribute'], [1, 2, 3, 4]);
    });

    test(
        'link combinde attributes from listener request and response to stopResource',
        () async {
      // Given
      final mockListener = MockDatadogGqlListener();
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'),
          listener: mockListener);
      final request = Request(
          operation: Operation(document: query, operationName: 'UserInfo'));
      final response = MockResponse();
      when(() => mockListener.requestStarted(request, any()))
          .thenAnswer((invocation) {
        final attrs = invocation.positionalArguments[1];
        attrs['request_attribute'] = 'my request';
      });
      when(() => mockListener.responseRecieved(response, any()))
          .thenAnswer((invocation) {
        final attrs = invocation.positionalArguments[1];
        attrs['response_attribute'] = [1, 2, 3, 4];
      });
      when(() => response.context).thenReturn(const Context());
      String? capturedKey;
      when(() => mockRum.startResourceLoading(any(), any(), any(), any()))
          .thenAnswer((i) {
        capturedKey = i.positionalArguments[0] as String;
      });

      // When
      final responseController = StreamController<Response>();
      final stream = link.request(request, (request) {
        return responseController.stream;
      });

      responseController.sink.add(response);
      unawaited(responseController.sink.close());
      await stream.drain();

      // Then
      final captured = verify(() => mockRum.stopResourceLoading(
          capturedKey!, any(), RumResourceType.native, any(), captureAny()));
      final capturedAttrs = captured.captured[0] as Map<String, dynamic>;
      expect(capturedAttrs['response_attribute'], [1, 2, 3, 4]);
      expect(capturedAttrs['request_attribute'], 'my request');
    });
  });
}
