// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:grpc/grpc.dart';
import 'package:uuid/uuid.dart';

/// A client GrpcInterceptor which enables automatic resource tracking and
/// distributed tracing
///
/// Note: This only supports intercepting unary calls. It does not intercept
/// streaming calls.
class DatadogGrpcInterceptor extends ClientInterceptor {
  final Uuid uuid = const Uuid();
  final DatadogSdk _datadog;
  final ClientChannel _channel;

  late String _hostPath;

  DatadogGrpcInterceptor(
    this._datadog,
    this._channel,
  ) {
    final host = _channel.host;
    final scheme = _channel.options.credentials.isSecure ? 'https' : 'http';
    // Add http / https scheme. This scheme is a lie but needed to connect
    // resources to distributed tracing.
    if (host is InternetAddress) {
      _hostPath = '$scheme://${host.host}:${_channel.port}';
    } else {
      if (Uri.parse(host.toString()).scheme.isEmpty) {
        // Add missing scheme
        _hostPath = '$scheme://$host:${_channel.port}';
      } else {
        // Already has scheme
        _hostPath = '$host:${_channel.port}';
      }
    }
  }

  @override
  ResponseFuture<R> interceptUnary<Q, R>(ClientMethod<Q, R> method, Q request,
      CallOptions options, ClientUnaryInvoker<Q, R> invoker) {
    final path = method.path;
    final String fullPath = '$_hostPath$path';

    bool shouldSample = _datadog.rum?.shouldSampleTrace() ?? false;
    bool isFirstPartyHost = _datadog.isFirstPartyHost(Uri.parse(fullPath));
    bool shouldAppendTraces = shouldSample && isFirstPartyHost;

    String? traceId;
    String? parentId;
    if (shouldAppendTraces) {
      traceId = generateTraceId();
      parentId = generateTraceId();
    }

    final rumKey = uuid.v1();
    _datadog.rum?.startResourceLoading(
      rumKey,
      RumHttpMethod.get,
      fullPath,
      {
        "grpc.method": method.path,
        if (shouldAppendTraces) ...{
          DatadogRumPlatformAttributeKey.traceID: traceId,
          DatadogRumPlatformAttributeKey.spanID: parentId
        }
      },
    );

    if (shouldAppendTraces) {
      options = options.mergedWith(CallOptions(metadata: {
        DatadogTracingHeaders.origin: 'rum',
        DatadogTracingHeaders.samplingPriority: '1',
        DatadogTracingHeaders.traceId: traceId!,
        DatadogTracingHeaders.parentId: parentId!,
      }));
    } else if (isFirstPartyHost) {
      options = options.mergedWith(CallOptions(metadata: {
        DatadogTracingHeaders.samplingPriority: '0',
      }));
    }

    final future = invoker(method, request, options);
    future.then((v) {
      _datadog.rum?.stopResourceLoading(rumKey, 200, RumResourceType.native);
    }, onError: (e, st) {
      _datadog.rum?.stopResourceLoadingWithErrorInfo(
          rumKey, e.toString(), e.runtimeType.toString());
    });
    return future;
  }
}
