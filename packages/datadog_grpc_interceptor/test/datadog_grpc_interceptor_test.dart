// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
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

  void verifyHeaders(
      TracingHeaderType type, Map<String, String> metadata, bool sampled) {
    BigInt? traceInt;
    BigInt? spanInt;

    switch (type) {
      case TracingHeaderType.dd:
        expect(metadata['x-datadog-sampling-priority'], sampled ? '1' : '0');
        traceInt = BigInt.tryParse(metadata['x-datadog-trace-id'] ?? '');
        spanInt = BigInt.tryParse(metadata['x-datadog-parent-id'] ?? '');
        break;
      case TracingHeaderType.b3s:
        var singleHeader = metadata['b3']!;
        var headerParts = singleHeader.split('-');
        if (sampled) {
          traceInt = BigInt.tryParse(headerParts[0], radix: 16);
          spanInt = BigInt.tryParse(headerParts[1], radix: 16);
          expect(headerParts[2], '1');
        } else {
          expect(singleHeader, '0');
        }
        break;
      case TracingHeaderType.b3m:
        expect(metadata['x-b3-sampled'], sampled ? '1' : '0');
        traceInt = BigInt.tryParse(metadata['x-b3-traceid'] ?? '', radix: 16);
        spanInt = BigInt.tryParse(metadata['x-b3-spanid'] ?? '', radix: 16);
        break;
    }

    if (sampled) {
      expect(traceInt, isNotNull);
      expect(traceInt?.bitLength, lessThanOrEqualTo(63));

      expect(spanInt, isNotNull);
      expect(spanInt?.bitLength, lessThanOrEqualTo(63));
    } else {
      expect(traceInt, isNull);
      expect(spanInt, isNull);
    }
  }

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
      when(() => mockRum.tracingSamplingRate).thenReturn(12);
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

    for (var tracingType in TracingHeaderType.values) {
      group('with tracing header type $tracingType', () {
        test('Interceptor calls send tracing attributes', () async {
          when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(true);

          final interceptor = DatadogGrpcInterceptor(
            mockDatadog,
            channel,
            tracingHeaderTypes: {tracingType},
          );

          final stub = GreeterClient(channel, interceptors: [interceptor]);

          await stub.sayHello(HelloRequest(name: 'test'));

          final captures = verify(() => mockRum.startResourceLoading(
              captureAny(),
              RumHttpMethod.get,
              'http://localhost:$port/helloworld.Greeter/SayHello',
              captureAny())).captured;
          final attributes = captures[1] as Map<String, Object?>;
          expect(attributes['_dd.trace_id'], isNotNull);
          expect(
              BigInt.tryParse(attributes['_dd.trace_id'] as String), isNotNull);
          expect(attributes['_dd.span_id'], isNotNull);
          expect(
              BigInt.tryParse(attributes['_dd.span_id'] as String), isNotNull);
          expect(attributes['_dd.rule_psr'], 0.12);
        });

        test(
            'Interceptor calls do not send tracing attributes when shouldSample returns false',
            () async {
          when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(true);
          when(() => mockRum.shouldSampleTrace()).thenReturn(false);

          final interceptor = DatadogGrpcInterceptor(
            mockDatadog,
            channel,
            tracingHeaderTypes: {tracingType},
          );

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
          expect(attributes['_dd.rule_psr'], 0.12);
        });

        test('Interceptor passes on proper metadata', () async {
          when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(true);

          final interceptor = DatadogGrpcInterceptor(
            mockDatadog,
            channel,
            tracingHeaderTypes: {tracingType},
          );

          final stub = GreeterClient(channel, interceptors: [interceptor]);

          await stub.sayHello(HelloRequest(name: 'test'));

          expect(loggingService.calls.length, 1);
          final call = loggingService.calls[0];
          verifyHeaders(tracingType, call.clientMetadata!, true);
        });

        test(
            'Interceptor does not send traces metadata when shouldSample returns false',
            () async {
          when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(true);
          when(() => mockRum.shouldSampleTrace()).thenReturn(false);

          final interceptor = DatadogGrpcInterceptor(
            mockDatadog,
            channel,
            tracingHeaderTypes: {tracingType},
          );

          final stub = GreeterClient(channel, interceptors: [interceptor]);

          await stub.sayHello(HelloRequest(name: 'test'));

          expect(loggingService.calls.length, 1);
          final call = loggingService.calls[0];
          verifyHeaders(tracingType, call.clientMetadata!, false);
        });
      });
    }

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

    test('extracts b3m headers and sets attributes', () async {
      when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(true);

      final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

      final stub = GreeterClient(channel, interceptors: [interceptor]);
      // Randomly generated
      //  - 61ffb765f4f77e3b == 7061564389269667387
      //  - 3eb5c1bcb46ab916 == 4518730817361066262
      final options = CallOptions(metadata: {
        'x-b3-traceid': '000000000000000061FFB765F4F77E3B',
        'x-b3-spanid': '3EB5C1BCB46AB916',
        'x-b3-sampled': '1',
      });

      await stub.sayHello(HelloRequest(name: 'test'), options: options);

      expect(loggingService.calls.length, 1);
      final call = loggingService.calls[0];

      expect(
          call.clientMetadata!['x-datadog-trace-id']!, '7061564389269667387');
      expect(
          call.clientMetadata!['x-datadog-parent-id']!, '4518730817361066262');

      final captures = verify(() => mockRum.startResourceLoading(
          captureAny(),
          RumHttpMethod.get,
          'http://localhost:$port/helloworld.Greeter/SayHello',
          captureAny())).captured;
      final attributes = captures[1] as Map<String, Object?>;
      var traceInt = BigInt.parse(
          attributes[DatadogRumPlatformAttributeKey.traceID] as String);
      expect(traceInt, BigInt.from(0x61ffb765f4f77e3b));
      var spanInt = BigInt.parse(
          attributes[DatadogRumPlatformAttributeKey.spanID] as String);
      expect(spanInt, BigInt.from(0x3eb5c1bcb46ab916));
    });

    test('extracts b3s headers and sets attributes', () async {
      when(() => mockDatadog.isFirstPartyHost(any())).thenReturn(true);

      final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

      final stub = GreeterClient(channel, interceptors: [interceptor]);
      // Randomly generated
      //  - 61ffb765f4f77e3b == 7061564389269667387
      //  - 3eb5c1bcb46ab916 == 4518730817361066262
      final options = CallOptions(metadata: {
        'b3': '000000000000000061FFB765F4F77E3B-3EB5C1BCB46AB916-1',
      });

      await stub.sayHello(HelloRequest(name: 'test'), options: options);

      expect(loggingService.calls.length, 1);
      final call = loggingService.calls[0];

      expect(
          call.clientMetadata!['x-datadog-trace-id']!, '7061564389269667387');
      expect(
          call.clientMetadata!['x-datadog-parent-id']!, '4518730817361066262');

      final captures = verify(() => mockRum.startResourceLoading(
          captureAny(),
          RumHttpMethod.get,
          'http://localhost:$port/helloworld.Greeter/SayHello',
          captureAny())).captured;
      final attributes = captures[1] as Map<String, Object?>;
      var traceInt = BigInt.parse(
          attributes[DatadogRumPlatformAttributeKey.traceID] as String);
      expect(traceInt, BigInt.from(0x61ffb765f4f77e3b));
      var spanInt = BigInt.parse(
          attributes[DatadogRumPlatformAttributeKey.spanID] as String);
      expect(spanInt, BigInt.from(0x3eb5c1bcb46ab916));
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
    when(() => mockRum.tracingSamplingRate).thenReturn(12);
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
    when(() => mockRum.tracingSamplingRate).thenReturn(12);
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
    when(() => mockRum.tracingSamplingRate).thenReturn(12);
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
