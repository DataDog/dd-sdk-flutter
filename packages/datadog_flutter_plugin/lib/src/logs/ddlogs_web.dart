// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.
// ignore_for_file: unused_element

@JS('DD_LOGS')
library ddlogs_flutter_web;

import 'package:js/js.dart';

import '../../datadog_flutter_plugin.dart';
import '../web_helpers.dart';
import 'ddlogs_platform_interface.dart';

class DdLogsWeb extends DdLogsPlatform {
  final Map<String, Logger> _activeLoggers = {};

  static void initLogs(DdSdkConfiguration configuration) {
    String? version = configuration.additionalConfig[DatadogConfigKey.version];

    init(_InternalOptions(
      clientToken: configuration.clientToken,
      env: configuration.env,
      site: siteStringForSite(configuration.site),
      proxyUrl: configuration.customEndpoint,
      service: configuration.serviceName,
      version: version,
    ));
  }

  @override
  Future<void> createLogger(
      String loggerHandle, LoggingConfiguration config) async {
    var loggerHandlers = [
      if (config.sendLogsToDatadog) 'http',
      if (config.printLogsToConsole) 'console'
    ];
    var logger = _createLogger(
      config.loggerName ?? 'default',
      _JsLoggerConfiguration(),
    );
    if (logger != null) {
      if (loggerHandlers.isNotEmpty) {
        logger.setHandler(loggerHandlers);
      } else {
        logger.setHandler(['silent']);
      }

      _activeLoggers[loggerHandle] = logger;
    }
  }

  @override
  Future<void> addAttribute(
      String loggerHandle, String key, Object value) async {
    final logger = _activeLoggers[loggerHandle];
    logger?.addContext(key, valueToJs(value, 'value'));
  }

  @override
  Future<void> addTag(String loggerHandle, String tag, [String? value]) async {}

  @override
  Future<void> debug(String loggerHandle, String message,
      [Map<String, Object?> context = const {}]) async {
    final logger = _activeLoggers[loggerHandle];
    logger?.debug(message, valueToJs(context, 'context'));
  }

  @override
  Future<void> error(String loggerHandle, String message,
      [Map<String, Object?> context = const {}]) async {
    final logger = _activeLoggers[loggerHandle];
    logger?.error(message, valueToJs(context, 'context'));
  }

  @override
  Future<void> info(String loggerHandle, String message,
      [Map<String, Object?> context = const {}]) async {
    final logger = _activeLoggers[loggerHandle];
    logger?.info(message, valueToJs(context, 'context'));
  }

  @override
  Future<void> warn(String loggerHandle, String message,
      [Map<String, Object?> context = const {}]) async {
    final logger = _activeLoggers[loggerHandle];
    logger?.warn(message, valueToJs(context, 'context'));
  }

  @override
  Future<void> removeAttribute(String loggerHandle, String key) async {
    final logger = _activeLoggers[loggerHandle];
    logger?.removeContext(key);
  }

  @override
  Future<void> removeTag(String loggerHandle, String tag) async {}

  @override
  Future<void> removeTagWithKey(String loggerHandle, String key) async {}
}

@JS()
@anonymous
class _InternalOptions {
  external String get clientToken;
  external String get site;
  external String get env;
  external String? get proxyUrl;
  external String? get service;
  external String? get version;

  external factory _InternalOptions({
    String clientToken,
    String site,
    String env,
    String? service,
    String? proxyUrl,
    String? version,
  });
}

@JS()
@anonymous
class _JsLoggerConfiguration {
  external String? get level;
  external String? get handler;
  external dynamic get context;

  external factory _JsLoggerConfiguration({
    String? level,
    String? handler,
    dynamic context,
  });
}

@JS('Logger')
class Logger {
  external void debug(String message, dynamic messageContext);
  external void info(String message, dynamic messageContext);
  external void warn(String message, dynamic messageContext);
  external void error(String message, dynamic messageContext);

  external void addContext(String key, dynamic value);
  external void removeContext(String key);

  external void setHandler(List<String> handler);
}

@JS()
external void init(_InternalOptions options);

@JS()
external Logger? getLogger(String name);

@JS('createLogger')
external Logger? _createLogger(
    String name, _JsLoggerConfiguration? configuration);
