// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_grpc_interceptor/datadog_grpc_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'src/generated/helloworld.pbgrpc.dart';

class DatadogSdkMock extends Mock implements DatadogSdk {}

class RumMock extends Mock implements DatadogRum {}

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
    TracingHeaderType type,
    Map<String, String> metadata,
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
            traceInt =
                BigInt.tryParse(metadata['x-b3-traceid'] ?? '', radix: 16);
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
      when(() => mockRum.contextInjectionSetting)
          .thenReturn(TraceContextInjection.all);
      when(() => mockRum.traceSampleRate).thenReturn(12);
    });

    tearDown(() async {
      await channel.shutdown();
      await server.shutdown();
    });

    test('Interceptor calls proper rum functions', () async {
      when(() => mockDatadog.headerTypesForHost(any()))
          .thenReturn({TracingHeaderType.datadog});

      final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

      final stub = GreeterClient(channel, interceptors: [interceptor]);

      await stub.sayHello(HelloRequest(name: 'test'));

      final captures = verify(() => mockRum.startResource(
          captureAny(),
          RumHttpMethod.get,
          'http://localhost:$port/helloworld.Greeter/SayHello',
          captureAny())).captured;
      final key = captures[0] as String;
      final attributes = captures[1] as Map<String, Object?>;

      expect(attributes['grpc.method'], '/helloworld.Greeter/SayHello');

      verify(() => mockRum.stopResource(key, 200, RumResourceType.native));
    });

    for (var tracingType in TracingHeaderType.values) {
      group('with tracing header type $tracingType', () {
        test('Interceptor calls send tracing attributes', () async {
          when(() => mockDatadog.headerTypesForHost(any()))
              .thenReturn({tracingType});

          final interceptor = DatadogGrpcInterceptor(
            mockDatadog,
            channel,
          );

          final stub = GreeterClient(channel, interceptors: [interceptor]);

          await stub.sayHello(HelloRequest(name: 'test'));

          final captures = verify(() => mockRum.startResource(
              captureAny(),
              RumHttpMethod.get,
              'http://localhost:$port/helloworld.Greeter/SayHello',
              captureAny())).captured;
          final attributes = captures[1] as Map<String, Object?>;
          expect(attributes['_dd.trace_id'], isNotNull);
          expect(
              BigInt.tryParse(attributes['_dd.trace_id'] as String, radix: 16),
              isNotNull);
          expect(attributes['_dd.span_id'], isNotNull);
          expect(
              BigInt.tryParse(attributes['_dd.span_id'] as String), isNotNull);
          expect(attributes['_dd.rule_psr'], 0.12);
        });

        test(
            'Interceptor calls do not send tracing attributes when shouldSample returns false',
            () async {
          when(() => mockDatadog.headerTypesForHost(any()))
              .thenReturn({tracingType});
          when(() => mockRum.shouldSampleTrace()).thenReturn(false);

          final interceptor = DatadogGrpcInterceptor(
            mockDatadog,
            channel,
          );

          final stub = GreeterClient(channel, interceptors: [interceptor]);

          await stub.sayHello(HelloRequest(name: 'test'));

          final captures = verify(() => mockRum.startResource(
              captureAny(),
              RumHttpMethod.get,
              'http://localhost:$port/helloworld.Greeter/SayHello',
              captureAny())).captured;
          final attributes = captures[1] as Map<String, Object?>;
          expect(attributes['_dd.trace_id'], isNull);
          expect(attributes['_dd.span_id'], isNull);
          expect(attributes['_dd.rule_psr'], 0.12);
        });

        test(
            'Interceptor passes on proper metadata { sampled, TraceContextInjection.all }',
            () async {
          when(() => mockRum.contextInjectionSetting)
              .thenReturn(TraceContextInjection.all);
          when(() => mockDatadog.headerTypesForHost(any()))
              .thenReturn({tracingType});

          final interceptor = DatadogGrpcInterceptor(
            mockDatadog,
            channel,
          );

          final stub = GreeterClient(channel, interceptors: [interceptor]);

          await stub.sayHello(HelloRequest(name: 'test'));

          expect(loggingService.calls.length, 1);
          final call = loggingService.calls[0];
          verifyHeaders(tracingType, call.clientMetadata!, true,
              TraceContextInjection.all);
        });

        test(
            'Interceptor passes on proper metadata { sampled, TraceContextInjection.sampled }',
            () async {
          when(() => mockRum.contextInjectionSetting)
              .thenReturn(TraceContextInjection.sampled);
          when(() => mockDatadog.headerTypesForHost(any()))
              .thenReturn({tracingType});

          final interceptor = DatadogGrpcInterceptor(
            mockDatadog,
            channel,
          );

          final stub = GreeterClient(channel, interceptors: [interceptor]);

          await stub.sayHello(HelloRequest(name: 'test'));

          expect(loggingService.calls.length, 1);
          final call = loggingService.calls[0];
          verifyHeaders(tracingType, call.clientMetadata!, true,
              TraceContextInjection.sampled);
        });

        test(
            'Interceptor does not send traces metadata returns false { unsampled, TraceContextInjection.all }',
            () async {
          when(() => mockDatadog.headerTypesForHost(any()))
              .thenReturn({tracingType});
          when(() => mockRum.contextInjectionSetting)
              .thenReturn(TraceContextInjection.all);
          when(() => mockRum.shouldSampleTrace()).thenReturn(false);

          final interceptor = DatadogGrpcInterceptor(
            mockDatadog,
            channel,
          );

          final stub = GreeterClient(channel, interceptors: [interceptor]);

          await stub.sayHello(HelloRequest(name: 'test'));

          expect(loggingService.calls.length, 1);
          final call = loggingService.calls[0];
          verifyHeaders(tracingType, call.clientMetadata!, false,
              TraceContextInjection.all);
        });

        test(
            'Interceptor does not send traces metadata returns false { unsampled, TraceContextInjection.sampled }',
            () async {
          when(() => mockDatadog.headerTypesForHost(any()))
              .thenReturn({tracingType});
          when(() => mockRum.contextInjectionSetting)
              .thenReturn(TraceContextInjection.sampled);
          when(() => mockRum.shouldSampleTrace()).thenReturn(false);

          final interceptor = DatadogGrpcInterceptor(
            mockDatadog,
            channel,
          );

          final stub = GreeterClient(channel, interceptors: [interceptor]);

          await stub.sayHello(HelloRequest(name: 'test'));

          expect(loggingService.calls.length, 1);
          final call = loggingService.calls[0];
          verifyHeaders(tracingType, call.clientMetadata!, false,
              TraceContextInjection.sampled);
        });
      });
    }

    test(
        'Interceptor calls do not send tracing attributes for non-first-party hosts',
        () async {
      when(() => mockDatadog.headerTypesForHost(any())).thenReturn({});

      final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

      final stub = GreeterClient(channel, interceptors: [interceptor]);

      await stub.sayHello(HelloRequest(name: 'test'));

      final captures = verify(() => mockRum.startResource(
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
    when(() => mockRum.traceSampleRate).thenReturn(12);
    when(() => mockRum.contextInjectionSetting)
        .thenReturn(TraceContextInjection.all);
    when(() => mockDatadog.headerTypesForHost(any()))
        .thenReturn({TracingHeaderType.datadog});

    final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

    final stub = GreeterClient(channel, interceptors: [interceptor]);

    try {
      await stub.sayHello(HelloRequest(name: 'test'));
    } catch (_) {
      // this is fine, we can't actually connect to a secure channel
    }

    final captures = verify(() => mockRum.startResource(
        captureAny(),
        RumHttpMethod.get,
        'https://localhost:$port/helloworld.Greeter/SayHello',
        captureAny())).captured;
    final key = captures[0] as String;
    final attributes = captures[1] as Map<String, Object?>;

    expect(attributes['grpc.method'], '/helloworld.Greeter/SayHello');

    verify(
        () => mockRum.stopResourceWithErrorInfo(key, any(), 'GrpcError', {}));

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
    when(() => mockRum.traceSampleRate).thenReturn(12);
    when(() => mockRum.contextInjectionSetting)
        .thenReturn(TraceContextInjection.all);
    when(() => mockDatadog.headerTypesForHost(any()))
        .thenReturn({TracingHeaderType.datadog});

    final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

    final stub = GreeterClient(channel, interceptors: [interceptor]);

    await stub.sayHello(HelloRequest(name: 'test'));

    final captures = verify(() => mockRum.startResource(
        captureAny(),
        RumHttpMethod.get,
        'http://127.0.0.1:$port/helloworld.Greeter/SayHello',
        captureAny())).captured;
    final key = captures[0] as String;
    final attributes = captures[1] as Map<String, Object?>;

    expect(attributes['grpc.method'], '/helloworld.Greeter/SayHello');

    verify(() => mockRum.stopResource(key, 200, RumResourceType.native));

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
    when(() => mockRum.traceSampleRate).thenReturn(12);
    when(() => mockRum.contextInjectionSetting)
        .thenReturn(TraceContextInjection.all);
    when(() => mockDatadog.headerTypesForHost(any()))
        .thenReturn({TracingHeaderType.datadog});

    final interceptor = DatadogGrpcInterceptor(mockDatadog, channel);

    final stub = GreeterClient(channel, interceptors: [interceptor]);

    try {
      await stub.sayHello(HelloRequest(name: 'test'));
    } catch (_) {
      // This is okay, we can't actually connect securely
    }

    final captures = verify(() => mockRum.startResource(
        captureAny(),
        RumHttpMethod.get,
        'https://127.0.0.1:$port/helloworld.Greeter/SayHello',
        captureAny())).captured;
    final key = captures[0] as String;
    final attributes = captures[1] as Map<String, Object?>;

    expect(attributes['grpc.method'], '/helloworld.Greeter/SayHello');

    verify(
        () => mockRum.stopResourceWithErrorInfo(key, any(), 'GrpcError', {}));

    await channel.shutdown();
    await server.shutdown();
  });
}
