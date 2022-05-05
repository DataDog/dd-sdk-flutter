// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'src/attributes.dart';
import 'src/datadog_configuration.dart';
import 'src/datadog_plugin.dart';
import 'src/datadog_sdk_platform_interface.dart';
import 'src/helpers.dart';
import 'src/internal_logger.dart';
import 'src/logs/ddlogs.dart';
import 'src/logs/ddlogs_platform_interface.dart';
import 'src/rum/ddrum.dart';
import 'src/traces/ddtraces.dart';
import 'src/version.dart' show ddPackageVersion;

export 'src/attributes.dart' show DatadogConfigKey;
export 'src/datadog_configuration.dart';
export 'src/datadog_plugin.dart';
export 'src/rum/ddrum.dart'
    show
        RumHttpMethod,
        RumUserActionType,
        RumErrorSource,
        RumResourceType,
        rumMethodFromMethodString,
        resourceTypeFromContentType;
export 'src/rum/navigation_observer.dart'
    show
        DatadogNavigationObserver,
        DatadogNavigationObserverProvider,
        RumViewInfo,
        DatadogRouteAwareMixin;
export 'src/traces/ddtraces.dart'
    show DdSpan, OTTags, OTLogFields, generateTraceId;

typedef AppRunner = void Function();

/// A singleton for the Datadog SDK.
///
/// Once initialized, individual features can be access through the [logs]
/// and [rum] member variables. If a feature is disabled (either
/// because they were not configured or the SDK has not been initialized) the
/// member variables will default to `null`
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

  // ignore: deprecated_member_use_from_same_package
  DdTraces? _traces;
  @Deprecated('Tracing is deprecated and will be removed before 1.0')
  DdTraces? get traces => _traces;

  DdRum? _rum;
  DdRum? get rum => _rum;

  List<String> _firstPartyHosts = [];
  RegExp? _firstPartyRegex;

  final Map<Type, DatadogPlugin> _plugins = {};

  /// An unmodifiable list of first party hosts for tracing.
  List<String> get firstPartyHosts => List.unmodifiable(_firstPartyHosts);
  void _setFirstPartyHosts(List<String> value) {
    _firstPartyHosts = value;
    if (value.isNotEmpty) {
      // pattern = "^(.*\\.)*tracedHost1$|tracedHost2$|...$"
      var hosts = value.map((e) => RegExp.escape(e) + '\$').join('|');
      _firstPartyRegex = RegExp('^(.*\\.)*$hosts');
    } else {
      _firstPartyRegex = null;
    }
  }

  /// The version of this SDK.
  String get version => ddPackageVersion;

  /// Logger used internally by Datadog to report errors.
  @internal
  final InternalLogger internalLogger = InternalLogger();

  /// Set the verbosity of the Datadog SDK. Set to [Verbosity.info] by
  /// default. All internal logging is enabled only when [kDebugMode] is
  /// set.
  Verbosity get sdkVerbosity => internalLogger.sdkVerbosity;
  set sdkVerbosity(Verbosity value) {
    internalLogger.sdkVerbosity = value;
    unawaited(_platform.setSdkVerbosity(value));
  }

  /// Get an instance of a DatadogPlugin that was registered with
  /// [DdSdkConfiguration.addPlugin]
  T? getPlugin<T>() => _plugins[T.runtimeType] as T?;

  /// This function is not part of the public interface for Datadog, and may not
  /// be available in all targets. Used for integration and E2E testing purposes only.
  @visibleForTesting
  Future<void> flushAndDeinitialize() async {
    await _platform.flushAndDeinitialize();
    _logs = null;
    _traces = null;
    _rum = null;
  }

  /// A helper function that will initialize Datadog setup error reporting, and
  /// automatic HttpClient tracing.
  ///
  /// See also, [DdRum.handleFlutterError], [DatadogTrackingHttpClient]
  static Future<void> runApp(
      DdSdkConfiguration configuration, AppRunner runner) async {
    return runZonedGuarded(() async {
      WidgetsFlutterBinding.ensureInitialized();
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        DatadogSdk.instance.rum?.handleFlutterError(details);
        originalOnError?.call(details);
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

  /// Initialize the DatadogSdk with the provided [configuration].
  Future<void> initialize(DdSdkConfiguration configuration) async {
    configuration.additionalConfig[DatadogConfigKey.source] = 'flutter';
    configuration.additionalConfig[DatadogConfigKey.version] = version;

    _setFirstPartyHosts(configuration.firstPartyHosts);

    await _platform.initialize(configuration, logCallback: _platformLog);

    if (configuration.loggingConfiguration != null) {
      _logs = createLogger(configuration.loggingConfiguration!);
    }
    if (configuration.tracingConfiguration != null) {
      // ignore: deprecated_member_use_from_same_package
      _traces = DdTraces(internalLogger);
    }
    if (configuration.rumConfiguration != null) {
      _rum = DdRum(internalLogger);
    }

    for (final pluginConfig in configuration.additionalPlugins) {
      var plugin = pluginConfig.create(this);
      if (_plugins.containsKey(plugin.runtimeType)) {
        internalLogger.error(
            'Attempting to setup two plugins of the same type: ${plugin.runtimeType}. The second plugin will be ignored.');
      } else {
        plugin.initialize();
        _plugins[plugin.runtimeType] = plugin;
      }
    }
  }

  /// Create a new logger.
  ///
  /// This can be used in addition to or instead of the default logger at [logs]
  DdLogs createLogger(LoggingConfiguration configuration) {
    final logger = DdLogs(internalLogger);
    wrap('createLogger', internalLogger, () {
      return DdLogsPlatform.instance
          .createLogger(logger.loggerHandle, configuration);
    });
    return logger;
  }

  /// Sets current user information. User information will be added traces and
  /// RUM events automatically.
  void setUserInfo({
    String? id,
    String? name,
    String? email,
    Map<String, dynamic> extraInfo = const {},
  }) {
    wrap('setUserInfo', internalLogger, () {
      return _platform.setUserInfo(id, name, email, extraInfo);
    });
  }

  void setTrackingConsent(TrackingConsent trackingConsent) {
    wrap('setTrackingConsent', internalLogger, () {
      return _platform.setTrackingConsent(trackingConsent);
    });
  }

  /// Determine if the provided URI is a first party host as determined by the
  /// value of [firstPartyHosts].
  bool isFirstPartyHost(Uri uri) {
    return _firstPartyRegex?.hasMatch(uri.host) ?? false;
  }

  void _platformLog(String log) {
    if (kDebugMode) {
      print(log);
    }
  }
}
