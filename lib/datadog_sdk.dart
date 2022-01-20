// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.
// ignore_for_file: unused_element, unused_field

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'src/datadog_configuration.dart';
import 'src/datadog_sdk_platform_interface.dart';
import 'src/internal_helpers.dart';
import 'src/internal_logger.dart';
import 'src/logs/ddlogs.dart';
import 'src/rum/ddrum.dart';
import 'src/traces/ddtraces.dart';

import 'src/version.dart' show ddSdkVersion;

export 'src/datadog_configuration.dart';
export 'src/rum/ddrum.dart'
    show RumHttpMethod, RumUserActionType, RumErrorSource, RumResourceType;
export 'src/traces/ddtraces.dart' show DdSpan, DdTags, OTTags, OTLogFields;

class _DatadogConfigKey {
  static const source = '_dd.source';
  static const version = '_dd.sdk_version';
  static const serviceName = '_dd.service_name';
  static const verbosity = '_dd.sdk_verbosity';
  static const nativeViewTracking = '_dd.native_view_tracking';
}

class DatadogSdk {
  static DatadogSdkPlatform get _platform {
    return DatadogSdkPlatform.instance;
  }

  static DatadogSdk? _singleton;
  static DatadogSdk get instance {
    _singleton ??= DatadogSdk._();
    return _singleton!;
  }

  DatadogSdk._();

  DdLogs? _logs;
  DdLogs? get logs => _logs;

  DdTraces? _traces;
  DdTraces? get traces => _traces;

  DdRum? _rum;
  DdRum? get rum => _rum;

  String get version => ddSdkVersion;

  final InternalLogger logger = InternalLogger();
  Verbosity get sdkVerbosity => logger.sdkVerbosity;
  set sdkVerbosity(Verbosity value) {
    logger.sdkVerbosity = value;
    unawaited(_platform.setSdkVerbosity(value));
  }

  Future<void> initialize(DdSdkConfiguration configuration) async {
    //configuration.additionalConfig[_DatadogConfigKey.source] = 'flutter';
    configuration.additionalConfig[_DatadogConfigKey.version] = ddSdkVersion;

    await _platform.initialize(configuration, logCallback: _platformLog);

    if (configuration.loggingConfiguration != null) {
      _logs = DdLogs(logger);
    }
    if (configuration.tracingConfiguration != null) {
      _traces = DdTraces(logger);
    }
    if (configuration.rumConfiguration != null) {
      _rum = DdRum(logger);
    }
  }

  Future<void> setUserInfo({
    String? id,
    String? name,
    String? email,
    Map<String, dynamic> extraInfo = const {},
  }) {
    return wrap('setUserInfo', logger, () {
      return _platform.setUserInfo(id, name, email, extraInfo);
    });
  }

  void _platformLog(String log) {
    if (kDebugMode) {
      print(log);
    }
  }
}
