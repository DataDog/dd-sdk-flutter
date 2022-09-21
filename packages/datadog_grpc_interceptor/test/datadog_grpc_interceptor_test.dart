// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_grpc_interceptor/datadog_grpc_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'src/generated/helloworld.pbgrpc.dart';

class DatadogSdkMock extends Mock implements DatadogSdk {}

class RumMock extends Mock implements DdRum {}

class LoggingGreeterService extends GreeterServiceBase {
  List<ServiceCall> calls = [];

  @override
  Future<HelloReply> sayHello(ServiceCall call, HelloRequest request) async {
    calls.add(call);
    return HelloReply(message: 'Hello, ${request.name}');
  }
}

void main() {
  const int port = 50192;
  late LoggingGreeterService loggingService;

  late DatadogSdkMock mockDatadog;
  late RumMock mockRum;

  setUpAll(() {
    registerFallbackValue(Uri(host: 'localhost'));
  });

  group('all tests with insecure channel', () {
    late ClientChannel channel;
    late Server server;

    setUp(() async {
      channel = ClientChannel(
        'localhost',
        port: port,
        options: const ChannelOptions(
          credentials: ChannelCredentials.insecure(),
        ),
      );
      loggingService = LoggingGreeterService();
      server = Server([loggingService]);
      await server.serve(port: port);

      mockDatadog = DatadogSdkMock();
      mockRum = RumMock();
      when(() => mockDatadog.rum).thenReturn(mockRum);
      when(() => mockRum.shouldSampleTrace()).thenReturn(true);
    });

    tearDown(() async {
      await channel.shutdown();
      await server.shutdown();
    });

    test('Interceptor calls proper rum functions', () async {
      when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(true);

      final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

      final stub = GreeterClient(channel, interceptors: [interceptor]);

      await stub.sayHello(HelloRequest(name: 'test'));

      final captures = verify(() => mockRum.startResourceLoading(
          captureAny(),
          RumHttpMethod.get,
          'http://localhost:$port/helloworld.Greeter/SayHello',
          captureAny())).captured;
      final key = captures[0] as String;
      final attributes = captures[1] as Map<String, Object?>;

      expect(attributes['grpc.method'], '/helloworld.Greeter/SayHello');

      verify(
          () => mockRum.stopResourceLoading(key, 200, RumResourceType.native));
    });

    test('Interceptor calls send tracing attributes', () async {
      when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(true);

      final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

      final stub = GreeterClient(channel, interceptors: [interceptor]);

      await stub.sayHello(HelloRequest(name: 'test'));

      final captures = verify(() => mockRum.startResourceLoading(
          captureAny(),
          RumHttpMethod.get,
          'http://localhost:$port/helloworld.Greeter/SayHello',
          captureAny())).captured;
      final attributes = captures[1] as Map<String, Object?>;
      expect(attributes['_dd.trace_id'], isNotNull);
      expect(BigInt.tryParse(attributes['_dd.trace_id'] as String), isNotNull);
      expect(attributes['_dd.span_id'], isNotNull);
      expect(BigInt.tryParse(attributes['_dd.span_id'] as String), isNotNull);
    });

    test(
        'Interceptor calls do not send tracing attributes when shouldSample returns false',
        () async {
      when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(true);
      when(() => mockRum.shouldSampleTrace()).thenReturn(false);

      final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

      final stub = GreeterClient(channel, interceptors: [interceptor]);

      await stub.sayHello(HelloRequest(name: 'test'));

      final captures = verify(() => mockRum.startResourceLoading(
          captureAny(),
          RumHttpMethod.get,
          'http://localhost:$port/helloworld.Greeter/SayHello',
          captureAny())).captured;
      final attributes = captures[1] as Map<String, Object?>;
      expect(attributes['_dd.trace_id'], isNull);
      expect(attributes['_dd.span_id'], isNull);
    });

    test('Interceptor passes on proper metadata', () async {
      when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(true);

      final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

      final stub = GreeterClient(channel, interceptors: [interceptor]);

      await stub.sayHello(HelloRequest(name: 'test'));

      expect(loggingService.calls.length, 1);
      final call = loggingService.calls[0];
      expect(call.clientMetadata!['x-datadog-trace-id'], isNotNull);
      expect(
          BigInt.tryParse(call.clientMetadata!['x-datadog-trace-id'] as String),
          isNotNull);
      expect(call.clientMetadata!['x-datadog-parent-id'], isNotNull);
      expect(
          BigInt.tryParse(
              call.clientMetadata!['x-datadog-parent-id'] as String),
          isNotNull);
      expect(call.clientMetadata!['x-datadog-origin'], 'rum');
      expect(call.clientMetadata!['x-datadog-sampling-priority'], '1');
    });

    test(
        'Interceptor does not send traces metadata when shouldSample returns false',
        () async {
      when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(true);
      when(() => mockRum.shouldSampleTrace()).thenReturn(false);

      final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

      final stub = GreeterClient(channel, interceptors: [interceptor]);

      await stub.sayHello(HelloRequest(name: 'test'));

      expect(loggingService.calls.length, 1);
      final call = loggingService.calls[0];
      expect(call.clientMetadata!['x-datadog-trace-id'], isNull);
      expect(call.clientMetadata!['x-datadog-parent-id'], isNull);
      expect(call.clientMetadata!['x-datadog-origin'], isNull);
      expect(call.clientMetadata!['x-datadog-sampling-priority'], '0');
    });

    test('Interceptor does not send traces for non-first-party hosts',
        () async {
      when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(false);

      final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

      final stub = GreeterClient(channel, interceptors: [interceptor]);

      await stub.sayHello(HelloRequest(name: 'test'));

      expect(loggingService.calls.length, 1);
      final call = loggingService.calls[0];
      expect(call.clientMetadata!['x-datadog-trace-id'], isNull);
      expect(call.clientMetadata!['x-datadog-parent-id'], isNull);
      expect(call.clientMetadata!['x-datadog-origin'], isNull);
      expect(call.clientMetadata!['x-datadog-sampling-priority'], isNull);
    });

    test(
        'Interceptor calls do not send tracing attributes for non-first-party hosts',
        () async {
      when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(false);

      final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

      final stub = GreeterClient(channel, interceptors: [interceptor]);

      await stub.sayHello(HelloRequest(name: 'test'));

      final captures = verify(() => mockRum.startResourceLoading(
          captureAny(),
          RumHttpMethod.get,
          'http://localhost:$port/helloworld.Greeter/SayHello',
          captureAny())).captured;
      final attributes = captures[1] as Map<String, Object?>;
      expect(attributes['_dd.trace_id'], isNull);
      expect(attributes['_dd.span_id'], isNull);
    });
  });

  test('secure channel adds https scheme', () async {
    final channel = ClientChannel(
      'localhost',
      port: port,
      options: const ChannelOptions(
        credentials: ChannelCredentials.secure(),
      ),
    );
    loggingService = LoggingGreeterService();
    final server = Server([loggingService]);
    await server.serve(port: port);

    mockDatadog = DatadogSdkMock();
    mockRum = RumMock();
    when(() => mockDatadog.rum).thenReturn(mockRum);
    when(() => mockRum.shouldSampleTrace()).thenReturn(true);

    when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(true);

    final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

    final stub = GreeterClient(channel, interceptors: [interceptor]);

    try {
      await stub.sayHello(HelloRequest(name: 'test'));
    } catch (_) {
      // this is fine, we can't actually connect to a secure channel
    }

    final captures = verify(() => mockRum.startResourceLoading(
        captureAny(),
        RumHttpMethod.get,
        'https://localhost:$port/helloworld.Greeter/SayHello',
        captureAny())).captured;
    final key = captures[0] as String;
    final attributes = captures[1] as Map<String, Object?>;

    expect(attributes['grpc.method'], '/helloworld.Greeter/SayHello');

    verify(() =>
        mockRum.stopResourceLoadingWithErrorInfo(key, any(), 'GrpcError', {}));

    await channel.shutdown();
    await server.shutdown();
  });

  test('internet address channel adds scheme', () async {
    final channel = ClientChannel(
      InternetAddress.loopbackIPv4,
      port: port,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );
    loggingService = LoggingGreeterService();
    final server = Server([loggingService]);
    await server.serve(port: port);

    mockDatadog = DatadogSdkMock();
    mockRum = RumMock();
    when(() => mockDatadog.rum).thenReturn(mockRum);
    when(() => mockRum.shouldSampleTrace()).thenReturn(true);

    when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(true);

    final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

    final stub = GreeterClient(channel, interceptors: [interceptor]);

    await stub.sayHello(HelloRequest(name: 'test'));

    final captures = verify(() => mockRum.startResourceLoading(
        captureAny(),
        RumHttpMethod.get,
        'http://127.0.0.1:$port/helloworld.Greeter/SayHello',
        captureAny())).captured;
    final key = captures[0] as String;
    final attributes = captures[1] as Map<String, Object?>;

    expect(attributes['grpc.method'], '/helloworld.Greeter/SayHello');

    verify(() => mockRum.stopResourceLoading(key, 200, RumResourceType.native));

    await channel.shutdown();
    await server.shutdown();
  });

  test('secure internet address channel adds scheme', () async {
    final channel = ClientChannel(
      InternetAddress.loopbackIPv4,
      port: port,
      options: const ChannelOptions(
        credentials: ChannelCredentials.secure(),
      ),
    );
    loggingService = LoggingGreeterService();
    final server = Server([loggingService]);
    await server.serve(port: port);

    mockDatadog = DatadogSdkMock();
    mockRum = RumMock();
    when(() => mockDatadog.rum).thenReturn(mockRum);
    when(() => mockRum.shouldSampleTrace()).thenReturn(true);

    when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(true);

    final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

    final stub = GreeterClient(channel, interceptors: [interceptor]);

    try {
      await stub.sayHello(HelloRequest(name: 'test'));
    } catch (_) {
      // This is okay, we can't actually connect securely
    }

    final captures = verify(() => mockRum.startResourceLoading(
        captureAny(),
        RumHttpMethod.get,
        'https://127.0.0.1:$port/helloworld.Greeter/SayHello',
        captureAny())).captured;
    final key = captures[0] as String;
    final attributes = captures[1] as Map<String, Object?>;

    expect(attributes['grpc.method'], '/helloworld.Greeter/SayHello');

    verify(() =>
        mockRum.stopResourceLoadingWithErrorInfo(key, any(), 'GrpcError', {}));

    await channel.shutdown();
    await server.shutdown();
  });
}
