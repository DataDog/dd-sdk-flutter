// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:io';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// A composable client for use with the `http` package that supports tracking
/// network requests and sending them to Datadog.
///
/// If the RUM feature is enabled, the SDK will send information about RUM
/// Resources (calling startResourceLoading, stopResourceLoading, and
/// stopResourceLoadingWithErrorInfo) for all intercepted requests.
///
/// The SDK will also create a tracing Span for each 1st-party request, and add
/// extra HTTP headers to further propagate the trace. The percentage of
/// resources traced in this way is determined by
/// [RumConfiguration.tracingSamplingRate].
///
/// To specify which hosts are 1st party (and therefore should have tracing
/// Spans sent), see [DdSdkConfiguration.firstPartyHosts]. You can also set
/// first party hosts after initialization setting [DatadogSdk.firstPartyHosts]
///
/// DatadogClient only modifies calls made through itself, unlike
/// [DatadogTrackingHttpClient], which overrides all calls made by [HttpClient]
/// and includes network calls made by Flutter. However, DatadogClient allows
/// you to compose with other [http.BaseClient] based libraries like
/// `cupertino_http` and `cronet_http`, which [DatadogTrackingHttpClient] would
/// miss.
///
/// DatadogClient and [DatadogTrackingHttpClient] can be used together if
/// needed, and will not interfere with each other.
///
/// See also [DatadogTrackingHttpClient]
class DatadogClient extends http.BaseClient {
  final DatadogSdk datadogSdk;
  final Uuid _uuid = const Uuid();
  final http.Client _innerClient;

  DatadogClient({
    required this.datadogSdk,
    http.Client? innerClient,
  }) : _innerClient = innerClient ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final rum = datadogSdk.rum;
    // Never track on web
    if (kIsWeb || rum == null) {
      return _innerClient.send(request);
    }

    return _trackingSend(request, rum);
  }

  Future<http.StreamedResponse> _trackingSend(
      http.BaseRequest request, DdRum rum) async {
    String? rumKey;
    bool isFirstParty = false;

    try {
      isFirstParty = datadogSdk.isFirstPartyHost(request.url);
      rumKey = _uuid.v1();
      bool shouldSample = isFirstParty && rum.shouldSampleTrace();
      final attributes =
          _appendRequestHeaders(request, rumKey, isFirstParty, shouldSample);

      final rumHttpMethod = rumMethodFromMethodString(request.method);
      rum.startResourceLoading(
          rumKey, rumHttpMethod, request.url.toString(), attributes);
    } catch (e, st) {
      datadogSdk.internalLogger.sendToDatadog(
        '$DatadogClient encountered an error while attempting '
        ' to track a send call: $e',
        st,
        e.runtimeType.toString(),
      );
      // Since there was an error, don't attempt any more tracking
      rumKey = null;
    }

    http.StreamedResponse response;
    try {
      response = await _innerClient.send(request);
    } catch (e) {
      if (rumKey != null) {
        try {
          rum.stopResourceLoadingWithErrorInfo(
              rumKey, e.toString(), e.runtimeType.toString());
        } catch (innerE, st) {
          datadogSdk.internalLogger.sendToDatadog(
            '$DatadogClient encountered an error while attempting '
            ' to track a send - error: $e',
            st,
            e.runtimeType.toString(),
          );
          rumKey = null;
        }
      }

      rethrow;
    }

    if (rumKey != null) {
      try {
        // Copy the response so we can spy on the stream.
        final spyStream = StreamController<List<int>>();

        Object? firstError;

        response.stream.listen(
          spyStream.sink.add,
          onError: (Object e, StackTrace? st) {
            if (firstError == null) {
              firstError = e;
              rum.stopResourceLoadingWithErrorInfo(rumKey!,
                  firstError.toString(), firstError.runtimeType.toString());
            }
            spyStream.addError(e, st);
          },
          onDone: () {
            if (rumKey != null) {
              _onFinish(rum, rumKey, response, firstError);
            }
            spyStream.close();
          },
        );

        response = http.StreamedResponse(
          spyStream.stream,
          response.statusCode,
          contentLength: response.contentLength,
          request: response.request,
          headers: response.headers,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
          reasonPhrase: response.reasonPhrase,
        );
      } catch (e, st) {
        datadogSdk.internalLogger.sendToDatadog(
          '$DatadogClient encountered an error while attempting '
          ' to spy on a response stream: $e',
          st,
          e.runtimeType.toString(),
        );
      }
    }

    return response;
  }

  void _onFinish(
      DdRum rum, String rumKey, http.StreamedResponse response, Object? error) {
    try {
      // If we saw an error, this resource has already been stopped
      if (error == null) {
        final contentTypeHeader =
            response.headers[HttpHeaders.contentTypeHeader];
        final contentType = contentTypeHeader != null
            ? ContentType.parse(contentTypeHeader)
            : ContentType.text;
        var resourceType = resourceTypeFromContentType(contentType);
        datadogSdk.rum?.stopResourceLoading(
            rumKey, response.statusCode, resourceType, response.contentLength);
      }
    } catch (e, st) {
      datadogSdk.internalLogger.sendToDatadog(
        '$DatadogClient encountered an error while attempting '
        ' to finish a resource: $e',
        st,
        e.runtimeType.toString(),
      );
    }
  }

  Map<String, Object?> _appendRequestHeaders(http.BaseRequest request,
      String rumKey, bool isFirstParty, bool shouldSample) {
    request.headers[DatadogTracingHeaders.origin] = 'rum';

    String? traceId, spanId;
    if (shouldSample) {
      traceId = generateTraceId();
      spanId = generateTraceId();
    }

    final attributes = <String, Object?>{};
    if (traceId != null && spanId != null) {
      attributes[DatadogRumPlatformAttributeKey.traceID] = traceId;
      attributes[DatadogRumPlatformAttributeKey.spanID] = spanId;

      request.headers[DatadogTracingHeaders.traceId] = traceId;
      request.headers[DatadogTracingHeaders.parentId] = spanId;
      request.headers[DatadogTracingHeaders.samplingPriority] = '1';
    } else if (isFirstParty) {
      request.headers[DatadogTracingHeaders.samplingPriority] = '0';
    }

    return attributes;
  }
}
