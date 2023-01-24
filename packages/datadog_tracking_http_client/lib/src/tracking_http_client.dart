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

import 'tracking_http_client_plugin.dart';

/// Overrides to supply the [DatadogTrackingHttpClient] instead of the default
/// HttpClient
///
/// This overrides class is setup automatically on [HttpOverrides.global] if you
/// are using [DatadogSdk.runApp] and have [DdSdkConfiguration.trackHttpClient]
/// set to true.
class DatadogTrackingHttpOverrides extends HttpOverrides {
  final DatadogSdk datadogSdk;
  final DdHttpTrackingPluginConfiguration configuration;

  DatadogTrackingHttpOverrides(this.datadogSdk, this.configuration);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    var innerClient = super.createHttpClient(context);
    return DatadogTrackingHttpClient(datadogSdk, configuration, innerClient);
  }
}

/// A wrapper around HttpClient that supports tracking network requests and
/// sending them to Datadog
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
/// Spans sent), see [DdSdkConfiguration.firstPartyHostsWithTracingHeaders].
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
  final DdHttpTrackingPluginConfiguration configuration;
  final HttpClient innerClient;

  DatadogTrackingHttpClient(
    this.datadogSdk,
    this.configuration,
    this.innerClient,
  );

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
    String? rumKey;
    final rum = datadogSdk.rum;

    if (rum != null) {
      try {
        rumKey = uuid.v1();
        final rumHttpMethod = rumMethodFromMethodString(method);
        rum.startResourceLoading(rumKey, rumHttpMethod, url.toString());
      } catch (e, st) {
        datadogSdk.internalLogger.sendToDatadog(
          '$DatadogTrackingHttpClient encountered an error while attempting '
          ' to track an _openUrl call: $e',
          st,
          e.runtimeType.toString(),
        );
      }
    }

    HttpClientRequest request;
    try {
      request = await innerClient.openUrl(method, url);
      request = _DatadogTrackingHttpRequest(this, request, rumKey);
    } catch (e) {
      if (rum != null) {
        rum.stopResourceLoadingWithErrorInfo(
            rumKey!, e.toString(), e.runtimeType.toString());
      }
      rethrow;
    }

    return request;
  }

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
  Future<HttpClientRequest> get(String host, int port, String path) =>
      open('get', host, port, path);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _openUrl('get', url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      open('head', host, port, path);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => _openUrl('head', url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      _openUrl(method, url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      open('patch', host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => _openUrl('patch', url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      open('post', host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => _openUrl('post', url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      open('post', host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => _openUrl('put', url);
}

class _DatadogTrackingHttpRequest implements HttpClientRequest {
  final DatadogTrackingHttpClient client;
  final HttpClientRequest innerContext;
  final String? rumKey;

  TracingContext? _tracingContext;
  bool _headersInjected = false;

  _DatadogTrackingHttpRequest(this.client, this.innerContext, this.rumKey) {
    // Don't bother trying to inject headers if we don't have a rum key
    _headersInjected = rumKey == null;
  }

  @override
  Future<HttpClientResponse> get done {
    _injectHeaders();

    final innerFuture = innerContext.done;
    return innerFuture.then((value) {
      return _DatadogTrackingHttpResponse(
          client.datadogSdk, value, rumKey, _tracingContext);
    }, onError: (Object e, StackTrace? st) {
      _onStreamError(e, st);
      throw e;
    });
  }

  @override
  Future<HttpClientResponse> close() {
    _injectHeaders();

    return innerContext.close().then((value) {
      return _DatadogTrackingHttpResponse(
          client.datadogSdk, value, rumKey, _tracingContext);
    }, onError: (Object e, StackTrace? st) async {
      _onStreamError(e, st);
      throw e;
    });
  }

  void _injectHeaders() {
    if (_headersInjected) return;

    // Regardless of the outcome here, don't try to track again.
    _headersInjected = true;

    final rum = client.datadogSdk.rum;
    try {
      final tracingHeaderTypes =
          client.datadogSdk.headerTypesForHost(innerContext.uri);

      if (rum != null && tracingHeaderTypes.isNotEmpty) {
        bool shouldSample = rum.shouldSampleTrace();

        // No tracing context, generate one ourselves
        _tracingContext ??= generateTracingContext(shouldSample);

        for (final headerType in tracingHeaderTypes) {
          final newHeaders = getTracingHeaders(_tracingContext!, headerType);
          for (final entry in newHeaders.entries) {
            // Don't replace exiting headers
            if (headers.value(entry.key) == null) {
              headers.add(entry.key, entry.value);
            }
          }
        }
      }
    } catch (e, st) {
      client.datadogSdk.internalLogger.sendToDatadog(
        '$DatadogTrackingHttpClient encountered an error while attempting '
        ' to track an _openUrl call: $e',
        st,
        e.runtimeType.toString(),
      );
    }
  }

  void _onStreamError(Object e, StackTrace? st) {
    try {
      final rum = client.datadogSdk.rum;
      if (rumKey != null && rum != null) {
        final attributes = generateDatadogAttributes(
          _tracingContext,
          rum.tracingSamplingRate,
        );
        rum.stopResourceLoadingWithErrorInfo(
            rumKey!, e.toString(), e.runtimeType.toString(), attributes);
      }
    } catch (e, st) {
      client.datadogSdk.internalLogger.sendToDatadog(
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
  Future addStream(Stream<List<int>> stream) {
    _injectHeaders();

    return innerContext.addStream(stream);
  }

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
  void write(Object? object) {
    _injectHeaders();

    innerContext.write(object);
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    _injectHeaders();

    innerContext.writeAll(objects, separator);
  }

  @override
  void writeCharCode(int charCode) {
    _injectHeaders();

    innerContext.writeCharCode(charCode);
  }

  @override
  void writeln([Object? object = '']) {
    _injectHeaders();

    innerContext.writeln(object);
  }
}

class _DatadogTrackingHttpResponse extends Stream<List<int>>
    implements HttpClientResponse {
  final DatadogSdk datadogSdk;
  final HttpClientResponse innerResponse;
  final String? rumKey;
  final TracingContext? tracingContext;
  Object? lastError;

  _DatadogTrackingHttpResponse(
    this.datadogSdk,
    this.innerResponse,
    this.rumKey,
    this.tracingContext,
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
    final rum = datadogSdk.rum;
    if (rumKey != null && rum != null) {
      final attributes = generateDatadogAttributes(
        tracingContext,
        rum.tracingSamplingRate,
      );
      rum.stopResourceLoadingWithErrorInfo(rumKey!, lastError.toString(),
          lastError.runtimeType.toString(), attributes);
    }
  }

  void _onFinish() {
    try {
      final statusCode = innerResponse.statusCode;

      final rum = datadogSdk.rum;
      if (rumKey != null && rum != null) {
        // Error'd streams are already closed
        if (lastError == null) {
          var resourceType = resourceTypeFromContentType(headers.contentType);
          var size = innerResponse.contentLength > 0
              ? innerResponse.contentLength
              : null;
          final attributes = generateDatadogAttributes(
              tracingContext, rum.tracingSamplingRate);
          rum.stopResourceLoading(
              rumKey!, statusCode, resourceType, size, attributes);
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
