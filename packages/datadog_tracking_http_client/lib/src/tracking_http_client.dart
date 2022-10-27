// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:uuid/uuid.dart';

/// Overrides to supply the [DatadogTrackingHttpClient] instead of the default
/// HttpClient
///
/// This overrides class is setup automatically on [HttpOverrides.global] if you
/// are using [DatadogSdk.runApp] and have [DdSdkConfiguration.trackHttpClient]
/// set to true.
class DatadogTrackingHttpOverrides extends HttpOverrides {
  final DatadogSdk datadogSdk;

  DatadogTrackingHttpOverrides(this.datadogSdk);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    var innerClient = super.createHttpClient(context);
    return DatadogTrackingHttpClient(datadogSdk, innerClient);
  }
}

/// A wrapper around HttpClient that supports tracking network requests and
/// sending them to Datadog
///
/// If the RUM feature is enabled, the SDK will send information about RUM
/// Resources (calling startLoading, stopLoading, and stopLoadingWithErrorInfo)
/// for all intercepted requests.
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
/// Unlike [DatadogClient], the DatadogTrackingHttpClient is able to override
/// all network operations that use [HttpClient], which includes requests made
/// by Flutter and other popular networking libraries (like http and Dio).
/// However, it is not able to intercept calls made from native packages like
/// `cupertino_http` and `cronet_http`, which should instead use
/// [DatadogClient].
///
/// DatadogTrackingHttpClient and [DatadogClient] can be used together if needed,
/// and will not interfere with each other.
///
/// See also [DatadogClient].
class DatadogTrackingHttpClient implements HttpClient {
  final Uuid uuid = const Uuid();
  final DatadogSdk datadogSdk;
  final HttpClient innerClient;

  DatadogTrackingHttpClient(this.datadogSdk, this.innerClient);

  @override
  Future<HttpClientRequest> open(
      String method, String host, int port, String path) {
    // This implementation is copied from http_impl.dart in dart:io, essentially
    // stripping out the query from the path. All roads eventually lead to
    // _openUrl
    const int hashMark = 0x23;
    const int questionMark = 0x3f;
    int fragmentStart = path.length;
    int queryStart = path.length;
    for (int i = path.length - 1; i >= 0; i--) {
      var char = path.codeUnitAt(i);
      if (char == hashMark) {
        fragmentStart = i;
        queryStart = i;
      } else if (char == questionMark) {
        queryStart = i;
      }
    }
    String? query;
    if (queryStart < fragmentStart) {
      query = path.substring(queryStart + 1, fragmentStart);
      path = path.substring(0, queryStart);
    }
    Uri uri =
        Uri(scheme: 'http', host: host, port: port, path: path, query: query);
    return _openUrl(method, uri);
  }

  Future<HttpClientRequest> _openUrl(String method, Uri url) async {
    final rum = datadogSdk.rum;
    String? rumKey;
    String? traceId, spanId;
    bool isFirstParty = false;

    try {
      isFirstParty = datadogSdk.isFirstPartyHost(url);

      if (rum != null) {
        bool shouldSample = isFirstParty && rum.shouldSampleTrace();
        if (shouldSample) {
          traceId = generateTraceId();
          spanId = generateTraceId();
        }

        final attributes = <String, dynamic>{};
        if (traceId != null) {
          attributes[DatadogRumPlatformAttributeKey.traceID] = traceId;
          attributes[DatadogRumPlatformAttributeKey.spanID] = spanId;
        }
        attributes[DatadogRumPlatformAttributeKey.rulePsr] =
            rum.tracingSamplingRate / 100.0;

        rumKey = uuid.v1();
        final rumHttpMethod = rumMethodFromMethodString(method);
        rum.startResourceLoading(
            rumKey, rumHttpMethod, url.toString(), attributes);
      }
    } catch (e, st) {
      datadogSdk.internalLogger.sendToDatadog(
        '$DatadogTrackingHttpClient encountered an error while attempting '
        ' to track an _openUrl call: $e',
        st,
        e.runtimeType.toString(),
      );
    }

    HttpClientRequest request;
    try {
      request = await innerClient.openUrl(method, url);
      request.headers.add(DatadogTracingHeaders.origin, 'rum');
      if (traceId != null && spanId != null) {
        request.headers.add(DatadogTracingHeaders.traceId, traceId);
        request.headers.add(DatadogTracingHeaders.parentId, spanId);
        request.headers.add(DatadogTracingHeaders.samplingPriority, '1');
      } else if (isFirstParty) {
        request.headers.add(DatadogTracingHeaders.samplingPriority, '0');
      }
    } catch (e) {
      if (rumKey != null) {
        try {
          rum?.stopResourceLoadingWithErrorInfo(
              rumKey, e.toString(), e.runtimeType.toString());
        } catch (innerE, st) {
          datadogSdk.internalLogger.sendToDatadog(
            '$DatadogTrackingHttpClient encountered an error while attempting '
            ' to track an _openUrl error: $e',
            st,
            e.runtimeType.toString(),
          );
        }
      }
      rethrow;
    }

    if (rumKey != null) {
      request = _DatadogTrackingHttpRequest(datadogSdk, request, rumKey);
    }

    return request;
  }

  @override
  set connectionFactory(
          Future<ConnectionTask<Socket>> Function(
                  Uri url, String? proxyHost, int? proxyPort)?
              f) =>
      innerClient.connectionFactory = f;

  @override
  set keyLog(Function(String line)? callback) => innerClient.keyLog = callback;

  @override
  bool get autoUncompress => innerClient.autoUncompress;
  @override
  set autoUncompress(bool value) => innerClient.autoUncompress = value;

  @override
  Duration? get connectionTimeout => innerClient.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) =>
      innerClient.connectionTimeout = value;

  @override
  Duration get idleTimeout => innerClient.idleTimeout;
  @override
  set idleTimeout(Duration value) => innerClient.idleTimeout = value;

  @override
  int? get maxConnectionsPerHost => innerClient.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? value) =>
      innerClient.maxConnectionsPerHost = value;

  @override
  String? get userAgent => innerClient.userAgent;
  @override
  set userAgent(String? value) => innerClient.userAgent = value;

  @override
  void addCredentials(
      Uri url, String realm, HttpClientCredentials credentials) {
    innerClient.addCredentials(url, realm, credentials);
  }

  @override
  void addProxyCredentials(
      String host, int port, String realm, HttpClientCredentials credentials) {
    innerClient.addProxyCredentials(host, port, realm, credentials);
  }

  @override
  set authenticate(
          Future<bool> Function(Uri url, String scheme, String? realm)? f) =>
      innerClient.authenticate = f;

  @override
  set authenticateProxy(
          Future<bool> Function(
                  String host, int port, String scheme, String? realm)?
              f) =>
      innerClient.authenticateProxy = f;

  @override
  set badCertificateCallback(
          bool Function(X509Certificate cert, String host, int port)?
              callback) =>
      innerClient.badCertificateCallback = callback;

  @override
  void close({bool force = false}) {
    innerClient.close(force: force);
  }

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) {
    return innerClient.delete(host, port, path);
  }

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => _openUrl('delete', url);

  @override
  set findProxy(String Function(Uri url)? f) => innerClient.findProxy = f;

  @override
  Future<HttpClientRequest> get(String host, int port, String path) {
    return innerClient.get(host, port, path);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _openUrl('get', url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) {
    return innerClient.head(host, port, path);
  }

  @override
  Future<HttpClientRequest> headUrl(Uri url) => _openUrl('head', url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      _openUrl(method, url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) {
    return innerClient.patch(host, port, path);
  }

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => _openUrl('patch', url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) {
    return innerClient.post(host, port, path);
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) => _openUrl('post', url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) {
    return innerClient.put(host, port, path);
  }

  @override
  Future<HttpClientRequest> putUrl(Uri url) => _openUrl('put', url);
}

class _DatadogTrackingHttpRequest implements HttpClientRequest {
  final DatadogSdk datadogSdk;
  final HttpClientRequest innerContext;
  final String? rumKey;

  _DatadogTrackingHttpRequest(
    this.datadogSdk,
    this.innerContext,
    this.rumKey,
  );

  @override
  Future<HttpClientResponse> get done {
    final innerFuture = innerContext.done;
    return innerFuture.then((value) {
      return _DatadogTrackingHttpResponse(datadogSdk, value, rumKey);
    }, onError: (Object e, StackTrace? st) {
      _onStreamError(e, st);
      throw e;
    });
  }

  @override
  Future<HttpClientResponse> close() {
    return innerContext.close().then((value) {
      return _DatadogTrackingHttpResponse(datadogSdk, value, rumKey);
    }, onError: (Object e, StackTrace? st) async {
      _onStreamError(e, st);
      throw e;
    });
  }

  void _onStreamError(Object e, StackTrace? st) {
    try {
      if (rumKey != null) {
        datadogSdk.rum?.stopResourceLoadingWithErrorInfo(
            rumKey!, e.toString(), e.runtimeType.toString());
      }
    } catch (e, st) {
      datadogSdk.internalLogger.sendToDatadog(
        '$DatadogTrackingHttpClient encountered an error attempting to report a stream error; $e',
        st,
        e.runtimeType.toString(),
      );
    }
  }

  @override
  bool get bufferOutput => innerContext.bufferOutput;
  @override
  set bufferOutput(bool value) => innerContext.bufferOutput = value;

  @override
  int get contentLength => innerContext.contentLength;
  @override
  set contentLength(int value) => innerContext.contentLength = value;

  @override
  Encoding get encoding => innerContext.encoding;
  @override
  set encoding(Encoding value) => innerContext.encoding = value;

  @override
  bool get followRedirects => innerContext.followRedirects;
  @override
  set followRedirects(bool value) => innerContext.followRedirects = value;

  @override
  int get maxRedirects => innerContext.maxRedirects;
  @override
  set maxRedirects(int value) => innerContext.maxRedirects = value;

  @override
  bool get persistentConnection => innerContext.persistentConnection;
  @override
  set persistentConnection(bool value) =>
      innerContext.persistentConnection = value;

  @override
  void abort([Object? exception, StackTrace? stackTrace]) =>
      innerContext.abort(exception, stackTrace);

  @override
  void add(List<int> data) => innerContext.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      innerContext.addError(error, stackTrace);

  @override
  Future addStream(Stream<List<int>> stream) => innerContext.addStream(stream);

  @override
  HttpConnectionInfo? get connectionInfo => innerContext.connectionInfo;

  @override
  List<Cookie> get cookies => innerContext.cookies;

  @override
  Future flush() => innerContext.flush();

  @override
  HttpHeaders get headers => innerContext.headers;

  @override
  String get method => innerContext.method;

  @override
  Uri get uri => innerContext.uri;

  @override
  void write(Object? object) => innerContext.write(object);

  @override
  void writeAll(Iterable objects, [String separator = '']) =>
      innerContext.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => innerContext.writeCharCode(charCode);

  @override
  void writeln([Object? object = '']) => innerContext.writeln(object);
}

class _DatadogTrackingHttpResponse extends Stream<List<int>>
    implements HttpClientResponse {
  final DatadogSdk datadogSdk;
  final HttpClientResponse innerResponse;
  final String? rumKey;
  Object? lastError;

  _DatadogTrackingHttpResponse(
    this.datadogSdk,
    this.innerResponse,
    this.rumKey,
  );

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return innerResponse.listen(
      onData,
      cancelOnError: cancelOnError,
      onError: (Object e, StackTrace? st) {
        _onError(e, st);
        if (onError == null) {
          return;
        }
        if (onError is void Function(Object, StackTrace?)) {
          onError(e, st);
        } else {
          assert(onError is void Function(Object));
          onError(e);
        }
      },
      onDone: () {
        _onFinish();
        if (onDone != null) {
          onDone();
        }
      },
    );
  }

  // Set an error if one occurs during the stream. Note that only the last
  // error will be sent.
  void _onError(Object error, StackTrace? stackTrace) {
    lastError = error;
    datadogSdk.rum?.stopResourceLoadingWithErrorInfo(
        rumKey!, lastError.toString(), lastError.runtimeType.toString());
  }

  void _onFinish() {
    try {
      final statusCode = innerResponse.statusCode;

      if (rumKey != null) {
        // Error'd streams are already closed
        if (lastError == null) {
          var resourceType = resourceTypeFromContentType(headers.contentType);
          var size = innerResponse.contentLength > 0
              ? innerResponse.contentLength
              : null;
          datadogSdk.rum
              ?.stopResourceLoading(rumKey!, statusCode, resourceType, size);
        }
      }
    } catch (e, st) {
      datadogSdk.internalLogger.sendToDatadog(
        '$DatadogTrackingHttpClient encountered an error while attempting '
        ' to finish a resource: $e',
        st,
        e.runtimeType.toString(),
      );
    }
  }

  @override
  X509Certificate? get certificate => innerResponse.certificate;

  @override
  HttpClientResponseCompressionState get compressionState =>
      innerResponse.compressionState;

  @override
  HttpConnectionInfo? get connectionInfo => innerResponse.connectionInfo;

  @override
  int get contentLength => innerResponse.contentLength;

  @override
  List<Cookie> get cookies => innerResponse.cookies;

  @override
  Future<Socket> detachSocket() {
    return innerResponse.detachSocket();
  }

  @override
  HttpHeaders get headers => innerResponse.headers;

  @override
  bool get isRedirect => innerResponse.isRedirect;

  @override
  bool get persistentConnection => innerResponse.persistentConnection;

  @override
  String get reasonPhrase => innerResponse.reasonPhrase;

  @override
  Future<HttpClientResponse> redirect(
      [String? method, Uri? url, bool? followLoops]) {
    return innerResponse.redirect(method, url, followLoops);
  }

  @override
  List<RedirectInfo> get redirects => innerResponse.redirects;

  @override
  int get statusCode => innerResponse.statusCode;
}
