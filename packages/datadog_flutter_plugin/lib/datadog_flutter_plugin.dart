// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'datadog_internal.dart';
import 'src/datadog_configuration.dart';
import 'src/datadog_noop_platform.dart';
import 'src/datadog_plugin.dart';
import 'src/logs/ddlogs.dart';
import 'src/logs/ddlogs_noop_platform.dart';
import 'src/logs/ddlogs_platform_interface.dart';
import 'src/rum/ddrum_noop_platform.dart';
import 'src/rum/ddrum_platform_interface.dart';
import 'src/rum/rum.dart';
import 'src/version.dart' show ddPackageVersion;

export 'src/datadog_configuration.dart';
export 'src/datadog_plugin.dart';
export 'src/logs/logs.dart';
export 'src/rum/rum.dart';
export 'src/tracing/tracing_headers.dart' show TracingHeaderType;

typedef AppRunner = void Function();

enum CoreLoggerLevel { debug, warn, error, critical }

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

  DatadogSdk._();

  static DatadogSdk? _singleton;
  static DatadogSdk get instance {
    _singleton ??= DatadogSdk._();
    return _singleton!;
  }

  /// Set Datadog to use No Op platform implementations.
  ///
  /// Not that this disables Datadog, and should only be used when performing
  /// headless integration tests where the underlying platform is not available
  static void initializeForTesting() {
    DatadogSdkPlatform.instance = DatadogSdkNoOpPlatform();
    DdLogsPlatform.instance = DdNoOpLogsPlatform();
    DdRumPlatform.instance = DdNoOpRumPlatform();
  }

  bool _initialized = false;

  DatadogLogging? _logs;
  DatadogLogging? get logs => _logs;

  DatadogRum? _rum;
  DatadogRum? get rum => _rum;

  final List<FirstPartyHost> _firstPartyHosts = [];

  final Map<Type, DatadogPlugin> _plugins = {};

  /// An unmodifiable list of first party hosts for tracing.
  List<FirstPartyHost> get firstPartyHosts =>
      List.unmodifiable(_firstPartyHosts);

  /// The version of this SDK.
  static String get sdkVersion => ddPackageVersion;

  /// Logger used internally by Datadog to report errors.
  @internal
  final InternalLogger internalLogger = InternalLogger();

  /// Internal extension access to the configured platform
  DatadogSdkPlatform get platform => _platform;

  /// Set the verbosity of the Datadog SDK. Set to [CoreLoggerLevel.info] by
  /// default. All internal logging is enabled only when [kDebugMode] is
  /// set.
  CoreLoggerLevel get sdkVerbosity => internalLogger.sdkVerbosity;
  set sdkVerbosity(CoreLoggerLevel value) {
    internalLogger.sdkVerbosity = value;
    if (_initialized) {
      unawaited(_platform.setSdkVerbosity(value));
    }
  }

  /// Get an instance of a DatadogPlugin that was registered with
  /// [DdSdkConfiguration.addPlugin]
  T? getPlugin<T>() => _plugins[T] as T?;

  /// This function is not part of the public interface for Datadog, and may not
  /// be available in all targets. Used for integration and E2E testing purposes only.
  @visibleForTesting
  Future<void> flushAndDeinitialize() async {
    await _platform.flushAndDeinitialize();
    for (final plugin in _plugins.values) {
      plugin.shutdown();
    }
    _plugins.clear();
    _initialized = false;
  }

  /// A helper function that will initialize Datadog and setup error reporting
  ///
  /// See also, [DdRum.handleFlutterError], [DatadogTrackingHttpClient]
  static Future<void> runApp(
    DatadogConfiguration configuration,
    TrackingConsent trackingConsent,
    AppRunner runner,
  ) async {
    WidgetsFlutterBinding.ensureInitialized();
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      DatadogSdk.instance.rum?.handleFlutterError(details);
      originalOnError?.call(details);
    };
    final platformOriginalOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (e, st) {
      DatadogSdk.instance.rum?.addErrorInfo(
        e.toString(),
        RumErrorSource.source,
        stackTrace: st,
      );
      return platformOriginalOnError?.call(e, st) ?? false;
    };

    await DatadogSdk.instance.initialize(configuration, trackingConsent);
    DatadogSdk.instance
        .updateConfigurationInfo(LateConfigurationProperty.trackErrors, true);

    runner();
  }

  /// Initialize the DatadogSdk with the provided [configuration].
  Future<void> initialize(DatadogConfiguration configuration,
      TrackingConsent trackingConsent) async {
    // First set our SDK verbosity. We can assume WidgetsFlutterBinding has been initialized at this point
    await _platform.setSdkVerbosity(internalLogger.sdkVerbosity);

    configuration.additionalConfig[DatadogConfigKey.source] = 'flutter';
    configuration.additionalConfig[DatadogConfigKey.sdkVersion] = sdkVersion;

    //_setFirstPartyHosts(configuration.firstPartyHostsWithTracingHeaders);

    await _platform.initialize(configuration, trackingConsent,
        logCallback: _platformLog, internalLogger: internalLogger);

    if (configuration.loggingConfiguration != null) {
      _logs = await DatadogLogging.enable(
          this, configuration.loggingConfiguration!);
    }

    if (configuration.rumConfiguration != null) {
      _rum = await DatadogRum.enable(this, configuration.rumConfiguration!);
    }

    _initializePlugins(configuration.additionalPlugins);
    _initialized = true;
  }

  /// Attach the Datadog Flutter SDK to an already initialized Datadog Native
  /// (iOS or Android) SDK.  This is used for "app in app" embedding of Flutter.
  // Future<void> attachToExisting(
  //   DdSdkExistingConfiguration config,
  // ) async {
  //   // First set our SDK verbosity. We can assume WidgetsFlutterBinding has been initialized at this point
  //   await _platform.setSdkVerbosity(internalLogger.sdkVerbosity);

  //   final attachResponse = await wrapAsync<AttachResponse>(
  //       'attachToExisting', internalLogger, null, () async {
  //     return await _platform.attachToExisting();
  //   });

  //   if (attachResponse != null) {
  //     _setFirstPartyHosts(config.firstPartyHostsWithTracingHeaders);

  //     if (config.loggingConfiguration != null) {
  //       try {
  //         _logs = createLogger(config.loggingConfiguration!);
  //       } catch (_) {
  //         // This is likely fine. Since we have no simple way of knowing if Logging is
  //         // enabled, we try to create a logger anyway, which could potentially fail.
  //         internalLogger.debug(
  //             'A logging configuration was provided to `attachToExisting` but log creation failed, likely because logging is disabled in the native SDK. No global log was created');
  //       }
  //     }
  //     if (attachResponse.rumEnabled) {
  //       _rum = DdRum(
  //           RumConfiguration.existing(
  //             detectLongTasks: config.detectLongTasks,
  //             longTaskThreshold: config.longTaskThreshold,
  //             tracingSamplingRate: config.tracingSamplingRate,
  //           ),
  //           internalLogger);
  //       await _rum!.initialize();
  //     }

  //     _initializePlugins(config.additionalPlugins);
  //     _initialized = true;
  //   } else {
  //     internalLogger.error(
  //         'Failed to attach to an existing native instance of the Datadog SDK.');
  //   }
  // }

  /// Sets current user information. User information will be added traces and
  /// RUM events automatically.
  void setUserInfo({
    String? id,
    String? name,
    String? email,
    Map<String, Object?> extraInfo = const {},
  }) {
    wrap('setUserInfo', internalLogger, extraInfo, () {
      return _platform.setUserInfo(id, name, email, extraInfo);
    });
  }

  /// Add custom attributes to the current user information
  ///
  /// This extra info will be added to already existing extra info that is added
  /// to logs traces and RUM events automatically.
  ///
  /// Setting an existing attribute to `null` will remove that attribute from
  /// the user's extra info
  void addUserExtraInfo(Map<String, Object?> extraInfo) {
    wrap('addUserExtraInfo', internalLogger, extraInfo, () {
      return _platform.addUserExtraInfo(extraInfo);
    });
  }

  void setTrackingConsent(TrackingConsent trackingConsent) {
    wrap('setTrackingConsent', internalLogger, null, () {
      return _platform.setTrackingConsent(trackingConsent);
    });
  }

  // Determine if the provided URI is a first party host as determined by the
  // value of [firstPartyHosts].
  bool isFirstPartyHost(Uri uri) {
    return headerTypesForHost(uri).isNotEmpty;
  }

  Set<TracingHeaderType> headerTypesForHost(Uri uri) {
    var tracingHeaderTypes = <TracingHeaderType>{};
    for (var host in firstPartyHosts) {
      if (host.matches(uri)) {
        tracingHeaderTypes = tracingHeaderTypes.union(host.headerTypes);
      }
    }
    return tracingHeaderTypes;
  }

  void _platformLog(String log) {
    if (kDebugMode) {
      print(log);
    }
  }

  void _initializePlugins(List<DatadogPluginConfiguration> plugins) {
    for (final pluginConfig in plugins) {
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
}
