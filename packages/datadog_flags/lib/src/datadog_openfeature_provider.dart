// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';

import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart'
    as openfeature;

import 'datadog_flags.dart' as datadog;
import 'default_flags_client.dart' as datadog;
import 'evaluation_context.dart' as datadog;
import 'flags_client.dart' as datadog;
import 'flags_configuration.dart' as datadog;
import 'flags_error.dart' as datadog;

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
  static const allocationKeyMetadata = datadog.datadogAllocationKeyMetadata;

  /// OpenFeature flag metadata key containing the Datadog assignment serial ID.
  static const serialIdMetadata = datadog.datadogSerialIdMetadata;

  /// Largest initialization budget accepted by this provider.
  ///
  /// The budget must expire before OpenFeature's 30-second lifecycle deadline.
  /// An isolated API with a shorter deadline must use a smaller budget.
  static const maxInitializationTimeout = Duration(seconds: 20);

  final Set<Future<void>> _retiring = {};
  openfeature.EvaluationContext? _requestedContext;

  /// Datadog runtime configuration used by each context revision.
  final datadog.DatadogFlagsConfiguration configuration;

  /// Explicit Datadog client name, or `null` to derive it from the domain.
  final String? clientName;
  final StreamController<openfeature.ProviderEvent> _events =
      StreamController<openfeature.ProviderEvent>.broadcast(sync: true);

  _ProviderRuntime? _activeRuntime;
  _ProviderRuntime? _pendingRuntime;
  var _contextRevision = 0;
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
    _requestedContext = context;
    _resolvedClientName =
        clientName ?? domain ?? datadog.DatadogFlags.defaultClientName;
    await _loadContext(context, isInitialization: true);
  }

  @override
  Future<void> onContextChanged(
    openfeature.EvaluationContext previousContext,
    openfeature.EvaluationContext newContext,
  ) async {
    _requestedContext = newContext;
    // Sign-out must retire private assignments even if anonymous loading fails.
    if (newContext.targetingKey == null) {
      final previous = _activeRuntime;
      _activeRuntime = null;
      _retire(previous);
    }
    _events.add(
      openfeature.ProviderEvent(
        type: openfeature.ProviderEventType.reconciling,
      ),
    );
    await _loadContext(newContext, isInitialization: false);
  }

  /// Refreshes assignments for the active context.
  ///
  /// Before the first successful load, uses the requested initial context.
  ///
  /// A successful refresh emits a configuration-changed event. A failed
  /// refresh emits an error and preserves assignments for the active context.
  Future<void> refresh() async {
    final activeContext = _activeRuntime?.client.evaluationContext;
    final context = activeContext == null
        ? _requestedContext
        : openfeature.EvaluationContext(
            targetingKey: activeContext.targetingKey,
            attributes: activeContext.attributes,
          );
    if (context == null) {
      throw StateError(
        'Initialize the provider before refreshing assignments.',
      );
    }
    await _loadContext(context, isInitialization: false, isRefresh: true);
  }

  @override
  Future<void> shutdown() async {
    _contextRevision += 1;
    final activeRuntime = _activeRuntime;
    final pendingRuntime = _pendingRuntime;
    _activeRuntime = null;
    _pendingRuntime = null;
    _resolvedClientName = null;
    _requestedContext = null;
    await Future.wait([
      ..._retiring,
      if (activeRuntime != null) _disableQuietly(activeRuntime),
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

    return openfeature.ResolutionDetails(
      value: _immutableStructure(details.value),
      reason: details.reason,
      variant: details.variant,
      flagMetadata: details.flagMetadata,
    );
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
      _emitLoadError('Datadog Flags configuration is required.');
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
      );
      return;
    }

    final owner = datadog.DatadogFlags();
    _ProviderRuntime? runtime;
    var initializationReturned = false;
    try {
      await owner.enable(configuration: configuration);
      if (revision != _contextRevision) {
        await _disableOwnerQuietly(owner);
        return;
      }
      final client = owner.sharedClient(
        name: _resolvedClientName ?? datadog.DatadogFlags.defaultClientName,
      );
      if (client is! datadog.DefaultDatadogFlagsClient) {
        await _disableOwnerQuietly(owner);
        _emitLoadError(
          'The Datadog client does not expose assignment lifecycle state.',
        );
        return;
      }

      final lifecycle = client as datadog.DatadogFlagsClientLifecycle;
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
        await client.initialize(_datadogContext(context));
      } on datadog.FlagsInitializationTimeoutException {
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
    datadog.DatadogFlagsClientStatus status, {
    required int revision,
    required bool isInitialization,
    bool isRefresh = false,
  }) async {
    if (!_isCurrent(runtime, revision)) {
      await _disableQuietly(runtime);
      return;
    }

    if (isRefresh && status == datadog.DatadogFlagsClientStatus.stale) {
      _pendingRuntime = null;
      _retire(runtime);
      _emitLoadError('Datadog assignment refresh failed.');
      _events.add(
        openfeature.ProviderEvent(
          type: openfeature.ProviderEventType.stale,
          message: 'Using existing Datadog assignments.',
        ),
      );
      return;
    }

    switch (status) {
      case datadog.DatadogFlagsClientStatus.ready:
      case datadog.DatadogFlagsClientStatus.stale:
        await _activateRuntime(
          runtime,
          status,
          revision: revision,
          isInitialization: isInitialization,
          isRefresh: isRefresh,
        );
      case datadog.DatadogFlagsClientStatus.notReady:
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
      case datadog.DatadogFlagsClientStatus.error:
        _pendingRuntime = null;
        await _disableQuietly(runtime);
        if (revision == _contextRevision) {
          _emitLoadError(
            'Datadog assignments are not available for the requested context.',
          );
        }
    }
  }

  Future<void> _handleLateStatus(
    _ProviderRuntime runtime,
    datadog.DatadogFlagsClientStatus status, {
    required int revision,
    required bool isInitialization,
  }) async {
    if (!_isCurrent(runtime, revision)) {
      await _disableQuietly(runtime);
      return;
    }

    if (identical(_activeRuntime, runtime)) {
      if (status == datadog.DatadogFlagsClientStatus.ready) {
        _events.add(
          openfeature.ProviderEvent(type: openfeature.ProviderEventType.ready),
        );
      }
      return;
    }

    if (!isInitialization) {
      if (status != datadog.DatadogFlagsClientStatus.notReady) {
        _pendingRuntime = null;
        await _disableQuietly(runtime);
      }
      return;
    }

    switch (status) {
      case datadog.DatadogFlagsClientStatus.ready:
      case datadog.DatadogFlagsClientStatus.stale:
        await _activateRuntime(
          runtime,
          status,
          revision: revision,
          isInitialization: true,
        );
      case datadog.DatadogFlagsClientStatus.error:
        _pendingRuntime = null;
        await _disableQuietly(runtime);
      case datadog.DatadogFlagsClientStatus.notReady:
        return;
    }
  }

  Future<void> _activateRuntime(
    _ProviderRuntime runtime,
    datadog.DatadogFlagsClientStatus status, {
    required int revision,
    required bool isInitialization,
    bool isRefresh = false,
  }) async {
    if (!_isCurrent(runtime, revision)) {
      await _disableQuietly(runtime);
      return;
    }

    final previous = _activeRuntime;
    _activeRuntime = runtime;
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
    if (status == datadog.DatadogFlagsClientStatus.stale &&
        _isCurrent(runtime, revision) &&
        runtime.client.status == datadog.DatadogFlagsClientStatus.stale) {
      _events.add(
        openfeature.ProviderEvent(
          type: openfeature.ProviderEventType.stale,
          message:
              'Using existing Datadog assignments. Fresh assignments '
              'are not available.',
        ),
      );
    }
    if (previous != null && !identical(previous, runtime)) {
      _retire(previous);
    }
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

  static Future<void> _disableOwnerQuietly(datadog.DatadogFlags owner) async {
    try {
      await owner.disable();
    } on Object {
      // Preserve the assignment lifecycle result when cleanup also fails.
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
  final datadog.DefaultDatadogFlagsClient client;
  StreamSubscription<datadog.DatadogFlagsClientStatus>? statusSubscription;
  Future<void>? _disabling;

  _ProviderRuntime(this.owner, this.client);

  Future<void> disable() => _disabling ??= _disable();

  Future<void> _disable() async {
    await statusSubscription?.cancel();
    await owner.disable();
  }
}
