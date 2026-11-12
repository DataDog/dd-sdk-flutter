// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';

import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart'
    as openfeature;

import 'datadog_flags.dart';
import 'default_flags_client.dart';
import 'evaluation_context.dart';
import 'flags_client.dart';
import 'flags_configuration.dart';
import 'flags_error.dart';

/// An OpenFeature provider backed by the pure-Dart Datadog Flags runtime.
///
/// One provider instance owns one OpenFeature domain. Context reconciliation
/// creates a candidate Datadog runtime and swaps it into use only after
/// assignments for the new context are available. Attribute-only changes retain
/// assignments while loading or after failure. Targeting-key changes return
/// application defaults until assignments for the new key are available.
/// The boolean context attribute `dd_strict_evaluation_context_switching`
/// also requires matching targeting attributes. It is a local control field.
final class DatadogProvider
    implements
        openfeature.FeatureProvider,
        openfeature.InitializableProvider,
        openfeature.ContextReconciliationProvider,
        openfeature.ShutdownProvider,
        openfeature.ProviderEventSource,
        openfeature.DomainScopedProvider {
  /// OpenFeature flag metadata key containing the Datadog allocation key.
  static const allocationKeyMetadata = datadogAllocationKeyMetadata;

  /// OpenFeature flag metadata key containing the Datadog assignment serial ID.
  static const serialIdMetadata = datadogSerialIdMetadata;

  /// Metadata key containing the assignment logging policy.
  static const doLogMetadata = datadogDoLogMetadata;

  /// Largest initialization budget accepted by this provider.
  ///
  /// The budget must expire before OpenFeature's 30-second lifecycle deadline.
  /// An isolated API with a shorter deadline must use a smaller budget.
  static const maxInitializationTimeout = Duration(seconds: 20);

  final Set<Future<void>> _retiring = {};
  openfeature.EvaluationContext? _requestedContext;

  /// Datadog runtime configuration used by each context revision.
  final DatadogFlagsConfiguration configuration;

  final StreamController<openfeature.ProviderEvent> _events =
      StreamController<openfeature.ProviderEvent>.broadcast(sync: true);

  _ProviderRuntime? _activeRuntime;
  _ProviderRuntime? _telemetrySource;
  _ProviderRuntime? _pendingRuntime;
  bool _requiresContextRetry = false;
  bool _hasCommittedContext = false;
  bool _requiresFreshAssignments = false;
  var _contextRevision = 0;
  var _shutdownGeneration = 0;
  Future<void>? _contextOperation;
  String? _resolvedClientName;

  /// Creates a provider from a Datadog runtime configuration.
  ///
  /// The domain name identifies stored snapshots. The default domain uses
  /// [DatadogFlags.defaultClientName].
  DatadogProvider.fromConfiguration(this.configuration);

  @override
  Stream<openfeature.ProviderEvent> get events => _events.stream;

  @override
  openfeature.ProviderMetadata get metadata =>
      const openfeature.ProviderMetadata(name: 'datadog');

  @override
  Future<void> initialize(
    openfeature.EvaluationContext context, {
    String? domain,
  }) async {
    _requestedContext = context;
    _requiresContextRetry = false;
    _resolvedClientName = domain ?? DatadogFlags.defaultClientName;
    await _runContextOperation(context, isInitialization: true);
  }

  @override
  Future<void> onContextChanged(
    openfeature.EvaluationContext previousContext,
    openfeature.EvaluationContext newContext,
  ) async {
    // OpenFeature commits its context only after successful reconciliation.
    _requestedContext = newContext;
    _requiresContextRetry = true;
    final requested = newContext.datadogContext;
    final retained = _telemetrySource;
    final retainedContext = retained?.client.evaluationContext;
    if (_activeRuntime == null &&
        retained != null &&
        retainedContext != null &&
        !_requiresFreshAssignments &&
        (retainedContext.targetingKey ?? '') ==
            (requested.targetingKey ?? '') &&
        (!requested.strictContextSwitching ||
            targetingContextsMatch(retainedContext, requested))) {
      _activeRuntime = retained;
      _telemetrySource = null;
    }
    final active = _activeRuntime;
    final activeKey = active?.client.evaluationContext?.targetingKey ?? '';
    if (active != null &&
        ((newContext.targetingKey ?? '') != activeKey ||
            (requested.strictContextSwitching &&
                !targetingContextsMatch(
                  active.client.evaluationContext ??
                      FlagsEvaluationContext.empty,
                  requested,
                )))) {
      _withholdActiveAssignments();
    }
    _events.add(
      openfeature.ProviderEvent(
        type: openfeature.ProviderEventType.reconciling,
      ),
    );
    await _runContextOperation(newContext, isInitialization: false);
  }

  /// Refreshes assignments for the active context.
  ///
  /// Waits for pending initialization or context reconciliation. After failed
  /// reconciliation, retry the context change through OpenFeature before refreshing.
  ///
  /// Before assignments have been activated, retries the initial context.
  /// Activation emits ready, followed by stale when using stored assignments.
  /// It does not emit configuration-changed. Failure without usable assignments
  /// emits error. A retry replaces the pending initial assignment request.
  /// Avoid retrying from every error event.
  ///
  /// After assignments have been activated, a successful refresh emits ready
  /// followed by configuration-changed. A failed refresh preserves usable
  /// assignments by default and emits error then stale. In strict mode, failure
  /// emits error and withholds assignments until a successful fetch.
  /// A retry keeps those assignments withheld.
  /// Throws [StateError] before initialization, after shutdown, or after failed
  /// context reconciliation.
  Future<void> refresh() async {
    final generation = _shutdownGeneration;
    while (_contextOperation != null) {
      await _contextOperation;
      if (generation != _shutdownGeneration) break;
    }
    if (generation != _shutdownGeneration) {
      throw StateError('The provider shut down while refresh was waiting.');
    }
    final context = _requestedContext;
    if (context == null || _requiresContextRetry) {
      throw StateError(
        'Initialize or reconcile the provider before refreshing assignments.',
      );
    }
    await _loadContext(
      context,
      isInitialization: !_hasCommittedContext,
      isRefresh: _hasCommittedContext,
    );
  }

  @override
  Future<void> shutdown() async {
    _shutdownGeneration += 1;
    _contextRevision += 1;
    final activeRuntime = _activeRuntime;
    final pendingRuntime = _pendingRuntime;
    final telemetrySource = _telemetrySource;
    _activeRuntime = null;
    _pendingRuntime = null;
    _resolvedClientName = null;
    _requestedContext = null;
    _requiresContextRetry = false;
    _hasCommittedContext = false;
    _requiresFreshAssignments = false;
    _telemetrySource = null;
    await Future.wait([
      ..._retiring,
      if (activeRuntime != null) _disableQuietly(activeRuntime),
      if (telemetrySource != null && !identical(telemetrySource, activeRuntime))
        _disableQuietly(telemetrySource),
      if (pendingRuntime != null && !identical(pendingRuntime, activeRuntime))
        _disableQuietly(pendingRuntime),
    ]);
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

    final details = client.getStructureDetails(
      key: flagKey,
      defaultValue: defaultValue,
    );
    final errorCode = details.error?.openFeatureCode;
    if (errorCode != null) {
      return openfeature.ResolutionDetails(
        value: defaultValue,
        errorCode: errorCode,
        errorMessage: details.error!.message,
        reason: 'ERROR',
        flagMetadata: details.flagMetadata,
      );
    }

    return openfeature.ResolutionDetails(
      value: _immutableJsonValue(details.value) as Map<String, Object?>,
      reason: details.reason,
      variant: details.variant,
      flagMetadata: details.flagMetadata,
    );
  }

  Future<void> _runContextOperation(
    openfeature.EvaluationContext context, {
    required bool isInitialization,
  }) {
    late final Future<void> operation;
    operation = _loadContext(context, isInitialization: isInitialization)
        .whenComplete(() {
          if (identical(_contextOperation, operation)) {
            _contextOperation = null;
          }
        });
    _contextOperation = operation;
    return operation;
  }

  Future<void> _loadContext(
    openfeature.EvaluationContext context, {
    required bool isInitialization,
    bool isRefresh = false,
  }) async {
    final revision = ++_contextRevision;
    final previousPending = _pendingRuntime;
    _pendingRuntime = null;
    _retire(previousPending);
    if (revision != _contextRevision) {
      return;
    }

    if (configuration.datadogConfig == null) {
      _emitLoadError('Datadog Flags configuration is required.', fatal: true);
      return;
    }

    final budget = configuration.initializationTimeout;
    if (budget == null ||
        budget <= Duration.zero ||
        budget > maxInitializationTimeout) {
      _emitLoadError(
        'initializationTimeout must be positive and at most '
        '${maxInitializationTimeout.inSeconds} seconds. It must expire '
        'before the OpenFeature lifecycle timeout.',
        fatal: true,
      );
      return;
    }

    final owner = DatadogFlags();
    _ProviderRuntime? runtime;
    var initializationReturned = false;
    try {
      await owner.enable(configuration: configuration);
      if (revision != _contextRevision) {
        await _disableOwnerQuietly(owner);
        return;
      }
      final client = owner.sharedClient(
        name: _resolvedClientName ?? DatadogFlags.defaultClientName,
      );
      if (client is! DefaultDatadogFlagsClient) {
        await _disableOwnerQuietly(owner);
        _emitLoadError(
          'The Datadog client does not expose assignment lifecycle state.',
        );
        return;
      }

      final lifecycle = client as DatadogFlagsClientLifecycle;
      final candidate = _ProviderRuntime(owner, client);
      runtime = candidate;
      _pendingRuntime = candidate;
      candidate.statusSubscription = lifecycle.statusChanges.listen((status) {
        if (initializationReturned) {
          unawaited(
            _handleLateStatus(
              candidate,
              status,
              revision: revision,
              isInitialization: isInitialization,
            ),
          );
        }
      });

      try {
        await client.initialize(context.datadogContext);
      } on FlagsInitializationTimeoutException {
        // The core operation continues. Published assignments are usable even
        // when storage is still pending; initial late success can recover.
      }
      initializationReturned = true;
      await _handleCompletedInitialization(
        candidate,
        lifecycle.status,
        revision: revision,
        isInitialization: isInitialization,
        isRefresh: isRefresh,
      );
    } on Object catch (error) {
      initializationReturned = false;
      if (runtime != null) {
        if (identical(_pendingRuntime, runtime)) {
          _pendingRuntime = null;
        }
        if (!identical(_activeRuntime, runtime)) {
          await _disableQuietly(runtime);
        }
      } else if (!identical(_activeRuntime?.owner, owner)) {
        await _disableOwnerQuietly(owner);
      }
      if (revision == _contextRevision) {
        _emitLoadError('Datadog provider initialization failed: $error');
      }
    }
  }

  Future<void> _handleCompletedInitialization(
    _ProviderRuntime runtime,
    DatadogFlagsClientStatus status, {
    required int revision,
    required bool isInitialization,
    bool isRefresh = false,
  }) async {
    if (!_isCurrent(runtime, revision)) {
      if (!identical(_activeRuntime, runtime)) {
        await _disableQuietly(runtime);
      }
      return;
    }

    if (isInitialization &&
        _requiresFreshAssignments &&
        (status == DatadogFlagsClientStatus.notReady ||
            status == DatadogFlagsClientStatus.stale)) {
      _emitLoadError(
        'Fresh Datadog assignments are not available before the initialization deadline.',
      );
      return;
    }

    if ((isRefresh || _requiresFreshAssignments) &&
        status != DatadogFlagsClientStatus.ready) {
      _pendingRuntime = null;
      _retire(runtime);
      if (_requestedContext?.datadogContext.strictContextSwitching ?? false) {
        _requiresFreshAssignments = true;
        _withholdActiveAssignments();
      }
      _emitLoadError(
        _loadMessage(
          runtime,
          isRefresh
              ? 'Datadog assignment refresh failed.'
              : 'Datadog context reconciliation failed.',
        ),
      );
      if (_activeRuntime != null) {
        _events.add(
          openfeature.ProviderEvent(
            type: openfeature.ProviderEventType.stale,
            message: 'Using existing Datadog assignments.',
          ),
        );
      }
      return;
    }

    switch (status) {
      case DatadogFlagsClientStatus.ready:
      case DatadogFlagsClientStatus.stale:
        await _activateRuntime(
          runtime,
          status,
          revision: revision,
          isInitialization: isInitialization,
          isRefresh: isRefresh,
        );
      case DatadogFlagsClientStatus.notReady:
        if (!isInitialization) {
          // OpenFeature retains its active context when reconciliation fails.
          // A late candidate cannot silently change that context afterwards.
          _pendingRuntime = null;
          _retire(runtime);
        }
        _emitLoadError(
          'Datadog assignments are not available before the initialization '
          'deadline.',
        );
      case DatadogFlagsClientStatus.error:
        if (_requestedContext?.datadogContext.strictContextSwitching ?? false) {
          _requiresFreshAssignments = true;
          _withholdActiveAssignments();
        }
        _pendingRuntime = null;
        await _disableQuietly(runtime);
        if (revision == _contextRevision) {
          _emitLoadError(
            _loadMessage(
              runtime,
              'Datadog assignments are not available for the requested context.',
            ),
          );
        }
    }
  }

  Future<void> _handleLateStatus(
    _ProviderRuntime runtime,
    DatadogFlagsClientStatus status, {
    required int revision,
    required bool isInitialization,
  }) async {
    if (!_isCurrent(runtime, revision)) {
      if (!identical(_activeRuntime, runtime)) {
        await _disableQuietly(runtime);
      }
      return;
    }

    if (identical(_activeRuntime, runtime)) {
      if (status == DatadogFlagsClientStatus.ready) {
        _requiresFreshAssignments = false;
        _events.add(
          openfeature.ProviderEvent(type: openfeature.ProviderEventType.ready),
        );
      } else if (status == DatadogFlagsClientStatus.error) {
        _requiresFreshAssignments = true;
        _withholdActiveAssignments();
        _emitLoadError(
          _loadMessage(runtime, 'Datadog assignment loading failed.'),
        );
      }
      return;
    }

    if (!isInitialization) {
      if (status != DatadogFlagsClientStatus.notReady) {
        _pendingRuntime = null;
        await _disableQuietly(runtime);
      }
      return;
    }

    switch (status) {
      case DatadogFlagsClientStatus.ready:
      case DatadogFlagsClientStatus.stale:
        await _activateRuntime(
          runtime,
          status,
          revision: revision,
          isInitialization: true,
        );
      case DatadogFlagsClientStatus.error:
        _pendingRuntime = null;
        await _disableQuietly(runtime);
      case DatadogFlagsClientStatus.notReady:
        return;
    }
  }

  Future<void> _activateRuntime(
    _ProviderRuntime runtime,
    DatadogFlagsClientStatus status, {
    required int revision,
    required bool isInitialization,
    bool isRefresh = false,
  }) async {
    if (!_isCurrent(runtime, revision)) {
      if (!identical(_activeRuntime, runtime)) {
        await _disableQuietly(runtime);
      }
      return;
    }

    final previous = _activeRuntime;
    final telemetrySource = previous ?? _telemetrySource;
    _telemetrySource = null;
    if (telemetrySource != null && !identical(telemetrySource, runtime)) {
      runtime.client.inheritTelemetry(telemetrySource.client);
    }
    _activeRuntime = runtime;
    _hasCommittedContext = true;
    if (status == DatadogFlagsClientStatus.ready) {
      _requiresFreshAssignments = false;
    }
    if (!isRefresh) _requiresContextRetry = false;
    if (identical(_pendingRuntime, runtime)) {
      _pendingRuntime = null;
    }
    if (isRefresh) {
      _events.add(
        openfeature.ProviderEvent(type: openfeature.ProviderEventType.ready),
      );
    }
    _events.add(
      openfeature.ProviderEvent(
        type: isRefresh
            ? openfeature.ProviderEventType.configurationChanged
            : isInitialization
            ? openfeature.ProviderEventType.ready
            : openfeature.ProviderEventType.contextChanged,
      ),
    );
    if (status == DatadogFlagsClientStatus.stale &&
        _isCurrent(runtime, revision) &&
        runtime.client.status == DatadogFlagsClientStatus.stale) {
      _events.add(
        openfeature.ProviderEvent(
          type: openfeature.ProviderEventType.stale,
          message: _loadMessage(
            runtime,
            'Using existing Datadog assignments. Fresh assignments are not available.',
          ),
        ),
      );
    }
    if (telemetrySource != null && !identical(telemetrySource, runtime)) {
      _retire(telemetrySource);
    }
  }

  void _withholdActiveAssignments() {
    final active = _activeRuntime;
    if (active == null) return;
    _activeRuntime = null;
    _telemetrySource = active;
    unawaited(active.statusSubscription?.cancel());
    active.statusSubscription = null;
  }

  bool _isCurrent(_ProviderRuntime runtime, int revision) {
    return revision == _contextRevision &&
        (identical(_activeRuntime, runtime) ||
            identical(_pendingRuntime, runtime));
  }

  void _retire(_ProviderRuntime? runtime) {
    if (runtime == null) return;
    final retiring = _disableQuietly(runtime);
    _retiring.add(retiring);
    unawaited(retiring.whenComplete(() => _retiring.remove(retiring)));
  }

  static Future<void> _disableQuietly(_ProviderRuntime? runtime) async {
    try {
      await runtime?.disable();
    } on Object {
      // Assignment readiness must not be replaced by a teardown error from an
      // inactive runtime. Datadog runtime shutdown already bounds its uploads.
    }
  }

  static Future<void> _disableOwnerQuietly(DatadogFlags owner) async {
    try {
      await owner.disable();
    } on Object {
      // Preserve the assignment lifecycle result when cleanup also fails.
    }
  }

  String _loadMessage(_ProviderRuntime runtime, String message) {
    final error = runtime.client.lastLoadError;
    if (error is FlagsException && error.type == FlagsErrorType.networkError) {
      return '$message ${error.message}';
    }
    if (error is FlagsException) return '$message ${error.type.name}.';
    return message;
  }

  void _emitLoadError(String message, {bool fatal = false}) {
    _events.add(
      openfeature.ProviderEvent(
        type: openfeature.ProviderEventType.error,
        errorCode: fatal
            ? openfeature.ErrorCode.providerFatal
            : openfeature.ErrorCode.general,
        message: message,
      ),
    );
  }

  static openfeature.ResolutionDetails<T> _resolution<T extends Object>(
    FlagDetails<T> details,
    T defaultValue,
  ) {
    final errorCode = details.error?.openFeatureCode;
    return openfeature.ResolutionDetails(
      value: errorCode == null ? details.value : defaultValue,
      errorCode: errorCode,
      errorMessage: details.error?.message,
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

  static Object? _immutableJsonValue(Object? value) {
    if (value is Map<String, Object?>) {
      return Map<String, Object?>.unmodifiable(
        value.map((key, child) => MapEntry(key, _immutableJsonValue(child))),
      );
    }
    if (value is List<Object?>) {
      return List<Object?>.unmodifiable(value.map(_immutableJsonValue));
    }
    return value;
  }
}

final class _ProviderRuntime {
  final DatadogFlags owner;
  final DefaultDatadogFlagsClient client;
  StreamSubscription<DatadogFlagsClientStatus>? statusSubscription;
  Future<void>? _disabling;

  _ProviderRuntime(this.owner, this.client);

  Future<void> disable() => _disabling ??= _disable();

  Future<void> _disable() async {
    await statusSubscription?.cancel();
    await owner.disable();
  }
}

extension _DatadogContext on openfeature.EvaluationContext {
  FlagsEvaluationContext get datadogContext => FlagsEvaluationContext(
    targetingKey: targetingKey,
    attributes: {
      for (final MapEntry(:key, :value) in attributes.entries)
        key: _jsonAttribute(value),
    },
  );
}

extension _OpenFeatureError on FlagEvaluationError {
  openfeature.ErrorCode get openFeatureCode => switch (this) {
    FlagEvaluationError.providerNotReady =>
      openfeature.ErrorCode.providerNotReady,
    FlagEvaluationError.flagNotFound => openfeature.ErrorCode.flagNotFound,
    FlagEvaluationError.typeMismatch => openfeature.ErrorCode.typeMismatch,
  };

  String get message => 'Datadog flag evaluation failed with $code.';
}

Object? _jsonAttribute(Object? value) => switch (value) {
  DateTime() => value.toUtc().toIso8601String(),
  double() when !value.isFinite => null,
  Map<String, Object?>() => {
    for (final MapEntry(:key, :value) in value.entries)
      key: _jsonAttribute(value),
  },
  List<Object?>() => [for (final item in value) _jsonAttribute(item)],
  _ => value,
};
