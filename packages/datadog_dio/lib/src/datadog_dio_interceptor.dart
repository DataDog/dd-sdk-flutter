// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

// ignore_for_file: invalid_use_of_internal_member

import 'dart:convert';
import 'dart:io';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../datadog_dio.dart';

/// An interceptor that forwards information about Dio requests to Datadog,
/// including enabling distributed tracing for hosts specified in
/// [DatadogConfiguration.firstPartyHosts].
class DatadogDioInterceptor extends Interceptor {
  @visibleForTesting
  static const String datadogRumExtraKey = '__datadog_rum_key';

  final DatadogSdk datadogSdk;
  final List<RegExp> ignoreUrlPatterns;
  final DatadogDioAttributeProvider? attributesProvider;

  final Uuid _uuid = const Uuid();

  DatadogDioInterceptor({
    required this.datadogSdk,
    this.ignoreUrlPatterns = const [],
    this.attributesProvider,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final rum = datadogSdk.rum;
    if (!kIsWeb && rum != null) {
      _trackRequest(options, rum);
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    final rum = datadogSdk.rum;
    final rumKey = response.requestOptions.extra[datadogRumExtraKey];
    if (!kIsWeb && rum != null && rumKey is String) {
      try {
        _stopWithResponse(rum, rumKey, response);
      } catch (e, st) {
        datadogSdk.internalLogger.sendToDatadog(
          '$DatadogDioInterceptor encountered an error while attempting'
          ' to track a request: $e',
          st,
          e.runtimeType.toString(),
        );
      }
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final rum = datadogSdk.rum;
    final rumKey = err.requestOptions.extra[datadogRumExtraKey];
    if (!kIsWeb && rum != null && rumKey is String) {
      try {
        if (err.type == DioExceptionType.badResponse &&
            err.response?.statusCode != null) {
          // Response completed successfully, but Dio throws an exception for
          // certain status codes if ValidateStatus is configured. This breaks
          // distributed tracing, so we stop our resource properly instead of
          // adding it as an error.
          _stopWithResponse(rum, rumKey, err.response!);
        } else {
          final attributes = attributesProvider?.onError(err) ?? {};
          rum.stopResourceWithErrorInfo(
              rumKey, err.toString(), err.type.toString(), attributes);
        }
      } catch (e, st) {
        datadogSdk.internalLogger.sendToDatadog(
          '$DatadogDioInterceptor encountered an error while attempting'
          ' to track a request: $e',
          st,
          e.runtimeType.toString(),
        );
      }
    }
    super.onError(err, handler);
  }

  /// Returns byte length of response body when already in memory (e.g. chunked response).
  static int? _responseDataByteLength(dynamic data) {
    if (data is List<int>) {
      return data.length;
    }
    if (data is Uint8List) {
      return data.length;
    }
    if (data is String) {
      return utf8.encode(data).length;
    }
    return null;
  }

  void _stopWithResponse(
      DatadogRum rum, String rumKey, Response<dynamic> response) {
    final contentTypeHeader =
        response.headers[Headers.contentTypeHeader]?.firstOrNull;
    final contentType = contentTypeHeader != null
        ? ContentType.parse(contentTypeHeader)
        : ContentType.text;
    final resourceType = resourceTypeFromContentType(contentType);
    int? contentLength;
    final contentLengthHeader =
        response.headers[Headers.contentLengthHeader]?.firstOrNull;
    if (contentLengthHeader != null) {
      contentLength = int.tryParse(contentLengthHeader);
    }
    // Chunked/streamed responses may omit Content-Length; use response body size when available
    if (contentLength == null && response.data != null) {
      contentLength = _responseDataByteLength(response.data);
    }
    var attributes =
        attributesProvider?.onResponse(response) ?? <String, Object?>{};
    final extractor = rum.resourceHeadersExtractor;
    if (extractor != null) {
      final requestHeaders = response.requestOptions.headers.map((k, v) {
        if (v is Iterable) {
          return MapEntry(k, v.map((e) => e.toString()).toList());
        }
        return MapEntry(k, [v.toString()]);
      });
      final headerAttrs = extractor.toResourceAttributes(
        requestHeaders,
        response.headers.map,
      );
      attributes = {...attributes, ...headerAttrs};
    }
    rum.stopResource(
      rumKey,
      response.statusCode,
      resourceType,
      contentLength,
      attributes,
    );
  }

  void _trackRequest(RequestOptions options, DatadogRum rum) {
    String? rumKey;
    if (_shouldTrackRequest(options)) {
      try {
        final tracingHeaders = datadogSdk.headerTypesForHost(options.uri);
        final rumHttpMethod = rumMethodFromMethodString(options.method);
        var attributes = <String, Object?>{};
        // Is first party?
        if (tracingHeaders.isNotEmpty) {
          var context = generateTracingContext(datadogSdk, rum);

          attributes = _appendRequestHeaders(
            options,
            context,
            tracingHeaders,
            rum.contextInjectionSetting,
          );
        }

        if (attributesProvider != null) {
          final userAttributes = attributesProvider?.onRequest(options);
          attributes.merge(userAttributes);
        }

        rumKey = _uuid.v1();
        options.extra[datadogRumExtraKey] = rumKey;
        rum.startResource(
            rumKey, rumHttpMethod, options.uri.toString(), attributes);
      } catch (e, st) {
        datadogSdk.internalLogger.sendToDatadog(
          '$DatadogDioInterceptor encountered an error while attempting'
          ' to track a request: $e',
          st,
          e.runtimeType.toString(),
        );
        // Since there was an error, don't attempt any more tracking
        rumKey = null;
      }
    }
  }

  bool _shouldTrackRequest(RequestOptions options) {
    final url = options.uri.toString();
    for (final pattern in ignoreUrlPatterns) {
      if (pattern.hasMatch(url)) {
        return false;
      }
    }
    return true;
  }

  Map<String, Object?> _appendRequestHeaders(
    RequestOptions requestOptions,
    TracingContext context,
    Set<TracingHeaderType> tracingHeaderTypes,
    TraceContextInjection contextInjection,
  ) {
    var attributes = <String, Object?>{};

    if (tracingHeaderTypes.isNotEmpty) {
      attributes = generateDatadogAttributes(
          context, datadogSdk.rum?.traceSampleRate ?? 0);

      for (final headerType in tracingHeaderTypes) {
        injectTracingHeaders(context, headerType, requestOptions.headers,
            contextInjection: contextInjection);
      }
    }

    return attributes;
  }
}

extension MergeExtension<K, V> on Map<K, V> {
  // Merge "other" onto this map, overwritting any values in the current map
  // with its new value.
  void merge(Map<K, V>? other) {
    if (other == null) return;

    for (final entry in other.entries) {
      this[entry.key] = entry.value;
    }
  }
}
