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

    final rum = _datadog.rum;
    final rumKey = uuid.v1();
    final headerTypes = _datadog.headerTypesForHost(Uri.parse(fullPath));

    var addedHeaders = <String, String>{};

    if (rum != null) {
      var attributes = <String, Object?>{
        'grpc.method': method.path,
      };
      TracingContext? tracingContext;
      bool shouldSample = rum.shouldSampleTrace();
      if (headerTypes.isNotEmpty) {
        tracingContext = generateTracingContext(shouldSample);

        attributes[DatadogRumPlatformAttributeKey.rulePsr] =
            rum.traceSampleRate / 100.0;
        if (tracingContext.sampled) {
          attributes[DatadogRumPlatformAttributeKey.traceID] =
              tracingContext.traceId.asString(TracingIdRepresentation.hex);
          attributes[DatadogRumPlatformAttributeKey.spanID] =
              tracingContext.spanId.asString(TracingIdRepresentation.decimal);
        }

        for (final tracingType in headerTypes) {
          addedHeaders.addAll(getTracingHeaders(tracingContext, tracingType,
              contextInjection: rum.contextInjectionSetting));
        }
      }

      _datadog.rum?.startResource(
        rumKey,
        RumHttpMethod.get,
        fullPath,
        attributes,
      );
    }

    options = options.mergedWith(CallOptions(metadata: addedHeaders));

    final future = invoker(method, request, options);
    future.then((v) {
      _datadog.rum?.stopResource(rumKey, 200, RumResourceType.native);
    }, onError: (Object e, StackTrace? st) {
      _datadog.rum?.stopResourceWithErrorInfo(
          rumKey, e.toString(), e.runtimeType.toString());
    });
    return future;
  }
}
