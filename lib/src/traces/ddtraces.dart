// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import '../helpers.dart';
import '../internal_logger.dart';
import 'ddtraces_platform_interface.dart';

typedef TimeProvider = DateTime Function();
DateTime systemTimeProvider() => DateTime.now();

/// A collection of standard `Span` tag keys defined by Open Tracing.
/// Use them as the `key` in [DdSpan.setTag]. Use the expected type for the `value`.
///
/// See more: [Span tags table](https://github.com/opentracing/specification/blob/master/semantic_conventions.md#span-tags-table)
class OTTags {
  /// Expected value: `String`.
  static const component = 'component';

  /// Expected value: `String`
  static const dbInstance = 'db.instance';

  /// Expected value: `String`
  static const dbStatement = 'db.statement';

  /// Expected value: `String`
  static const dbType = 'db.type';

  /// Expected value: `String`
  static const dbUser = 'db.user';

  /// Expected value: `Bool`
  static const error = 'error';

  /// Expected value: `String`
  static const httpMethod = 'http.method';

  /// Expected value: `Int`
  static const httpStatusCode = 'http.status_code';

  /// Expected value: `String`
  static const httpUrl = 'http.url';

  /// Expected value: `String`
  static const messageBusDestination = 'message_bus.destination';

  /// Expected value: `String`
  static const peerAddress = 'peer.address';

  /// Expected value: `String`
  static const peerHostname = 'peer.hostname';

  /// Expected value: `String`
  static const peerIPv4 = 'peer.ipv4';

  /// Expected value: `String`
  static const peerIPv6 = 'peer.ipv6';

  /// Expected value: `Int`
  static const peerPort = 'peer.port';

  /// Expected value: `String`
  static const peerService = 'peer.service';

  /// Expected value: `Int`
  static const samplingPriority = 'sampling.priority';

  /// Expected value: `String`
  static const spanKind = 'span.kind';
}

/// A collection of standard `Span` log fields defined by Open Tracing.
/// Use them as the `key` for `fields` dictionary in [DdSpan.log]. Use the expected type for the value.
///
/// See more: [Log fields table](https://github.com/opentracing/specification/blob/master/semantic_conventions.md#log-fields-table)
///
class OTLogFields {
  /// Expected value: `String`
  static const errorKind = 'error.kind';

  /// Expected value: `String`
  static const event = 'event';

  /// Expected value: `String`
  static const message = 'message';

  /// Expected value: `String`
  static const stack = 'stack';
}

class DdSpan {
  static String closedSpanWarning(String method) =>
      'Attempting to call $method on a closed span.';

  final DdTracesPlatform _platform;
  final TimeProvider _timeProvider;
  InternalLogger? _logger;

  int _handle;
  int get handle => _handle;

  DdSpan(this._platform, this._timeProvider, this._handle, [this._logger]);

  void setActive() {
    if (_handle <= 0 || _logger == null) {
      _logger?.warn(closedSpanWarning('setActivate'));
      return;
    }

    wrap('span.setActive', _logger!, () {
      return _platform.spanSetActive(this);
    });
  }

  void setBaggageItem(String key, String value) {
    if (_handle <= 0 || _logger == null) {
      _logger?.warn(closedSpanWarning('setBaggageItem'));
      return;
    }

    wrap('span.setBaggageItem', _logger!, () {
      return _platform.spanSetBaggageItem(this, key, value);
    });
  }

  /// Set a tag with the given [key] to the given [value]. Although the type for
  /// [value] is [Object], the object passed in must be one of the types
  /// supported by the [StandardMessageCodec]
  void setTag(String key, Object value) {
    if (_handle <= 0 || _logger == null) {
      _logger?.warn(closedSpanWarning('setTag'));
      return;
    }

    wrap('span.setTag', _logger!, () {
      return _platform.spanSetTag(this, key, value);
    });
  }

  void setError(Exception error, [StackTrace? stackTrace]) {
    if (_handle <= 0 || _logger == null) {
      _logger?.warn(closedSpanWarning('setError'));
      return;
    }

    wrap('span.setError', _logger!, () {
      return setErrorInfo(
          error.runtimeType.toString(), error.toString(), stackTrace);
    });
  }

  void setErrorInfo(String kind, String message, StackTrace? stackTrace) {
    if (_handle <= 0 || _logger == null) {
      _logger?.warn(closedSpanWarning('setErrorInfo'));
      return;
    }
    stackTrace ??= StackTrace.current;

    wrap('span.setErrorInfo', _logger!, () {
      return _platform.spanSetError(this, kind, message, stackTrace.toString());
    });
  }

  void log(Map<String, Object?> fields) {
    if (_handle <= 0 || _logger == null) {
      _logger?.warn(closedSpanWarning('log'));
      return;
    }

    wrap('span.log', _logger!, () {
      return _platform.spanLog(this, fields);
    });
  }

  void finish([DateTime? finishTime]) {
    if (_handle <= 0 || _logger == null) {
      _logger?.warn(closedSpanWarning('finish'));
      return;
    }

    // Immediately invalidate the handle to prevent extra calls
    final currentHandle = _handle;
    _handle = -1;

    wrap('span.finish', _logger!, () async {
      final resolvedTime = finishTime ?? _timeProvider();
      await _platform.spanFinish(currentHandle, resolvedTime);
    });
  }
}

class DdTraces {
  static DdTracesPlatform get _platform {
    return DdTracesPlatform.instance;
  }

  final TimeProvider timeProvider;
  final InternalLogger _logger;
  var _nextSpanHandle = 1;

  DdTraces(this._logger, {this.timeProvider = systemTimeProvider});

  DdSpan startSpan(
    String operationName, {
    DdSpan? parentSpan,
    String? resourceName,
    Map<String, dynamic>? tags,
    DateTime? startTime,
  }) {
    final spanHandle = _nextSpanHandle++;
    final span = DdSpan(_platform, timeProvider, spanHandle);
    span._logger = _logger;
    final resolvedTime = startTime ?? timeProvider();

    wrapAsync('traces.startSpan', _logger, () {
      return _platform.startSpan(spanHandle, operationName, parentSpan,
          resourceName, tags, resolvedTime);
    }).then((success) {
      success ??= false;
      if (!success) {
        _logger.error(
            'Error creating span named $operationName - this span will be force closed');
        // Clear the logger on this span or it will spam being closed
        span._handle = 0;
        span._logger = null;
      }
    });

    return span;
  }

  DdSpan startRootSpan(
    String operationName, {
    String? resourceName,
    Map<String, dynamic>? tags,
    DateTime? startTime,
  }) {
    final spanHandle = _nextSpanHandle++;
    final span = DdSpan(_platform, timeProvider, spanHandle);
    span._logger = _logger;
    final resolvedTime = startTime ?? timeProvider();

    wrapAsync('traces.startSpan', _logger, () {
      return _platform.startRootSpan(
          spanHandle, operationName, resourceName, tags, resolvedTime);
    }).then((success) {
      success ??= false;
      if (!success) {
        _logger.error(
            'Error creating span named $operationName - this span will be force closed');
        // Clear the logger on this span or it will spam being closed
        span._handle = 0;
        span._logger = null;
      }
    });

    return span;
  }

  Future<Map<String, String>> getTracePropagationHeaders(DdSpan span) async {
    final headers =
        await wrapAsync('traces.getTracePropagationHeaders', _logger, () {
      return _platform.getTracePropagationHeaders(span);
    });

    return headers ?? {};
  }
}
