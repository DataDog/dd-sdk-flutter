// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.
// ignore_for_file: unused_element, unused_field

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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
export 'src/rum/navigation_observer.dart'
    show DatadogNavigationObserver, RumViewInfo;

class _DatadogConfigKey {
  static const source = '_dd.source';
  static const version = '_dd.sdk_version';
  static const serviceName = '_dd.service_name';
  static const verbosity = '_dd.sdk_verbosity';
  static const nativeViewTracking = '_dd.native_view_tracking';
}

typedef AppRunner = void Function();

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

  List<String> _firstPartyHosts = [];
  RegExp? _firstPartyRegex;

  /// A list of first party hosts for tracing. Note that this is an unmodifiable
  /// list. If you need to add a host, call the setter for [firstPartyHosts]
  List<String> get firstPartyHosts => List.unmodifiable(_firstPartyHosts);
  set firstPartyHosts(List<String> value) {
    _firstPartyHosts = value;
    if (value.isNotEmpty) {
      // pattern = "^(.*\\.)*tracedHost1$|tracedHost2$|...$"
      var hosts = value.map((e) => RegExp.escape(e) + '\$').join('|');
      _firstPartyRegex = RegExp('^(.*\\.)*$hosts');
    } else {
      _firstPartyRegex = null;
    }
  }

  String get version => ddSdkVersion;

  final InternalLogger logger = InternalLogger();
  Verbosity get sdkVerbosity => logger.sdkVerbosity;
  set sdkVerbosity(Verbosity value) {
    logger.sdkVerbosity = value;
    unawaited(_platform.setSdkVerbosity(value));
  }

  static Future<void> runApp(
      DdSdkConfiguration configuration, AppRunner runner) async {
    return runZonedGuarded(() async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        DatadogSdk.instance.rum?.handleFlutterError(details);
      };

      await DatadogSdk.instance.initialize(configuration);

      runner();
    }, (e, s) {
      DatadogSdk.instance.rum?.addErrorInfo(
        e.toString(),
        RumErrorSource.source,
        stackTrace: s,
      );
    });
  }

  Future<void> initialize(DdSdkConfiguration configuration) async {
    //configuration.additionalConfig[_DatadogConfigKey.source] = 'flutter';
    configuration.additionalConfig[_DatadogConfigKey.version] = ddSdkVersion;

    firstPartyHosts = configuration.firstPartyHosts;

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

  bool isFirstPartyHost(Uri uri) {
    return _firstPartyRegex?.hasMatch(uri.host) ?? false;
  }

  void _platformLog(String log) {
    if (kDebugMode) {
      print(log);
    }
  }
}
