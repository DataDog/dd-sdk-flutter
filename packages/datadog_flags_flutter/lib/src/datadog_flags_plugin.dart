// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/foundation.dart';

/// Convenience access to the Flutter-integrated Datadog Flags plugin.
extension DatadogSdkFlagsExtension on DatadogSdk {
  /// Returns the configured flags plugin, or `null` when flags integration was
  /// not added to [DatadogConfiguration].
  DatadogFlagsPlugin? get flags => getPlugin<DatadogFlagsPlugin>();
}

/// Adds Flutter SDK integration for the standalone `datadog_flags` package.
///
/// Register this configuration with [DatadogConfiguration.addPlugin] to derive
/// Flags SDK account metadata from the initialized [DatadogSdk] and to add
/// successful flag evaluations to the active RUM view.
class DatadogFlagsPluginConfiguration extends DatadogPluginConfiguration {
  /// Optional Flags SDK configuration overrides.
  ///
  /// When [DatadogFlagsConfiguration.datadogConfig] is omitted, the plugin
  /// derives it from [DatadogConfiguration].
  final DatadogFlagsConfiguration flagsConfiguration;

  /// Whether successful flag evaluations should be added to the active RUM
  /// view through [DatadogRum.addFeatureFlagEvaluation].
  final bool rumIntegrationEnabled;

  /// Creates Flutter integration configuration for `datadog_flags`.
  const DatadogFlagsPluginConfiguration({
    this.flagsConfiguration = const DatadogFlagsConfiguration(),
    this.rumIntegrationEnabled = true,
  });

  @override
  DatadogPlugin create(DatadogSdk datadogInstance) {
    return DatadogFlagsPlugin(
      datadogInstance,
      flagsConfiguration: flagsConfiguration,
      rumIntegrationEnabled: rumIntegrationEnabled,
    );
  }
}

/// Flutter integration plugin for Datadog feature flags.
///
/// Use [sharedClient] to evaluate flags with the same API as the standalone
/// `datadog_flags` package. Successful evaluations still emit exposure and
/// flag-evaluation telemetry through `datadog_flags`; this plugin only adds the
/// Flutter-specific setup and RUM feature flag tagging.
class DatadogFlagsPlugin extends DatadogPlugin {
  final DatadogFlagsConfiguration _flagsConfiguration;
  final bool _rumIntegrationEnabled;
  final DatadogFlags _flags;
  final Map<String, DatadogFlutterFlagsClient> _clients = {};

  Future<void> _ready = Future<void>.value();

  /// Creates a Flutter flags integration plugin.
  DatadogFlagsPlugin(
    super.instance, {
    DatadogFlagsConfiguration flagsConfiguration =
        const DatadogFlagsConfiguration(),
    bool rumIntegrationEnabled = true,
    @visibleForTesting DatadogFlags? flags,
  })  : _flagsConfiguration = flagsConfiguration,
        _rumIntegrationEnabled = rumIntegrationEnabled,
        _flags = flags ?? DatadogFlags.instance;

  /// Completes when the underlying `datadog_flags` SDK has been configured.
  Future<void> get ready => _ready;

  @override
  void initialize() {
    _ready = _enableFlags();
  }

  /// Returns a named feature flag client.
  ///
  /// Call [DatadogFlutterFlagsClient.initialize] before evaluating flags for a
  /// subject. The client waits for this plugin's [ready] future before fetching
  /// assignments.
  DatadogFlutterFlagsClient sharedClient({
    String name = DatadogFlags.defaultClientName,
  }) {
    return _clients.putIfAbsent(
      name,
      () => DatadogFlutterFlagsClient(
        name: name,
        resolveDelegate: () async {
          await ready;
          return _flags.sharedClient(name: name);
        },
        addRumFeatureFlagEvaluation: _addRumFeatureFlagEvaluation,
        rumIntegrationEnabled: _rumIntegrationEnabled,
      ),
    );
  }

  /// Clears in-memory and stored assignments for all integrated clients.
  Future<void> reset() => _flags.reset();

  @override
  void shutdown() {
    _clients.clear();
    unawaited(_flags.disable());
  }

  Future<void> _enableFlags() async {
    final datadogConfiguration = instance.configuration;
    if (datadogConfiguration == null) {
      return;
    }

    final flagsSite = _flagsSiteFor(datadogConfiguration.site);
    if (flagsSite == null && _flagsConfiguration.datadogConfig == null) {
      return;
    }

    await _flags.enable(
      configuration: _configurationFor(
        datadogConfiguration: datadogConfiguration,
        flagsSite: flagsSite,
      ),
    );
  }

  DatadogFlagsConfiguration _configurationFor({
    required DatadogConfiguration datadogConfiguration,
    required DatadogFlagsSite? flagsSite,
  }) {
    final flagsDatadogConfig = _flagsConfiguration.datadogConfig ??
        DatadogFlagsConfig(
          clientToken: datadogConfiguration.clientToken,
          env: datadogConfiguration.env,
          site: flagsSite!,
          applicationId: datadogConfiguration.rumConfiguration?.applicationId,
          service: datadogConfiguration.service,
          version: datadogConfiguration.versionTag,
        );

    return DatadogFlagsConfiguration(
      customFlagsEndpoint: _flagsConfiguration.customFlagsEndpoint,
      customFlagsHeaders: _flagsConfiguration.customFlagsHeaders,
      customExposureEndpoint: _flagsConfiguration.customExposureEndpoint,
      trackExposures: _flagsConfiguration.trackExposures,
      customEvaluationEndpoint: _flagsConfiguration.customEvaluationEndpoint,
      trackEvaluations: _flagsConfiguration.trackEvaluations,
      evaluationFlushInterval: _flagsConfiguration.evaluationFlushInterval,
      httpClient: _flagsConfiguration.httpClient,
      datadogConfig: flagsDatadogConfig,
      store: _flagsConfiguration.store,
      dateProvider: _flagsConfiguration.dateProvider,
    );
  }

  void _addRumFeatureFlagEvaluation(String key, Object value) {
    instance.rum?.addFeatureFlagEvaluation(key, value);
  }
}

/// A feature flag client integrated with Flutter RUM feature flag tracking.
class DatadogFlutterFlagsClient implements DatadogFlagsClient {
  final Future<DatadogFlagsClient> Function() _resolveDelegate;
  final void Function(String key, Object value) _addRumFeatureFlagEvaluation;
  final bool _rumIntegrationEnabled;

  DatadogFlagsClient? _delegate;

  @override
  final String name;

  /// Creates a Flutter-integrated feature flag client.
  @visibleForTesting
  DatadogFlutterFlagsClient({
    required this.name,
    required Future<DatadogFlagsClient> Function() resolveDelegate,
    required void Function(String key, Object value)
        addRumFeatureFlagEvaluation,
    bool rumIntegrationEnabled = true,
  })  : _resolveDelegate = resolveDelegate,
        _addRumFeatureFlagEvaluation = addRumFeatureFlagEvaluation,
        _rumIntegrationEnabled = rumIntegrationEnabled;

  @override
  Future<void> initialize(FlagsEvaluationContext context) async {
    final delegate = await _delegateOrResolve();
    await delegate.initialize(context);
  }

  @override
  FlagDetails<bool> getBooleanDetails({
    required String key,
    required bool defaultValue,
  }) {
    final delegate = _delegate;
    if (delegate == null) {
      return _providerNotReady(key: key, defaultValue: defaultValue);
    }
    return _trackRumEvaluation(
      delegate.getBooleanDetails(key: key, defaultValue: defaultValue),
    );
  }

  @override
  FlagDetails<String> getStringDetails({
    required String key,
    required String defaultValue,
  }) {
    final delegate = _delegate;
    if (delegate == null) {
      return _providerNotReady(key: key, defaultValue: defaultValue);
    }
    return _trackRumEvaluation(
      delegate.getStringDetails(key: key, defaultValue: defaultValue),
    );
  }

  @override
  FlagDetails<int> getIntegerDetails({
    required String key,
    required int defaultValue,
  }) {
    final delegate = _delegate;
    if (delegate == null) {
      return _providerNotReady(key: key, defaultValue: defaultValue);
    }
    return _trackRumEvaluation(
      delegate.getIntegerDetails(key: key, defaultValue: defaultValue),
    );
  }

  @override
  FlagDetails<double> getDoubleDetails({
    required String key,
    required double defaultValue,
  }) {
    final delegate = _delegate;
    if (delegate == null) {
      return _providerNotReady(key: key, defaultValue: defaultValue);
    }
    return _trackRumEvaluation(
      delegate.getDoubleDetails(key: key, defaultValue: defaultValue),
    );
  }

  @override
  FlagDetails<Object?> getObjectDetails({
    required String key,
    required Object? defaultValue,
  }) {
    final delegate = _delegate;
    if (delegate == null) {
      return _providerNotReady(key: key, defaultValue: defaultValue);
    }
    return _trackRumEvaluation(
      delegate.getObjectDetails(key: key, defaultValue: defaultValue),
    );
  }

  @override
  Future<void> reset() async {
    final delegate = await _delegateOrResolve();
    await delegate.reset();
  }

  @override
  Future<void> shutdown() async {
    final delegate = _delegate;
    if (delegate == null) {
      return;
    }
    await delegate.shutdown();
    _delegate = null;
  }

  Future<DatadogFlagsClient> _delegateOrResolve() async {
    final existing = _delegate;
    if (existing != null) {
      return existing;
    }
    final resolved = await _resolveDelegate();
    _delegate = resolved;
    return resolved;
  }

  FlagDetails<T> _trackRumEvaluation<T>(FlagDetails<T> details) {
    final variant = details.variant;
    if (_rumIntegrationEnabled && details.error == null && variant != null) {
      _addRumFeatureFlagEvaluation(details.key, variant);
    }
    return details;
  }

  FlagDetails<T> _providerNotReady<T>({
    required String key,
    required T defaultValue,
  }) {
    return FlagDetails(
      key: key,
      value: defaultValue,
      error: FlagEvaluationError.providerNotReady,
    );
  }
}

DatadogFlagsSite? _flagsSiteFor(DatadogSite site) {
  return switch (site) {
    DatadogSite.us1 => DatadogFlagsSite.us1,
    DatadogSite.us3 => DatadogFlagsSite.us3,
    DatadogSite.us5 => DatadogFlagsSite.us5,
    DatadogSite.eu1 => DatadogFlagsSite.eu1,
    DatadogSite.ap1 => DatadogFlagsSite.ap1,
    DatadogSite.ap2 => DatadogFlagsSite.ap2,
    DatadogSite.us1Fed => null,
  };
}
