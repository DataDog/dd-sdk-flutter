// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../datadog_sdk.dart';

///
///
class DatadogTrackingHttpClient implements HttpClient {
  final Uuid uuid = const Uuid();
  final DatadogSdk datadogSdk;
  final HttpClient innerClient;

  DatadogTrackingHttpClient(this.datadogSdk, this.innerClient);

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
  Future<HttpClientRequest> open(
      String method, String host, int port, String path) {
    return innerClient.open(method, host, port, path);
  }

  @override
  void close({bool force = false}) {
    innerClient.close(force: force);
  }

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) {
    return innerClient.deleteUrl(url);
  }

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) {
    return innerClient.delete(host, port, path);
  }

  @override
  set findProxy(String Function(Uri url)? f) => innerClient.findProxy = f;

  @override
  Future<HttpClientRequest> get(String host, int port, String path) {
    return innerClient.get(host, port, path);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    return innerClient.getUrl(url);
  }

  @override
  Future<HttpClientRequest> head(String host, int port, String path) {
    return innerClient.head(host, port, path);
  }

  @override
  Future<HttpClientRequest> headUrl(Uri url) {
    return innerClient.headUrl(url);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    var request = await innerClient.openUrl(method, url);
    if (datadogSdk.traces != null || datadogSdk.rum != null) {
      DdSpan? tracingContext;
      String? rumKey;
      if (datadogSdk.traces != null && datadogSdk.isFirstPartyHost(url)) {
        tracingContext = await datadogSdk.traces!.startSpan(
            'flutter.http_client',
            tags: {'http.method': method, 'http.url': url.toString()});
        var headers =
            await datadogSdk.traces!.getTracePropagationHeaders(tracingContext);
        for (var header in headers.entries) {
          request.headers.add(header.key, header.value);
        }
      }

      if (datadogSdk.rum != null) {
        rumKey = uuid.v1();
        await datadogSdk.rum
            ?.startResourceLoading(rumKey, RumHttpMethod.get, url.toString());
      }

      // Wrap to return a tracking response
      request = _DatadogTrackingHttpRequest(
          datadogSdk, request, tracingContext, rumKey);
    }

    return request;
  }

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) {
    return innerClient.patch(host, port, path);
  }

  @override
  Future<HttpClientRequest> patchUrl(Uri url) {
    return innerClient.patchUrl(url);
  }

  @override
  Future<HttpClientRequest> post(String host, int port, String path) {
    return innerClient.post(host, port, path);
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) {
    return innerClient.postUrl(url);
  }

  @override
  Future<HttpClientRequest> put(String host, int port, String path) {
    return innerClient.put(host, port, path);
  }

  @override
  Future<HttpClientRequest> putUrl(Uri url) {
    return innerClient.putUrl(url);
  }
}

class _DatadogTrackingHttpRequest implements HttpClientRequest {
  final DatadogSdk datadogSdk;
  final HttpClientRequest innerContext;
  final DdSpan? tracingContext;
  final String? rumKey;

  _DatadogTrackingHttpRequest(
    this.datadogSdk,
    this.innerContext,
    this.tracingContext,
    this.rumKey,
  );

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
  Future<HttpClientResponse> close() => done;

  @override
  HttpConnectionInfo? get connectionInfo => innerContext.connectionInfo;

  @override
  List<Cookie> get cookies => innerContext.cookies;

  @override
  Future<HttpClientResponse> get done {
    return innerContext.done.then((value) {
      return _DatadogTrackingHttpResponse(
          datadogSdk, value, tracingContext, rumKey);
    });
  }

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
  final DdSpan? tracingContext;
  final String? rumKey;

  _DatadogTrackingHttpResponse(
    this.datadogSdk,
    this.innerResponse,
    this.tracingContext,
    this.rumKey,
  );

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
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return innerResponse.listen(
      onData,
      cancelOnError: cancelOnError,
      onError: (e, st) {
        if (onError == null) {
          return;
        }
        if (onError is void Function(Object, StackTrace)) {
          onError(e, st);
        } else {
          assert(onError is void Function(Object));
          onError(e);
        }
      },
      onDone: () async {
        if (rumKey != null) {
          await datadogSdk.rum
              ?.stopResourceLoading(rumKey!, statusCode, RumResourceType.image);
        }
        await tracingContext?.finish();
        if (onDone != null) {
          onDone();
        }
      },
    );
  }

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
