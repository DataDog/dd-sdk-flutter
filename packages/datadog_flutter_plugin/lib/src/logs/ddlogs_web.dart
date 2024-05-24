// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.
// ignore_for_file: unused_element, library_private_types_in_public_api

import 'dart:js_interop';

import 'package:meta/meta.dart';

import '../../datadog_flutter_plugin.dart';
import '../../datadog_internal.dart';
import '../web_helpers.dart';
import 'ddlogs_platform_interface.dart';
import 'ddweb_helpers.dart';

class DdLogsWeb extends DdLogsPlatform {
  final Map<String, Logger> _activeLoggers = {};

  static void initLogs(DatadogConfiguration configuration) {
    DD_LOGS.init(_LogInitOptions(
      clientToken: configuration.clientToken,
      env: configuration.env,
      proxy: configuration.loggingConfiguration?.customEndpoint,
      site: siteStringForSite(configuration.site),
      service: configuration.service,
      version: configuration.versionTag,
    ));
  }

  @override
  Future<void> enable(
      DatadogSdk core, DatadogLoggingConfiguration config) async {}

  @override
  Future<void> addGlobalAttribute(String key, Object value) async {}

  @override
  Future<void> removeGlobalAttribute(String key) async {}

  @override
  Future<void> deinitialize() async {}

  @override
  Future<void> createLogger(
      String loggerHandle, DatadogLoggerConfiguration config) async {
    var loggerHandlers = [
      'http'.toJS,
    ];
    var logger = DD_LOGS.createLogger(
      config.name ?? 'default',
      _JsLoggerConfiguration(),
    );
    if (logger != null) {
      if (loggerHandlers.isNotEmpty) {
        logger.setHandler(loggerHandlers.toJS);
      } else {
        logger.setHandler(['silent'.toJS].toJS);
      }

      _activeLoggers[loggerHandle] = logger;
    }
  }

  @override
  Future<void> destroyLogger(String loggerHandle) async {
    _activeLoggers.remove(loggerHandle);
  }

  @override
  Future<void> addAttribute(
      String loggerHandle, String key, Object value) async {
    final logger = _activeLoggers[loggerHandle];
    logger?.setContextProperty(key, valueToJs(value, 'value'));
  }

  @override
  Future<void> addTag(String loggerHandle, String tag, [String? value]) async {}

  @override
  Future<void> removeAttribute(String loggerHandle, String key) async {
    final logger = _activeLoggers[loggerHandle];
    logger?.removeContextProperty(key);
  }

  @override
  Future<void> removeTag(String loggerHandle, String tag) async {}

  @override
  Future<void> removeTagWithKey(String loggerHandle, String key) async {}

  @override
  Future<void> log(
    String loggerHandle,
    LogLevel level,
    String message,
    String? errorMessage,
    String? errorKind,
    StackTrace? errorStackTrace,
    Map<String, Object?> attributes,
  ) async {
    final logger = _activeLoggers[loggerHandle];
    final webLogLevel = _toWebLogLevel(level);
    JSError? error;
    if (errorMessage != null || errorKind != null) {
      error = JSError();
      error.stack = convertWebStackTrace(errorStackTrace);
      error.message = errorMessage;
      error.name = errorKind ?? 'Error';

      // Move error fingerprint to its proper location
      final fingerprint = attributes[DatadogAttributes.errorFingerprint];
      if (fingerprint != null) {
        attributes = Map.from(attributes)
          ..remove(DatadogAttributes.errorFingerprint)
          ..putIfAbsent('error.fingerprint', () => fingerprint);
      }
    }
    logger?.log(
      message,
      valueToJs(attributes, 'attributes'),
      webLogLevel,
      error,
    );
  }
}

String _toWebLogLevel(LogLevel level) {
  switch (level) {
    case LogLevel.debug:
      return 'debug';
    case LogLevel.info:
      return 'info';
    case LogLevel.notice:
      return 'warn';
    case LogLevel.warning:
      return 'warn';
    case LogLevel.error:
      return 'error';
    case LogLevel.critical:
      return 'error';
    case LogLevel.alert:
      return 'error';
    case LogLevel.emergency:
      return 'error';
  }
}

@anonymous
extension type _LogInitOptions._(JSObject _) implements JSObject {
  external String get clientToken;
  external String get site;
  external String get env;
  external String? get proxy;
  external String? get service;
  external String? get version;

  external factory _LogInitOptions({
    String clientToken,
    String site,
    String env,
    String? service,
    String? proxy,
    String? version,
  });
}

@anonymous
extension type _JsLoggerConfiguration._(JSObject _) implements JSObject {
  external String? get level;
  external String? get handler;
  external JSObject get context;

  external factory _JsLoggerConfiguration({
    String? level,
    String? handler,
    JSObject context,
  });
}

extension type _DdLogs._(JSObject _) implements JSObject {
  external void init(_LogInitOptions options);

  external Logger? getLogger(String name);

  @internal
  external Logger? createLogger(
      String name, _JsLoggerConfiguration? configuration);
}

@JS()
// ignore: non_constant_identifier_names
external _DdLogs DD_LOGS;

extension type Logger._(JSObject _) implements JSObject {
  external void log(
      String message, JSAny? messageContext, String status, JSError? error);

  external void setContextProperty(String key, JSAny? value);
  external void removeContextProperty(String key);

  external void setHandler(JSArray handler);
}
