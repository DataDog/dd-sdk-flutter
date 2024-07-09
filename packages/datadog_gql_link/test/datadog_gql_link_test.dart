// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:async';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_common_test/uri_matchers.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_gql_link/datadog_gql_link.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gql/language.dart' as lang;
import 'package:gql_exec/gql_exec.dart';
import 'package:mocktail/mocktail.dart';

class MockDatadogSdk extends Mock implements DatadogSdk {}

class MockDatadogSdkPlatform extends Mock implements DatadogSdkPlatform {}

class MockDdRum extends Mock implements DatadogRum {}

class MockDatadogGqlListener extends Mock implements DatadogGqlListener {}

class MockResponse extends Mock implements Response {}

class MockInternalLogger extends Mock implements InternalLogger {}

class FakeRequest extends Fake implements Request {}

class Unencodable {
  final String representation;
  bool shouldThrow = false;

  Unencodable(this.representation);

  @override
  String toString() {
    if (shouldThrow) {
      throw Exception('Throwing during toString');
    }
    return 'Instance of Unencodable: $representation';
  }
}

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
    registerFallbackValue(StackTrace.current);
  });

  setUp(() {
    mockPlatform = MockDatadogSdkPlatform();
    mockDatadog = MockDatadogSdk();
    when(() => mockDatadog
            .headerTypesForHost(any(that: HasHost(equals('test_url')))))
        .thenReturn({TracingHeaderType.datadog});
    when(() => mockDatadog.platform).thenReturn(mockPlatform);
    // ignore: invalid_use_of_internal_member
    when(() => mockDatadog.internalLogger).thenReturn(MockInternalLogger());

    mockRum = MockDdRum();
    when(() => mockRum.shouldSampleTrace()).thenReturn(true);
    when(() => mockRum.traceSampleRate).thenReturn(50.0);
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
      verify(() => mockRum.startResource(
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
      final capturedAttributes = verify(() => mockRum.startResource(
              any(), RumHttpMethod.post, 'https://test_uri', captureAny()))
          .captured[0] as Map<String, Object?>;
      expect(capturedAttributes['_dd.graphql.operation_type'], 'query');
      expect(capturedAttributes['_dd.graphql.operation_name'], 'UserInfo');
    });

    test('link pulls operation name from query when not given', () {
      // Given
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'));
      final request = Request(operation: Operation(document: query));

      // When
      link.request(request, (request) {
        return const Stream<Response>.empty();
      });

      // Then
      final capturedAttributes = verify(() => mockRum.startResource(
              any(), RumHttpMethod.post, 'https://test_uri', captureAny()))
          .captured[0] as Map<String, Object?>;
      expect(capturedAttributes['_dd.graphql.operation_type'], 'query');
      expect(capturedAttributes['_dd.graphql.operation_name'], 'UserInfo');
    });

    test('link adds variables to attributes', () {
      // Given
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'));
      final idValue = randomString();
      final request = Request(
        operation: Operation(
          document: query,
          operationName: 'UserInfo',
        ),
        variables: {'id': idValue},
      );

      // When
      link.request(request, (request) {
        return const Stream<Response>.empty();
      });

      // Then
      final capturedAttributes = verify(() => mockRum.startResource(
              any(), RumHttpMethod.post, 'https://test_uri', captureAny()))
          .captured[0] as Map<String, Object?>;
      expect(capturedAttributes['_dd.graphql.variables'], '{"id":"$idValue"}');
    });

    test('link stringifies unencodable variables to attributes', () {
      // Given
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'));
      final request = Request(
        operation: Operation(
          document: query,
          operationName: 'UserInfo',
        ),
        variables: {'file': Unencodable('fake_representation')},
      );

      // When
      link.request(request, (request) {
        return const Stream<Response>.empty();
      });

      // Then
      final capturedAttributes = verify(() => mockRum.startResource(
              any(), RumHttpMethod.post, 'https://test_uri', captureAny()))
          .captured[0] as Map<String, Object?>;
      expect(capturedAttributes['_dd.graphql.variables'],
          '{"file":"Instance of Unencodable: fake_representation"}');
    });

    test('exception during json encoding does not break link', () {
      // Given
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'));
      final unencodable = Unencodable('fake_representation')
        ..shouldThrow = true;
      final request = Request(
        operation: Operation(
          document: query,
          operationName: 'UserInfo',
        ),
        variables: {'file': unencodable},
      );

      // When
      link.request(request, (request) {
        return const Stream<Response>.empty();
      });

      // Then
      final capturedAttributes = verify(() => mockRum.startResource(
              any(), RumHttpMethod.post, 'https://test_uri', captureAny()))
          .captured[0] as Map<String, Object?>;
      expect(capturedAttributes['_dd.graphql.variables'], isNull);
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
      when(() => mockRum.startResource(any(), any(), any(), any()))
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
      verify(() => mockRum.stopResource(
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
      when(() => mockRum.startResource(any(), any(), any(), any()))
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
      verify(() => mockRum.stopResource(
          capturedKey!, 418, RumResourceType.native, 66219, any()));
    });

    test('link calls listener on response received', () async {
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
      verify(() => mockListener.responseReceived(response, {}));
    });

    test('link adds attributes from listener to stopResource', () async {
      // Given
      final mockListener = MockDatadogGqlListener();
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'),
          listener: mockListener);
      final request = Request(
          operation: Operation(document: query, operationName: 'UserInfo'));
      final response = MockResponse();
      when(() => mockListener.responseReceived(response, any()))
          .thenAnswer((invocation) {
        final attrs = invocation.positionalArguments[1];
        attrs['response_attribute'] = [1, 2, 3, 4];
      });
      when(() => response.context).thenReturn(const Context());
      String? capturedKey;
      when(() => mockRum.startResource(any(), any(), any(), any()))
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
      final captured = verify(() => mockRum.stopResource(
          capturedKey!, any(), RumResourceType.native, any(), captureAny()));
      final capturedAttrs = captured.captured[0] as Map<String, dynamic>;
      expect(capturedAttrs['response_attribute'], [1, 2, 3, 4]);
    });

    test(
        'link combines attributes from listener request and response to stopResource',
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
      when(() => mockListener.responseReceived(response, any()))
          .thenAnswer((invocation) {
        final attrs = invocation.positionalArguments[1];
        attrs['response_attribute'] = [1, 2, 3, 4];
      });
      when(() => response.context).thenReturn(const Context());
      String? capturedKey;
      when(() => mockRum.startResource(any(), any(), any(), any()))
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
      final captured = verify(() => mockRum.stopResource(
          capturedKey!, any(), RumResourceType.native, any(), captureAny()));
      final capturedAttrs = captured.captured[0] as Map<String, dynamic>;
      expect(capturedAttrs['response_attribute'], [1, 2, 3, 4]);
      expect(capturedAttrs['request_attribute'], 'my request');
    });

    test('link calls stopResourceWithErrorInfo on stream error', () async {
      // Given
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'));
      final request = Request(
          operation: Operation(document: query, operationName: 'UserInfo'));
      final response = MockResponse();
      when(() => response.context).thenReturn(const Context());
      String? capturedKey;
      when(() => mockRum.startResource(any(), any(), any(), any()))
          .thenAnswer((i) {
        capturedKey = i.positionalArguments[0] as String;
      });

      // When
      final responseController = StreamController<Response>();
      final stream = link.request(request, (request) {
        return responseController.stream;
      });

      responseController.sink.addError('FakeError', StackTrace.current);
      unawaited(responseController.sink.close());
      try {
        await stream.drain();
      } catch (_) {}

      // Then
      verify(() => mockRum
          .stopResourceWithErrorInfo(capturedKey!, 'FakeError', 'String', {}));
    });

    test('link calls stopResourceWithErrorInfo on stream error', () async {
      // Given
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'));
      final request = Request(
          operation: Operation(document: query, operationName: 'UserInfo'));
      final response = MockResponse();
      when(() => response.context).thenReturn(const Context());
      String? capturedKey;
      when(() => mockRum.startResource(any(), any(), any(), any()))
          .thenAnswer((i) {
        capturedKey = i.positionalArguments[0] as String;
      });

      // When
      final responseController = StreamController<Response>();
      final stream = link.request(request, (request) {
        return responseController.stream;
      });

      responseController.sink.addError('FakeError', StackTrace.current);
      unawaited(responseController.sink.close());
      try {
        await stream.drain();
      } catch (_) {}

      // Then
      verify(() => mockRum
          .stopResourceWithErrorInfo(capturedKey!, 'FakeError', 'String', {}));
    });

    test('link calls listener on stream error', () async {
      // Given
      final listener = MockDatadogGqlListener();
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'),
          listener: listener);
      final request = Request(
          operation: Operation(document: query, operationName: 'UserInfo'));
      final response = MockResponse();
      when(() => response.context).thenReturn(const Context());

      // When
      final responseController = StreamController<Response>();
      final stream = link.request(request, (request) {
        return responseController.stream;
      });

      final st = StackTrace.current;
      responseController.sink.addError('FakeError', st);
      unawaited(responseController.sink.close());
      try {
        await stream.drain();
      } catch (_) {}

      // Then
      verify(() => listener.requestError('FakeError', st, {}));
    });

    test('link adds attributes from listener on stream error', () async {
      // Given
      final listener = MockDatadogGqlListener();
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'),
          listener: listener);
      final request = Request(
          operation: Operation(document: query, operationName: 'UserInfo'));
      final response = MockResponse();
      when(() => response.context).thenReturn(const Context());
      when(() => listener.requestError(any(), any(), any()))
          .thenAnswer((invocation) {
        final attributes =
            invocation.positionalArguments[2] as Map<String, Object?>;
        attributes['error_attribute'] = 'error cause';
      });

      // When
      final responseController = StreamController<Response>();
      final stream = link.request(request, (request) {
        return responseController.stream;
      });

      final st = StackTrace.current;
      responseController.sink.addError('FakeError', st);
      unawaited(responseController.sink.close());
      try {
        await stream.drain();
      } catch (_) {}

      // Then
      final captured = verify(() => mockRum.stopResourceWithErrorInfo(
          any(), 'FakeError', 'String', captureAny()));
      final capturedAttrs = captured.captured[0] as Map<String, dynamic>;
      expect(capturedAttrs['error_attribute'], 'error cause');
    });

    test('link merges attributes from listener on stream error', () async {
      // Given
      final listener = MockDatadogGqlListener();
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'),
          listener: listener);
      final request = Request(
          operation: Operation(document: query, operationName: 'UserInfo'));
      final response = MockResponse();
      when(() => response.context).thenReturn(const Context());
      when(() => listener.requestStarted(request, any()))
          .thenAnswer((invocation) {
        final attributes =
            invocation.positionalArguments[1] as Map<String, Object?>;
        attributes['request_attribute'] = 'my request';
      });
      when(() => listener.requestError(any(), any(), any()))
          .thenAnswer((invocation) {
        final attributes =
            invocation.positionalArguments[2] as Map<String, Object?>;
        attributes['error_attribute'] = 'error cause';
      });

      // When
      final responseController = StreamController<Response>();
      final stream = link.request(request, (request) {
        return responseController.stream;
      });

      final st = StackTrace.current;
      responseController.sink.addError('FakeError', st);
      unawaited(responseController.sink.close());
      try {
        await stream.drain();
      } catch (_) {}

      // Then
      final captured = verify(() => mockRum.stopResourceWithErrorInfo(
          any(), 'FakeError', 'String', captureAny()));
      final capturedAttrs = captured.captured[0] as Map<String, dynamic>;
      expect(capturedAttrs['request_attribute'], 'my request');
      expect(capturedAttrs['error_attribute'], 'error cause');
    });

    test('link adds graphql errors to attributes', () async {
      // Given
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'));
      final request = Request(
          operation: Operation(document: query, operationName: 'UserInfo'));
      final response = MockResponse();
      when(() => response.context).thenReturn(const Context());
      when(() => response.errors).thenReturn([
        const GraphQLError(
          message: 'GraphQL Error Message',
          locations: [
            ErrorLocation(line: 1, column: 10),
          ],
          path: ['heroes', 2, 'name'],
        )
      ]);
      // When
      final responseController = StreamController<Response>();
      final stream = link.request(request, (request) {
        return responseController.stream;
      });

      responseController.sink.add(response);
      unawaited(responseController.sink.close());
      await stream.drain();

      // Then
      final captured = verify(() => mockRum.stopResource(
          any(), any(), RumResourceType.native, any(), captureAny()));
      final capturedAttrs = captured.captured[0] as Map<String, dynamic>;
      expect(capturedAttrs['_dd']['graphql']['errors'], [
        {
          'message': 'GraphQL Error Message',
          'locations': [
            {
              'line': 1,
              'column': 10,
            }
          ],
          'path': ['heroes', 2, 'name'],
        }
      ]);
    });

    test('link supports mutation operations in attributes', () async {
      // Given
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'));
      final mutation = lang.parseString('''
  mutation AddStar(\$starrableId: ID!) {
    addStar(input: {starrableId: \$starrableId}) {
      starrable {
        viewerHasStarred
      }
    }
  }
''');
      final request = Request(
          operation: Operation(document: mutation, operationName: 'AddStar'));

      // When
      link.request(request, (request) {
        return const Stream<Response>.empty();
      });

      // Then
      final capturedAttributes = verify(() => mockRum.startResource(
              any(), RumHttpMethod.post, 'https://test_uri', captureAny()))
          .captured[0] as Map<String, Object?>;
      expect(capturedAttributes['_dd.graphql.operation_type'], 'mutation');
      expect(capturedAttributes['_dd.graphql.operation_name'], 'AddStar');
    });

    test('link supports subscription operations in attributes', () async {
      // Given
      final link = DatadogGqlLink(mockDatadog, Uri.parse('https://test_uri'));
      final subscription = lang.parseString('''
  subscription ReviewAdded {
      reviewAdded {
        stars, commentary, episode
      }
    }
''');
      final request = Request(
          operation:
              Operation(document: subscription, operationName: 'ReviewAdded'));

      // When
      link.request(request, (request) {
        return const Stream<Response>.empty();
      });

      // Then
      final capturedAttributes = verify(() => mockRum.startResource(
              any(), RumHttpMethod.post, 'https://test_uri', captureAny()))
          .captured[0] as Map<String, Object?>;
      expect(capturedAttributes['_dd.graphql.operation_type'], 'subscription');
      expect(capturedAttributes['_dd.graphql.operation_name'], 'ReviewAdded');
    });
  });

  for (final headerType in TracingHeaderType.values) {
    group('when rum is enabled with $headerType tracing headers', () {
      setUp(() {
        mockPlatform = MockDatadogSdkPlatform();
        mockDatadog = MockDatadogSdk();
        when(() => mockDatadog.headerTypesForHost(
            any(that: HasHost(equals('test_url'))))).thenReturn({headerType});
        when(() => mockDatadog.headerTypesForHost(
            any(that: HasHost(equals('non_first_party'))))).thenReturn({});
        when(() => mockDatadog.platform).thenReturn(mockPlatform);
        // ignore: invalid_use_of_internal_member
        when(() => mockDatadog.internalLogger).thenReturn(MockInternalLogger());

        when(() => mockRum.shouldSampleTrace()).thenReturn(true);
        when(() => mockRum.traceSampleRate).thenReturn(50.0);
        when(() => mockDatadog.rum).thenReturn(mockRum);
      });

      test('does not set trace attributes when should sample returns false',
          () {
        // Given
        when(() => mockRum.shouldSampleTrace()).thenReturn(false);
        final link =
            DatadogGqlLink(mockDatadog, Uri.parse('https://test_url/graphql'));
        final request = Request(
            operation: Operation(document: query, operationName: 'UserInfo'));

        // When
        link.request(request, (request) {
          return const Stream<Response>.empty();
        });

        // Then
        final capturedAttrs = verify(
                () => mockRum.startResource(any(), any(), any(), captureAny()))
            .captured[0] as Map<String, Object?>;
        expect(capturedAttrs[DatadogRumPlatformAttributeKey.traceID], isNull);
        expect(capturedAttrs[DatadogRumPlatformAttributeKey.spanID], isNull);
        expect(capturedAttrs[DatadogRumPlatformAttributeKey.rulePsr], 0.50);
      });

      test('start resource loading sets tracing attributes', () {
        // Given
        when(() => mockRum.shouldSampleTrace()).thenReturn(true);
        final link =
            DatadogGqlLink(mockDatadog, Uri.parse('https://test_url/graphql'));
        final request = Request(
            operation: Operation(document: query, operationName: 'UserInfo'));

        // When
        link.request(request, (request) {
          return const Stream<Response>.empty();
        });

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

      // This should not happen as links are url specific, but we should check anyway.
      test('does not set trace headers for third party urls', () async {
        when(() => mockRum.shouldSampleTrace()).thenReturn(true);
        final link = DatadogGqlLink(
            mockDatadog, Uri.parse('https://non_first_party/graphql'));
        final request = Request(
            operation: Operation(document: query, operationName: 'UserInfo'));

        // When
        Request? forwardedRequest;
        link.request(request, (request) {
          forwardedRequest = request;
          return const Stream<Response>.empty();
        });

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
        final headersEntry = forwardedRequest!.context.entry<HttpLinkHeaders>();
        for (var header in headers) {
          expect(headersEntry?.headers[header], isNull);
        }
      });

      test(
          'sets trace headers for first party urls { sampled, TraceContextInjection.all }',
          () {
        when(() => mockRum.shouldSampleTrace()).thenReturn(true);
        when(() => mockRum.contextInjectionSetting)
            .thenReturn(TraceContextInjection.all);
        final link =
            DatadogGqlLink(mockDatadog, Uri.parse('https://test_url/graphql'));
        final request = Request(
            operation: Operation(document: query, operationName: 'UserInfo'));

        // When
        Request? forwardedRequest;
        link.request(request, (request) {
          forwardedRequest = request;
          return const Stream<Response>.empty();
        });

        final headersEntry = forwardedRequest!.context.entry<HttpLinkHeaders>();
        verifyHeaders(
            headersEntry!.headers, headerType, true, TraceContextInjection.all);
      });

      test(
          'sets trace headers for first party urls { sampled, TraceContextInjection.sampled }',
          () {
        when(() => mockRum.shouldSampleTrace()).thenReturn(true);
        when(() => mockRum.contextInjectionSetting)
            .thenReturn(TraceContextInjection.sampled);
        final link =
            DatadogGqlLink(mockDatadog, Uri.parse('https://test_url/graphql'));
        final request = Request(
            operation: Operation(document: query, operationName: 'UserInfo'));

        // When
        Request? forwardedRequest;
        link.request(request, (request) {
          forwardedRequest = request;
          return const Stream<Response>.empty();
        });

        final headersEntry = forwardedRequest!.context.entry<HttpLinkHeaders>();
        verifyHeaders(headersEntry!.headers, headerType, true,
            TraceContextInjection.sampled);
      });

      test(
          'sets trace headers for first party urls { unsampled, TraceContextInjection.all }, ',
          () {
        when(() => mockRum.shouldSampleTrace()).thenReturn(false);
        when(() => mockRum.contextInjectionSetting)
            .thenReturn(TraceContextInjection.all);
        final link =
            DatadogGqlLink(mockDatadog, Uri.parse('https://test_url/graphql'));
        final request = Request(
            operation: Operation(document: query, operationName: 'UserInfo'));

        // When
        Request? forwardedRequest;
        link.request(request, (request) {
          forwardedRequest = request;
          return const Stream<Response>.empty();
        });

        final headersEntry = forwardedRequest!.context.entry<HttpLinkHeaders>();
        verifyHeaders(headersEntry!.headers, headerType, false,
            TraceContextInjection.all);
      });

      test(
          'does not sets trace headers for first party urls { unsampled, TraceContextInjection.sampled }, ',
          () {
        when(() => mockRum.shouldSampleTrace()).thenReturn(false);
        when(() => mockRum.contextInjectionSetting)
            .thenReturn(TraceContextInjection.sampled);
        final link =
            DatadogGqlLink(mockDatadog, Uri.parse('https://test_url/graphql'));
        final request = Request(
            operation: Operation(document: query, operationName: 'UserInfo'));

        // When
        Request? forwardedRequest;
        link.request(request, (request) {
          forwardedRequest = request;
          return const Stream<Response>.empty();
        });

        final headersEntry = forwardedRequest!.context.entry<HttpLinkHeaders>();
        verifyHeaders(headersEntry!.headers, headerType, false,
            TraceContextInjection.sampled);
      });
    });
  }
}

void verifyHeaders(
  Map<String, String> headers,
  TracingHeaderType type,
  bool shouldSample,
  TraceContextInjection traceContextInjection,
) {
  BigInt? traceInt;
  BigInt? spanInt;

  bool shouldInjectHeaders =
      shouldSample || traceContextInjection == TraceContextInjection.all;

  switch (type) {
    case TracingHeaderType.datadog:
      if (shouldInjectHeaders) {
        expect(headers['x-datadog-origin'], 'rum');
        expect(
            headers['x-datadog-sampling-priority'], shouldSample ? '1' : '0');
        var traceValue = headers['x-datadog-trace-id']!;
        traceInt = BigInt.tryParse(traceValue);
        var spanValue = headers['x-datadog-parent-id']!;
        spanInt = BigInt.tryParse(spanValue);
        var tagsHeader = headers['x-datadog-tags'];
        expect(tagsHeader, isNotNull);
        final parts = tagsHeader?.split('=');
        expect(parts, isNotNull);
        expect(parts?[0], '_dd.p.tid');
        BigInt? highTraceInt = BigInt.tryParse(parts?[1] ?? '', radix: 16);
        expect(highTraceInt, isNotNull);
        expect(highTraceInt?.bitLength, lessThanOrEqualTo(64));
      } else {
        expect(headers['x-datadog-origin'], isNull);
        expect(headers['x-datadog-sampling-priority'], isNull);
        expect(headers['x-datadog-trace-id'], isNull);
        expect(headers['x-datadog-parent-id'], isNull);
        expect(headers['x-datadog-tags'], isNull);
      }
      break;
    case TracingHeaderType.b3:
      var singleHeader = headers['b3'];
      if (shouldSample) {
        var headerParts = singleHeader!.split('-');
        traceInt = BigInt.tryParse(headerParts[0], radix: 16);
        spanInt = BigInt.tryParse(headerParts[1], radix: 16);
        expect(headerParts[2], shouldSample ? '1' : '0');
      } else if (shouldInjectHeaders) {
        expect(singleHeader, '0');
      } else {
        expect(singleHeader, isNull);
      }
      break;
    case TracingHeaderType.b3multi:
      if (shouldInjectHeaders) {
        expect(headers['X-B3-Sampled'], shouldSample ? '1' : '0');
        if (shouldSample) {
          var traceValue = headers['X-B3-TraceId']!;
          traceInt = BigInt.tryParse(traceValue, radix: 16);
          var spanValue = headers['X-B3-SpanId']!;
          spanInt = BigInt.tryParse(spanValue, radix: 16);
        }
      } else {
        expect(headers['X-B3-Sampled'], isNull);
        expect(headers['X-B3-TraceId'], isNull);
        expect(headers['X-B3-SpanId'], isNull);
      }
      break;
    case TracingHeaderType.tracecontext:
      if (shouldInjectHeaders) {
        var header = headers['traceparent']!;
        var headerParts = header.split('-');
        expect(headerParts[0], '00');
        traceInt = BigInt.tryParse(headerParts[1], radix: 16);
        spanInt = BigInt.tryParse(headerParts[2], radix: 16);
        expect(headerParts[3], shouldSample ? '01' : '00');
        final stateHeader = headers['tracestate']!;

        final stateParts = getDdTraceState(stateHeader);
        expect(stateParts['s'], shouldSample ? '1' : '0');
        expect(stateParts['o'], 'rum');
        expect(stateParts['p'], headerParts[2]);
      } else {
        expect(headers['traceparent'], isNull);
      }
      break;
  }

  if (shouldSample) {
    expect(traceInt, isNotNull);
  }
  if (traceInt != null) {
    if (type == TracingHeaderType.datadog) {
      expect(traceInt.bitLength, lessThanOrEqualTo(64));
    } else {
      expect(traceInt.bitLength, lessThanOrEqualTo(128));
    }
  }

  if (shouldSample) {
    expect(spanInt, isNotNull);
  }
  if (spanInt != null) {
    expect(spanInt.bitLength, lessThanOrEqualTo(63));
  }
}
