// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/src/rum/ddrum.dart';
import 'package:datadog_flutter_plugin/src/traces/ddtraces.dart';
import 'package:datadog_grpc_interceptor/datadog_grpc_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'src/generated/helloworld.pbgrpc.dart';

class DatadogSdkMock extends Mock implements DatadogSdk {}

class RumMock extends Mock implements DdRum {}

class TracesMock extends Fake implements DdTraces {}

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
  late ClientChannel channel;
  late Server server;
  late LoggingGreeterService loggingService;

  setUp(() async {
    channel = ClientChannel(
      'localhost',
      port: 50192,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );
    loggingService = LoggingGreeterService();
    server = Server([loggingService]);
    await server.serve(port: 50192);
  });

  tearDown(() async {
    await channel.shutdown();
    await server.shutdown();
  });

  test('Interceptor calls proper rum functions', () async {
    final mockDatadog = DatadogSdkMock();
    final mockRum = RumMock();
    when(() => mockDatadog.rum).thenReturn(mockRum);

    final interceptor = DatadogGrpcInterceptor(mockDatadog);

    final stub = GreeterClient(channel, interceptors: [interceptor]);

    final _ = await stub.sayHello(HelloRequest(name: 'test'));

    final captures = verify(() => mockRum.startResourceLoading(
        captureAny(),
        RumHttpMethod.get,
        '/helloworld.Greeter/SayHello',
        captureAny())).captured;
    final key = captures[0];
    final attributes = captures[1];
    // TODO: Double check that this is a proper value for the grpc.method
    expect(attributes['grpc.method'], '/helloworld.Greeter/SayHello');

    verify(() => mockRum.stopResourceLoading(key, 200, RumResourceType.native));
  });

  test('Interceptor calls do not send trace headers when tracing is disabled',
      () async {
    final mockDatadog = DatadogSdkMock();
    final mockRum = RumMock();
    when(() => mockDatadog.rum).thenReturn(mockRum);

    final interceptor = DatadogGrpcInterceptor(mockDatadog);

    final stub = GreeterClient(channel, interceptors: [interceptor]);

    final _ = await stub.sayHello(HelloRequest(name: 'test'));

    final captures = verify(() => mockRum.startResourceLoading(
        captureAny(),
        RumHttpMethod.get,
        '/helloworld.Greeter/SayHello',
        captureAny())).captured;
    final key = captures[0];
    final attributes = captures[1];
    expect(attributes['_dd.trace_id'], isNull);
    expect(attributes['_dd.span_id'], isNull);
  });

  test('Interceptor calls send trace headers when tracing is enabled',
      () async {
    final mockDatadog = DatadogSdkMock();
    final mockRum = RumMock();
    final mockTraces = TracesMock();
    when(() => mockDatadog.rum).thenReturn(mockRum);
    when(() => mockDatadog.traces).thenReturn(mockTraces);

    final interceptor = DatadogGrpcInterceptor(mockDatadog);

    final stub = GreeterClient(channel, interceptors: [interceptor]);

    final _ = await stub.sayHello(HelloRequest(name: 'test'));

    final captures = verify(() => mockRum.startResourceLoading(
        captureAny(),
        RumHttpMethod.get,
        '/helloworld.Greeter/SayHello',
        captureAny())).captured;
    final key = captures[0];
    final attributes = captures[1];
    expect(attributes['_dd.trace_id'], isNotNull);
    expect(BigInt.tryParse(attributes['_dd.trace_id'] as String), isNotNull);
    expect(attributes['_dd.span_id'], isNotNull);
    expect(BigInt.tryParse(attributes['_dd.span_id'] as String), isNotNull);
  });

  test('Interceptor does not add metadata when traces are disabled', () async {
    final mockDatadog = DatadogSdkMock();
    final mockRum = RumMock();
    final mockTraces = TracesMock();
    when(() => mockDatadog.rum).thenReturn(mockRum);
    when(() => mockDatadog.traces).thenReturn(mockTraces);

    final interceptor = DatadogGrpcInterceptor(mockDatadog);

    final stub = GreeterClient(channel, interceptors: [interceptor]);

    final _ = await stub.sayHello(HelloRequest(name: 'test'));

    expect(loggingService.calls.length, 1);
    final call = loggingService.calls[0];
    expect(call.clientMetadata!['x-datadog-trace-id'], isNotNull);
    expect(
        BigInt.tryParse(call.clientMetadata!['x-datadog-trace-id'] as String),
        isNotNull);
    expect(call.clientMetadata!['x-datadog-parent-id'], isNotNull);
    expect(
        BigInt.tryParse(call.clientMetadata!['x-datadog-parent-id'] as String),
        isNotNull);
    expect(call.clientMetadata!['x-datadog-origin'], 'rum');
    expect(call.clientMetadata!['x-datadog-sampling-priority'], '1');
  });

  test('Interceptor passes on proper metadata when traces are enabled',
      () async {
    final mockDatadog = DatadogSdkMock();
    final mockRum = RumMock();
    when(() => mockDatadog.rum).thenReturn(mockRum);

    final interceptor = DatadogGrpcInterceptor(mockDatadog);

    final stub = GreeterClient(channel, interceptors: [interceptor]);

    final _ = await stub.sayHello(HelloRequest(name: 'test'));

    expect(loggingService.calls.length, 1);
    final call = loggingService.calls[0];
    expect(call.clientMetadata!['x-datadog-trace-id'], isNull);
    expect(call.clientMetadata!['x-datadog-parent-id'], isNull);
    expect(call.clientMetadata!['x-datadog-origin'], isNull);
    expect(call.clientMetadata!['x-datadog-sampling-priority'], isNull);
  });
}
