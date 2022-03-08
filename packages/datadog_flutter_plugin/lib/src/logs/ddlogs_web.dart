// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.
@JS('DD_LOGS')
library ddlogs_flutter_web;

import 'package:js/js.dart';

import '../../datadog_flutter_plugin.dart';
import '../web_helpers.dart';
import 'ddlogs_platform_interface.dart';

class DdLogsWeb extends DdLogsPlatform {
  static void initLogs(DdSdkConfiguration configuration) {
    String? version = configuration.additionalConfig[DatadogConfigKey.version];

    // TODO different site endpoints
    String site = 'datadoghq.com';

    init(_InternalOptions(
      clientToken: configuration.clientToken,
      env: configuration.env,
      site: site,
      proxyUrl: configuration.customEndpoint,
      service: configuration.serviceName,
      version: version,
    ));

    if (configuration.loggingConfiguration!.printLogsToConsole) {
      logger.setHandler(['http', 'console']);
    }
  }

  @override
  Future<void> addAttribute(String key, Object value) async {
    logger.addContext(key, valueToJs(value, 'value'));
  }

  @override
  Future<void> addTag(String tag, [String? value]) async {}

  @override
  Future<void> debug(String message,
      [Map<String, Object?> context = const {}]) async {
    logger.debug(message, valueToJs(context, 'context'));
  }

  @override
  Future<void> error(String message,
      [Map<String, Object?> context = const {}]) async {
    logger.error(message, valueToJs(context, 'context'));
  }

  @override
  Future<void> info(String message,
      [Map<String, Object?> context = const {}]) async {
    logger.info(message, valueToJs(context, 'context'));
  }

  @override
  Future<void> removeAttribute(String key) async {
    logger.removeContext(key);
  }

  @override
  Future<void> removeTag(String tag) async {}

  @override
  Future<void> removeTagWithKey(String key) async {}

  @override
  Future<void> warn(String message,
      [Map<String, Object?> context = const {}]) async {
    logger.warn(message, valueToJs(context, 'context'));
  }
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

@JS('logger')
external Logger logger;

@JS()
external void init(_InternalOptions options);
