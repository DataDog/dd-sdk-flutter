// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';

import 'package:datadog_flags/datadog_flags.dart' as datadog;
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart'
    as openfeature;

/// An OpenFeature provider backed by the pure-Dart Datadog Flags runtime.
///
/// One provider instance owns one OpenFeature domain. Context reconciliation
/// creates a candidate Datadog runtime and swaps it into use only after
/// assignments for the new context are available. Evaluations therefore keep
/// using the previous context while reconciliation is in progress or fails.
final class DatadogOpenFeatureProvider
    implements
        openfeature.FeatureProvider,
        openfeature.InitializableProvider,
        openfeature.ContextReconciliationProvider,
        openfeature.ShutdownProvider,
        openfeature.ProviderEventSource,
        openfeature.DomainScopedProvider {
  /// OpenFeature flag metadata key containing the Datadog allocation key.
  static const allocationKeyMetadata = 'datadog.allocation_key';

  /// OpenFeature flag metadata key containing the Datadog assignment serial ID.
  static const serialIdMetadata = 'datadog.serial_id';

  /// Datadog runtime configuration used by each context revision.
  final datadog.DatadogFlagsConfiguration configuration;

  /// Explicit Datadog client name, or `null` to derive it from the domain.
  final String? clientName;
  final StreamController<openfeature.ProviderEvent> _events =
      StreamController<openfeature.ProviderEvent>.broadcast(sync: true);

  _ProviderRuntime? _activeRuntime;
  String? _resolvedClientName;

  /// Creates a provider that owns its Datadog runtime lifecycle.
  ///
  /// When [clientName] is omitted, a domain binding uses its domain as the
  /// Datadog client name and the default binding uses
  /// [datadog.DatadogFlags.defaultClientName].
  DatadogOpenFeatureProvider({required this.configuration, this.clientName});

  @override
  Stream<openfeature.ProviderEvent> get events => _events.stream;

  @override
  openfeature.ProviderMetadata get metadata =>
      const openfeature.ProviderMetadata(name: 'Datadog');

  @override
  Future<void> initialize(
    openfeature.EvaluationContext context, {
    String? domain,
  }) async {
    _resolvedClientName =
        clientName ?? domain ?? datadog.DatadogFlags.defaultClientName;
    await _loadContext(context, isInitialization: true);
  }

  @override
  Future<void> onContextChanged(
    openfeature.EvaluationContext previousContext,
    openfeature.EvaluationContext newContext,
  ) async {
    _events.add(
      openfeature.ProviderEvent(
        type: openfeature.ProviderEventType.reconciling,
      ),
    );
    await _loadContext(newContext, isInitialization: false);
  }

  @override
  Future<void> shutdown() async {
    final activeRuntime = _activeRuntime;
    _activeRuntime = null;
    _resolvedClientName = null;
    await activeRuntime?.owner.disable();
  }

  @override
  openfeature.ResolutionDetails<bool> resolveBooleanValue(
    String flagKey,
    bool defaultValue,
    openfeature.EvaluationContext context,
  ) {
    final client = _activeRuntime?.client;
    if (client == null) {
      return _notReady(defaultValue);
    }
    return _resolution(
      client.getBooleanDetails(key: flagKey, defaultValue: defaultValue),
      defaultValue,
    );
  }

  @override
  openfeature.ResolutionDetails<String> resolveStringValue(
    String flagKey,
    String defaultValue,
    openfeature.EvaluationContext context,
  ) {
    final client = _activeRuntime?.client;
    if (client == null) {
      return _notReady(defaultValue);
    }
    return _resolution(
      client.getStringDetails(key: flagKey, defaultValue: defaultValue),
      defaultValue,
    );
  }

  @override
  openfeature.ResolutionDetails<int> resolveIntegerValue(
    String flagKey,
    int defaultValue,
    openfeature.EvaluationContext context,
  ) {
    final client = _activeRuntime?.client;
    if (client == null) {
      return _notReady(defaultValue);
    }
    return _resolution(
      client.getIntegerDetails(key: flagKey, defaultValue: defaultValue),
      defaultValue,
    );
  }

  @override
  openfeature.ResolutionDetails<double> resolveDoubleValue(
    String flagKey,
    double defaultValue,
    openfeature.EvaluationContext context,
  ) {
    final client = _activeRuntime?.client;
    if (client == null) {
      return _notReady(defaultValue);
    }
    return _resolution(
      client.getDoubleDetails(key: flagKey, defaultValue: defaultValue),
      defaultValue,
    );
  }

  @override
  openfeature.ResolutionDetails<Map<String, Object?>> resolveStructureValue(
    String flagKey,
    Map<String, Object?> defaultValue,
    openfeature.EvaluationContext context,
  ) {
    final client = _activeRuntime?.client;
    if (client == null) {
      return _notReady(defaultValue);
    }

    final details = client.getObjectDetails(
      key: flagKey,
      defaultValue: defaultValue,
    );
    final errorCode = _errorCode(details.error);
    if (errorCode != null) {
      return openfeature.ResolutionDetails(
        value: defaultValue,
        errorCode: errorCode,
        errorMessage: _errorMessage(details.error!),
        reason: 'ERROR',
        flagMetadata: details.flagMetadata,
      );
    }

    final value = details.value;
    if (value is! Map<String, Object?>) {
      return openfeature.ResolutionDetails(
        value: defaultValue,
        errorCode: openfeature.ErrorCode.typeMismatch,
        errorMessage: 'Datadog flag "$flagKey" is not a structure.',
        reason: 'ERROR',
        flagMetadata: details.flagMetadata,
      );
    }

    return openfeature.ResolutionDetails(
      value: _immutableStructure(value),
      reason: details.reason,
      variant: details.variant,
      flagMetadata: details.flagMetadata,
    );
  }

  Future<void> _loadContext(
    openfeature.EvaluationContext context, {
    required bool isInitialization,
  }) async {
    final owner = datadog.DatadogFlags();
    try {
      await owner.enable(configuration: configuration);
      final client = owner.sharedClient(
        name: _resolvedClientName ?? datadog.DatadogFlags.defaultClientName,
      );
      await client.initialize(_datadogContext(context));

      if (client is! datadog.DatadogFlagsClientLifecycle) {
        await _disableQuietly(owner);
        _emitLoadError(
          'The Datadog client does not expose assignment lifecycle state.',
        );
        return;
      }

      final lifecycle = client as datadog.DatadogFlagsClientLifecycle;
      final status = lifecycle.status;
      if (status != datadog.DatadogFlagsClientStatus.ready &&
          status != datadog.DatadogFlagsClientStatus.stale) {
        await _disableQuietly(owner);
        _emitLoadError(
          'Datadog assignments are not available for the requested context.',
        );
        return;
      }

      final previous = _activeRuntime;
      _activeRuntime = _ProviderRuntime(owner, client);
      _events.add(
        openfeature.ProviderEvent(
          type: isInitialization
              ? openfeature.ProviderEventType.ready
              : openfeature.ProviderEventType.contextChanged,
        ),
      );
      if (status == datadog.DatadogFlagsClientStatus.stale) {
        _events.add(
          openfeature.ProviderEvent(
            type: openfeature.ProviderEventType.stale,
            message: 'Using stored Datadog assignments because refresh failed.',
          ),
        );
      }
      await _disableQuietly(previous?.owner);
    } on Object catch (error) {
      if (!identical(_activeRuntime?.owner, owner)) {
        await _disableQuietly(owner);
      }
      _emitLoadError('Datadog provider initialization failed: $error');
    }
  }

  static Future<void> _disableQuietly(datadog.DatadogFlags? owner) async {
    try {
      await owner?.disable();
    } on Object {
      // Assignment readiness must not be replaced by a teardown error from an
      // inactive runtime. Datadog runtime shutdown already bounds its uploads.
    }
  }

  void _emitLoadError(String message) {
    _events.add(
      openfeature.ProviderEvent(
        type: openfeature.ProviderEventType.error,
        errorCode: openfeature.ErrorCode.general,
        message: message,
      ),
    );
  }

  static datadog.FlagsEvaluationContext _datadogContext(
    openfeature.EvaluationContext context,
  ) {
    return datadog.FlagsEvaluationContext(
      targetingKey: context.targetingKey,
      attributes: context.attributes,
    );
  }

  static openfeature.ResolutionDetails<T> _resolution<T extends Object>(
    datadog.FlagDetails<T> details,
    T defaultValue,
  ) {
    final errorCode = _errorCode(details.error);
    return openfeature.ResolutionDetails(
      value: errorCode == null ? details.value : defaultValue,
      errorCode: errorCode,
      errorMessage: details.error == null
          ? null
          : _errorMessage(details.error!),
      reason: errorCode == null ? details.reason : 'ERROR',
      variant: details.variant,
      flagMetadata: details.flagMetadata,
    );
  }

  static openfeature.ResolutionDetails<T> _notReady<T extends Object>(
    T defaultValue,
  ) {
    return openfeature.ResolutionDetails(
      value: defaultValue,
      errorCode: openfeature.ErrorCode.providerNotReady,
      errorMessage: 'The Datadog provider has not loaded assignments.',
      reason: 'ERROR',
    );
  }

  static openfeature.ErrorCode? _errorCode(datadog.FlagEvaluationError? error) {
    return switch (error) {
      null => null,
      datadog.FlagEvaluationError.providerNotReady =>
        openfeature.ErrorCode.providerNotReady,
      datadog.FlagEvaluationError.flagNotFound =>
        openfeature.ErrorCode.flagNotFound,
      datadog.FlagEvaluationError.typeMismatch =>
        openfeature.ErrorCode.typeMismatch,
    };
  }

  static String _errorMessage(datadog.FlagEvaluationError error) {
    return 'Datadog flag evaluation failed with ${error.code}.';
  }

  static Map<String, Object?> _immutableStructure(Map<String, Object?> value) {
    return Map<String, Object?>.unmodifiable(
      value.map((key, child) => MapEntry(key, _immutableJsonValue(child))),
    );
  }

  static Object? _immutableJsonValue(Object? value) {
    if (value is Map<String, Object?>) {
      return _immutableStructure(value);
    }
    if (value is List<Object?>) {
      return List<Object?>.unmodifiable(value.map(_immutableJsonValue));
    }
    return value;
  }
}

final class _ProviderRuntime {
  final datadog.DatadogFlags owner;
  final datadog.DatadogFlagsClient client;

  const _ProviderRuntime(this.owner, this.client);
}
