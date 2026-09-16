// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show parseHttpDate;

const _initialRetryBackoff = Duration(milliseconds: 100);
const _maxRetryBackoff = Duration(seconds: 30);
const _maxRetryAfter = Duration(seconds: 30);
const _maxRetries = 10;

/// Wraps [inner] with a timeout for each assignment request attempt.
///
/// The timeout includes receiving the complete response body. A [timeout] of
/// [Duration.zero] returns [inner] unchanged and applies no timeout. Closing
/// the returned client closes [inner]. This wrapper is intentionally scoped to
/// Datadog assignment requests and accepts the [http.Request] subtype created
/// by the SDK.
http.Client withAssignmentRequestTimeout(
  http.Client inner,
  Duration timeout,
) {
  if (timeout.isNegative) {
    throw ArgumentError.value(timeout, 'timeout', 'must not be negative');
  }
  if (timeout == Duration.zero) {
    return inner;
  }
  return _AssignmentRequestTimeoutClient(inner, timeout);
}

/// Wraps [inner] with retries for transient assignment request failures.
///
/// [retries] is the number of retries after the first attempt and must be
/// between zero and ten. Transport errors, timeouts, HTTP 408, and HTTP 5xx
/// responses are retried. HTTP 429 and caller cancellation are not retried.
/// Closing the returned client closes [inner]. This wrapper is intentionally
/// scoped to Datadog assignment requests and accepts the [http.Request]
/// subtype created by the SDK.
http.Client withAssignmentRequestRetry(
  http.Client inner,
  int retries,
) {
  return buildAssignmentRequestClient(
    inner,
    timeout: Duration.zero,
    retries: retries,
  );
}

/// Builds the assignment request policy used by the public wrappers and SDK.
///
/// The dependency hooks keep retry timing deterministic in unit tests. This
/// function lives under `src/` and is not part of the package's public API.
http.Client buildAssignmentRequestClient(
  http.Client inner, {
  required Duration timeout,
  required int retries,
  Future<void> Function(Duration)? delay,
  double Function()? randomDouble,
  DateTime Function()? dateProvider,
}) {
  if (timeout.isNegative) {
    throw ArgumentError.value(timeout, 'timeout', 'must not be negative');
  }
  if (retries < 0 || retries > _maxRetries) {
    throw RangeError.range(retries, 0, _maxRetries, 'retries');
  }

  final timedClient = withAssignmentRequestTimeout(inner, timeout);
  if (retries == 0) {
    return timedClient;
  }
  return _AssignmentRequestRetryClient(
    timedClient,
    retries: retries,
    delay: delay ?? _defaultDelay,
    randomDouble: randomDouble ?? Random().nextDouble,
    dateProvider: dateProvider ?? DateTime.now,
  );
}

final class _AssignmentRequestTimeoutClient extends http.BaseClient {
  final http.Client _inner;
  final Duration _timeout;

  _AssignmentRequestTimeoutClient(this._inner, this._timeout);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final replayable = await _ReplayableRequest.from(request);
    final timeoutAbort = Completer<void>();
    final timeoutResult = Completer<http.StreamedResponse>();
    var timedOut = false;
    final timer = Timer(_timeout, () {
      timedOut = true;
      if (!timeoutAbort.isCompleted) {
        timeoutAbort.complete();
      }
      if (!timeoutResult.isCompleted) {
        timeoutResult.completeError(
          TimeoutException(
            'The assignment request timed out after '
            '${_timeout.inMilliseconds} ms.',
            _timeout,
          ),
        );
      }
    });

    final operation = () async {
      try {
        final response = await _inner.send(
          replayable.create(additionalAbortTrigger: timeoutAbort.future),
        );
        return await _bufferResponse(response);
      } on http.RequestAbortedException {
        if (timedOut) {
          throw TimeoutException(
            'The assignment request timed out after '
            '${_timeout.inMilliseconds} ms.',
            _timeout,
          );
        }
        rethrow;
      }
    }();

    try {
      return await Future.any([
        operation,
        timeoutResult.future,
        if (replayable.abortTrigger != null)
          _abortAsError<http.StreamedResponse>(
            replayable.abortTrigger!,
            request.url,
          ),
      ]);
    } finally {
      timer.cancel();
    }
  }

  @override
  void close() => _inner.close();
}

final class _AssignmentRequestRetryClient extends http.BaseClient {
  final http.Client _inner;
  final int _retries;
  final Future<void> Function(Duration) _delay;
  final double Function() _randomDouble;
  final DateTime Function() _dateProvider;

  _AssignmentRequestRetryClient(
    this._inner, {
    required int retries,
    required Future<void> Function(Duration) delay,
    required double Function() randomDouble,
    required DateTime Function() dateProvider,
  })  : _retries = retries,
        _delay = delay,
        _randomDouble = randomDouble,
        _dateProvider = dateProvider;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final replayable = await _ReplayableRequest.from(request);
    var callerAborted = false;
    final callerAbort = replayable.abortTrigger;
    if (callerAbort != null) {
      unawaited(
        callerAbort.then<void>(
          (_) => callerAborted = true,
          onError: (Object _, StackTrace __) {
            // Abort triggers must not fail according to package:http's
            // contract. Treat a broken trigger as cancellation without
            // leaking an unhandled asynchronous error.
            callerAborted = true;
          },
        ),
      );
    }

    for (var attempt = 0; attempt <= _retries; attempt++) {
      if (callerAborted) {
        throw http.RequestAbortedException(request.url);
      }

      http.StreamedResponse response;
      try {
        response = await _bufferResponse(
          await _inner.send(replayable.create()),
        );
      } catch (error) {
        if (callerAborted || !_isRetryableError(error) || attempt == _retries) {
          rethrow;
        }
        await _waitForRetry(
          _retryBackoff(attempt, _randomDouble()),
          callerAbort,
          request.url,
          _delay,
        );
        continue;
      }

      if (!_isRetryableStatus(response.statusCode) ||
          attempt == _retries ||
          callerAborted) {
        return response;
      }

      final retryAfter = _retryAfter(response, _dateProvider());
      if (retryAfter != null && retryAfter > _maxRetryAfter) {
        return response;
      }
      await _waitForRetry(
        (retryAfter ?? Duration.zero) + _retryBackoff(attempt, _randomDouble()),
        callerAbort,
        request.url,
        _delay,
      );
    }

    throw StateError('Assignment request retry loop completed unexpectedly.');
  }

  @override
  void close() => _inner.close();
}

final class _ReplayableRequest {
  final String method;
  final Uri url;
  final Map<String, String> headers;
  final List<int> bodyBytes;
  final bool followRedirects;
  final int maxRedirects;
  final bool persistentConnection;
  final Future<void>? abortTrigger;

  const _ReplayableRequest({
    required this.method,
    required this.url,
    required this.headers,
    required this.bodyBytes,
    required this.followRedirects,
    required this.maxRedirects,
    required this.persistentConnection,
    required this.abortTrigger,
  });

  static Future<_ReplayableRequest> from(http.BaseRequest request) async {
    if (request is! http.Request) {
      throw ArgumentError.value(
        request,
        'request',
        'assignment request clients support http.Request only',
      );
    }
    return _ReplayableRequest(
      method: request.method,
      url: request.url,
      headers: Map.of(request.headers),
      bodyBytes: await request.finalize().toBytes(),
      followRedirects: request.followRedirects,
      maxRedirects: request.maxRedirects,
      persistentConnection: request.persistentConnection,
      abortTrigger: request is http.Abortable
          ? (request as http.Abortable).abortTrigger
          : null,
    );
  }

  http.BaseRequest create({Future<void>? additionalAbortTrigger}) {
    final abort = _combineAbortTriggers(abortTrigger, additionalAbortTrigger);
    final http.Request request = abort == null
        ? http.Request(method, url)
        : http.AbortableRequest(method, url, abortTrigger: abort);
    request
      ..followRedirects = followRedirects
      ..maxRedirects = maxRedirects
      ..persistentConnection = persistentConnection
      ..headers.addAll(headers)
      ..bodyBytes = bodyBytes;
    return request;
  }
}

Future<void>? _combineAbortTriggers(
  Future<void>? first,
  Future<void>? second,
) {
  if (first == null) {
    return second == null ? null : _asCancellation(second);
  }
  if (second == null) return _asCancellation(first);
  return Future.any<void>([
    _asCancellation(first),
    _asCancellation(second),
  ]);
}

Future<void> _asCancellation(Future<void> trigger) async {
  try {
    await trigger;
  } catch (_) {
    // Abort triggers are required not to fail. Normalize a broken trigger to
    // ordinary cancellation before forwarding it to an HTTP client.
  }
}

Future<void> _waitForRetry(
  Duration duration,
  Future<void>? abortTrigger,
  Uri requestUrl,
  Future<void> Function(Duration) delay,
) async {
  if (abortTrigger == null) {
    await delay(duration);
    return;
  }
  await Future.any<void>([
    delay(duration),
    _abortAsError(abortTrigger, requestUrl),
  ]);
}

Future<T> _abortAsError<T>(
  Future<void> abortTrigger,
  Uri requestUrl,
) async {
  try {
    await abortTrigger;
  } catch (_) {
    // See the caller-abort listener above. A failing trigger is invalid but is
    // still treated as cancellation so it cannot start another attempt.
  }
  throw http.RequestAbortedException(requestUrl);
}

Future<http.StreamedResponse> _bufferResponse(
  http.StreamedResponse response,
) async {
  final bytes = await response.stream.toBytes();
  return http.StreamedResponse(
    Stream.value(bytes),
    response.statusCode,
    contentLength: bytes.length,
    request: response.request,
    headers: response.headers,
    isRedirect: response.isRedirect,
    persistentConnection: response.persistentConnection,
    reasonPhrase: response.reasonPhrase,
  );
}

bool _isRetryableStatus(int statusCode) {
  return statusCode == 408 || (statusCode >= 500 && statusCode <= 599);
}

bool _isRetryableError(Object error) {
  if (error is http.RequestAbortedException) {
    return false;
  }
  return error is TimeoutException || error is http.ClientException;
}

Duration _retryBackoff(int attempt, double randomDouble) {
  final exponentialMilliseconds =
      _initialRetryBackoff.inMilliseconds * (1 << attempt);
  final maximumMilliseconds = min(
    exponentialMilliseconds,
    _maxRetryBackoff.inMilliseconds,
  );
  final boundedRandom = randomDouble.clamp(0.0, 1.0);
  return Duration(
    microseconds: (boundedRandom * maximumMilliseconds * 1000).floor(),
  );
}

Duration? _retryAfter(http.BaseResponse response, DateTime now) {
  if (response.statusCode != 503) {
    return null;
  }

  final value = response.headers['retry-after']?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }

  if (RegExp(r'^\d+$').hasMatch(value)) {
    final seconds = int.tryParse(value);
    if (seconds == null || seconds > _maxRetryAfter.inSeconds) {
      return _maxRetryAfter + const Duration(microseconds: 1);
    }
    return Duration(seconds: seconds);
  }

  try {
    final delay = parseHttpDate(value).difference(now);
    return delay.isNegative ? Duration.zero : delay;
  } on FormatException {
    return null;
  }
}

Future<void> _defaultDelay(Duration duration) => Future<void>.delayed(duration);
