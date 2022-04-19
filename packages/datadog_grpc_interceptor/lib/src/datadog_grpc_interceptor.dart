// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_grpc_interceptor/src/tracing_util.dart';
import 'package:grpc/grpc.dart';
import 'package:uuid/uuid.dart';

class DatadogTracingHeaders {
  static const traceId = 'x-datadog-trace-id';
  static const parentId = 'x-datadog-parent-id';

  static const sampled = 'x-datadog-sampled';
  static const samplingPriority = 'x-datadog-sampling-priority';
  static const origin = 'x-datadog-origin';
}

// TODO: These are defined in the main datadog_flutter_plugin package but aren't
// public. Probably want to fix that.
class DatadogPlatformAttributeKey {
  /// Trace ID. Used in RUM resources created by automatic resource tracking.
  /// Expects `String` value.
  static const traceID = '_dd.trace_id';

  /// Span ID. Used in RUM resources created by automatic resource tracking.
  /// Expects `String` value.
  static const spanID = '_dd.span_id';
}

/// A client GrpcInterceptor which enables automatic resource tracking and
/// distributed tracing
///
/// Note: only support Unary interception, not streaming interception
class DatadogGrpcInterceptor extends ClientInterceptor {
  final Uuid uuid = const Uuid();
  final DatadogSdk _datadog;

  DatadogGrpcInterceptor(this._datadog);

  @override
  ResponseFuture<R> interceptUnary<Q, R>(ClientMethod<Q, R> method, Q request,
      CallOptions options, ClientUnaryInvoker<Q, R> invoker) {
    String? traceId;
    String? parentId;
    if (_datadog.traces != null) {
      traceId = generateTraceId();
      parentId = generateTraceId();
    }

    final rumKey = uuid.v1();
    _datadog.rum?.startResourceLoading(
      rumKey,
      RumHttpMethod.get,
      method.path,
      {
        "grpc.method": method.path,
        if (_datadog.traces != null) ...{
          DatadogPlatformAttributeKey.traceID: traceId,
          DatadogPlatformAttributeKey.spanID: parentId
        }
      },
    );

    if (_datadog.traces != null) {
      options = options.mergedWith(CallOptions(metadata: {
        DatadogTracingHeaders.origin: 'rum',
        DatadogTracingHeaders.samplingPriority: '1',
        DatadogTracingHeaders.traceId: traceId!,
        DatadogTracingHeaders.parentId: parentId!,
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
