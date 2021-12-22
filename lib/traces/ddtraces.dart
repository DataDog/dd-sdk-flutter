// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'ddtraces_platform_interface.dart';

class DdSpan {
  final DdTracesPlatform _platform;

  int _handle;
  int get handle => _handle;

  DdSpan(this._platform, this._handle);

  Future<void> setActive() {
    if (_handle <= 0) {
      return Future.value();
    }

    return _platform.spanSetActive(this);
  }

  Future<void> setBaggageItem(String key, String value) {
    if (_handle <= 0) {
      return Future.value();
    }

    return _platform.spanSetBaggageItem(this, key, value);
  }

  /// Set a tag with the given [key] to the given [value]. Although the type for
  /// [value] is dynamic, the object passed in must be one of the types
  /// supported byt the [StandardMessageCodec]
  Future<void> setTag(String key, dynamic value) {
    if (_handle <= 0) {
      return Future.value();
    }

    return _platform.spanSetTag(this, key, value);
  }

  Future<void> setError(Exception error, [StackTrace? stackTrace]) {
    if (_handle <= 0) {
      return Future.value();
    }

    return setErrorInfo(
        error.runtimeType.toString(), error.toString(), stackTrace);
  }

  Future<void> setErrorInfo(
      String kind, String message, StackTrace? stackTrace) {
    if (_handle <= 0) {
      return Future.value();
    }

    return _platform.spanSetError(this, kind, message, stackTrace?.toString());
  }

  Future<void> finish() async {
    if (_handle <= 0) {
      return Future.value();
    }

    await _platform.spanFinish(this);
    _handle = -1;
  }
}

class DdTraces {
  static DdTracesPlatform get _platform {
    return DdTracesPlatform.instance;
  }

  Future<DdSpan> startSpan(String operationName,
      {DdSpan? parentSpan, Map<String, dynamic>? tags, DateTime? startTime}) {
    return _platform.startSpan(operationName, parentSpan, tags, startTime);
  }

  Future<DdSpan> startRootSpan(String operationName,
      {Map<String, dynamic>? tags, DateTime? startTime}) {
    return _platform.startRootSpan(operationName, tags, startTime);
  }
}
