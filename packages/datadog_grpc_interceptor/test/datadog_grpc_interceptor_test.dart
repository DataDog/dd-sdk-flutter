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

  late DatadogSdkMock mockDatadog;
  late RumMock mockRum;

  setUpAll(() {
    registerFallbackValue(Uri(host: 'localhost'));
  });

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

    final _ = await stub.sayHello(HelloRequest(name: 'test'));

    final captures = verify(() => mockRum.startResourceLoading(
        captureAny(),
        RumHttpMethod.get,
        'localhost:$port/helloworld.Greeter/SayHello',
        captureAny())).captured;
    final key = captures[0];
    final attributes = captures[1];
    // TODO: Double check that this is a proper value for the grpc.method
    expect(attributes['grpc.method'], '/helloworld.Greeter/SayHello');

    verify(() => mockRum.stopResourceLoading(key, 200, RumResourceType.native));
  });

  test(
      'Interceptor calls do not send tracing attributes when tracing is disabled',
      () async {
    when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(true);

    final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

    final stub = GreeterClient(channel, interceptors: [interceptor]);

    final _ = await stub.sayHello(HelloRequest(name: 'test'));

    final captures = verify(() => mockRum.startResourceLoading(
        captureAny(),
        RumHttpMethod.get,
        'localhost:$port/helloworld.Greeter/SayHello',
        captureAny())).captured;
    final attributes = captures[1];
    expect(attributes['_dd.trace_id'], isNull);
    expect(attributes['_dd.span_id'], isNull);
  });

  test('Interceptor calls send tracing attributes when tracing is enabled',
      () async {
    final mockTraces = TracesMock();
    when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(true);
    when(() => mockDatadog.traces).thenReturn(mockTraces);

    final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

    final stub = GreeterClient(channel, interceptors: [interceptor]);

    final _ = await stub.sayHello(HelloRequest(name: 'test'));

    final captures = verify(() => mockRum.startResourceLoading(
        captureAny(),
        RumHttpMethod.get,
        'localhost:$port/helloworld.Greeter/SayHello',
        captureAny())).captured;
    final attributes = captures[1];
    expect(attributes['_dd.trace_id'], isNotNull);
    expect(BigInt.tryParse(attributes['_dd.trace_id'] as String), isNotNull);
    expect(attributes['_dd.span_id'], isNotNull);
    expect(BigInt.tryParse(attributes['_dd.span_id'] as String), isNotNull);
  });

  test(
      'Interceptor calls do not send tracing attributes when shouldSample returns false',
      () async {
    final mockTraces = TracesMock();
    when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(true);
    when(() => mockDatadog.traces).thenReturn(mockTraces);
    when(() => mockRum.shouldSampleTrace()).thenReturn(false);

    final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

    final stub = GreeterClient(channel, interceptors: [interceptor]);

    final _ = await stub.sayHello(HelloRequest(name: 'test'));

    final captures = verify(() => mockRum.startResourceLoading(
        captureAny(),
        RumHttpMethod.get,
        'localhost:$port/helloworld.Greeter/SayHello',
        captureAny())).captured;
    final attributes = captures[1];
    expect(attributes['_dd.trace_id'], isNull);
    expect(attributes['_dd.span_id'], isNull);
  });

  test('Interceptor passes on proper metadata when traces are enabled',
      () async {
    final mockTraces = TracesMock();
    when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(true);
    when(() => mockDatadog.traces).thenReturn(mockTraces);

    final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

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

  test('Interceptor does not add metadata when traces are disabled', () async {
    when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(true);

    final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

    final stub = GreeterClient(channel, interceptors: [interceptor]);

    final _ = await stub.sayHello(HelloRequest(name: 'test'));

    expect(loggingService.calls.length, 1);
    final call = loggingService.calls[0];
    expect(call.clientMetadata!['x-datadog-trace-id'], isNull);
    expect(call.clientMetadata!['x-datadog-parent-id'], isNull);
    expect(call.clientMetadata!['x-datadog-origin'], isNull);
    expect(call.clientMetadata!['x-datadog-sampling-priority'], '0');
  });

  test('Interceptor does not send traces for when shouldSample returns false',
      () async {
    final mockTraces = TracesMock();
    when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(true);
    when(() => mockDatadog.traces).thenReturn(mockTraces);
    when(() => mockRum.shouldSampleTrace()).thenReturn(false);

    final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

    final stub = GreeterClient(channel, interceptors: [interceptor]);

    final _ = await stub.sayHello(HelloRequest(name: 'test'));

    expect(loggingService.calls.length, 1);
    final call = loggingService.calls[0];
    expect(call.clientMetadata!['x-datadog-trace-id'], isNull);
    expect(call.clientMetadata!['x-datadog-parent-id'], isNull);
    expect(call.clientMetadata!['x-datadog-origin'], isNull);
    expect(call.clientMetadata!['x-datadog-sampling-priority'], '0');
  });

  test('Interceptor does not send traces for non-first-party hosts', () async {
    final mockTraces = TracesMock();
    when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(false);
    when(() => mockDatadog.traces).thenReturn(mockTraces);

    final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

    final stub = GreeterClient(channel, interceptors: [interceptor]);

    final _ = await stub.sayHello(HelloRequest(name: 'test'));

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
    final mockTraces = TracesMock();
    when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(false);
    when(() => mockDatadog.traces).thenReturn(mockTraces);

    final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

    final stub = GreeterClient(channel, interceptors: [interceptor]);

    final _ = await stub.sayHello(HelloRequest(name: 'test'));

    final captures = verify(() => mockRum.startResourceLoading(
        captureAny(),
        RumHttpMethod.get,
        'localhost:$port/helloworld.Greeter/SayHello',
        captureAny())).captured;
    final attributes = captures[1];
    expect(attributes['_dd.trace_id'], isNull);
    expect(attributes['_dd.span_id'], isNull);
  });
}
