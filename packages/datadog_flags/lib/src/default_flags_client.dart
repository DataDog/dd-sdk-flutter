// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';

import 'assignment.dart';
import 'evaluation_aggregator.dart';
import 'evaluation_context.dart';
import 'exposure_logger.dart';
import 'flags_client.dart';
import 'flags_error.dart';
import 'flags_repository.dart';
import 'split_features.dart';

class DefaultDatadogFlagsClient
    implements DatadogFlagsClient, DatadogFlagsClientLifecycle {
  static final Object _typeMismatch = Object();
  bool isShutdown = false;

  @override
  final String name;
  final FlagsRepository _repository;
  final ExposureLogger _exposureLogger;
  final EvaluationAggregator _evaluationAggregator;

  DefaultDatadogFlagsClient({
    required this.name,
    required FlagsRepository repository,
    required ExposureLogger exposureLogger,
    required EvaluationAggregator evaluationAggregator,
  }) : _repository = repository,
       _exposureLogger = exposureLogger,
       _evaluationAggregator = evaluationAggregator;

  // Runtime replacement preserves deduplication and pending telemetry uploads.
  void inheritTelemetry(DefaultDatadogFlagsClient previous) {
    _exposureLogger.inheritHistory(previous._exposureLogger);
    _evaluationAggregator.inheritPendingEvaluations(
      previous._evaluationAggregator,
    );
  }

  @override
  DatadogFlagsClientStatus get status => _repository.status;

  @override
  Stream<DatadogFlagsClientStatus> get statusChanges =>
      _repository.statusChanges;

  @override
  FlagsEvaluationContext? get evaluationContext => _repository.context;

  @override
  Future<void> initialize(FlagsEvaluationContext context) async {
    if (isShutdown) {
      throw StateError('This client is shut down. Create a new client.');
    }
    await _repository.initialize(context);
  }

  @override
  FlagDetails<bool> getBooleanDetails({
    required String key,
    required bool defaultValue,
  }) {
    return getDetails(
      key: key,
      defaultValue: defaultValue,
      requestedType: FlagVariationType.boolean,
    );
  }

  @override
  FlagDetails<String> getStringDetails({
    required String key,
    required String defaultValue,
  }) {
    return getDetails(
      key: key,
      defaultValue: defaultValue,
      requestedType: FlagVariationType.string,
    );
  }

  @override
  FlagDetails<int> getIntegerDetails({
    required String key,
    required int defaultValue,
  }) {
    return getDetails(
      key: key,
      defaultValue: defaultValue,
      requestedType: FlagVariationType.integer,
    );
  }

  @override
  FlagDetails<double> getDoubleDetails({
    required String key,
    required double defaultValue,
  }) {
    return getDetails(
      key: key,
      defaultValue: defaultValue,
      requestedType: FlagVariationType.float,
    );
  }

  @override
  FlagDetails<Object?> getObjectDetails({
    required String key,
    required Object? defaultValue,
  }) {
    return getDetails(
      key: key,
      defaultValue: defaultValue,
      requestedType: FlagVariationType.object,
    );
  }

  @override
  Future<void> shutdown() async {
    isShutdown = true;
    await _repository.dispose();
    await Future.wait([
      _evaluationAggregator.shutdown(),
      _exposureLogger.shutdown(),
    ]);
  }

  @override
  Future<void> reset() async {
    await _repository.reset();
  }

  FlagDetails<T> getDetails<T>({
    required String key,
    required T defaultValue,
    required FlagVariationType requestedType,
    bool Function(Object?)? valueGuard,
  }) {
    final resolution = resolveDeferringExposure(
      key: key,
      defaultValue: defaultValue,
      requestedType: requestedType,
      valueGuard: valueGuard,
    );
    resolution.exposure?.record();
    return resolution.details;
  }

  /// Evaluates a flag without recording its exposure.
  ///
  /// The returned exposure is non-null for a successful evaluation of an
  /// allocation that logs exposures. The caller records it once the whole
  /// evaluation has succeeded.
  ({FlagDetails<T> details, PendingExposure? exposure})
  resolveDeferringExposure<T>({
    required String key,
    required T defaultValue,
    required FlagVariationType requestedType,
    bool Function(Object?)? valueGuard,
  }) {
    PendingExposure? exposure;
    final details = _resolve(
      key: key,
      defaultValue: defaultValue,
      requestedType: requestedType,
      valueGuard: valueGuard,
      onSuccess: (assignment, context) {
        if (assignment.doLog) {
          exposure = PendingExposure._(
            _exposureLogger,
            key,
            assignment,
            context,
          );
        }
      },
    );
    return (details: details, exposure: exposure);
  }

  FlagDetails<T> _resolve<T>({
    required String key,
    required T defaultValue,
    required FlagVariationType requestedType,
    bool Function(Object?)? valueGuard,
    required void Function(FlagAssignment, FlagsEvaluationContext) onSuccess,
  }) {
    if (isShutdown) {
      return FlagDetails(
        key: key,
        value: defaultValue,
        error: FlagEvaluationError.providerNotReady,
      );
    }
    final context = _repository.context;
    if (context == null) {
      _evaluationAggregator.recordEvaluation(
        flagKey: key,
        assignment: null,
        evaluationContext: FlagsEvaluationContext.empty,
        error: FlagEvaluationError.providerNotReady.code,
      );
      return FlagDetails(
        key: key,
        value: defaultValue,
        error: FlagEvaluationError.providerNotReady,
      );
    }

    final assignment = _repository.flagAssignment(key);
    // Capture before telemetry invokes application-provided callbacks, which
    // may synchronously clear the repository.
    final restoredFromStore = _repository.isRestoredFromStore;
    if (assignment == null) {
      _evaluationAggregator.recordEvaluation(
        flagKey: key,
        assignment: null,
        evaluationContext: context,
        error: FlagEvaluationError.flagNotFound.code,
      );
      return FlagDetails(
        key: key,
        value: defaultValue,
        error: FlagEvaluationError.flagNotFound,
      );
    }

    final variationValue = assignment.variationValue;
    final assignmentType = assignment.variationType;
    final resolvedValue = switch (requestedType) {
      FlagVariationType.boolean
          when assignmentType == FlagVariationType.boolean =>
        variationValue,
      FlagVariationType.string
          when assignmentType == FlagVariationType.string =>
        variationValue,
      FlagVariationType.integer
          when (assignmentType == FlagVariationType.integer ||
                  assignmentType == FlagVariationType.number) &&
              variationValue is int =>
        variationValue,
      FlagVariationType.float
          when (assignmentType == FlagVariationType.float ||
                  assignmentType == FlagVariationType.number) &&
              variationValue is num =>
        variationValue.toDouble(),
      FlagVariationType.object
          when assignmentType == FlagVariationType.object =>
        variationValue,
      _ => _typeMismatch,
    };

    if (identical(resolvedValue, _typeMismatch) ||
        (valueGuard != null && !valueGuard(resolvedValue))) {
      _evaluationAggregator.recordEvaluation(
        flagKey: key,
        assignment: assignment,
        evaluationContext: context,
        error: FlagEvaluationError.typeMismatch.code,
      );
      return FlagDetails(
        key: key,
        value: defaultValue,
        error: FlagEvaluationError.typeMismatch,
      );
    }

    onSuccess(assignment, context);
    _evaluationAggregator.recordEvaluation(
      flagKey: key,
      assignment: assignment,
      evaluationContext: context,
      error: null,
    );

    return FlagDetails(
      key: key,
      value: resolvedValue as T,
      variant: assignment.variationKey,
      reason: restoredFromStore ? 'CACHED' : assignment.reason,
      flagMetadata: {
        datadogAllocationKeyMetadata: assignment.allocationKey,
        datadogSerialIdMetadata: ?assignment.serialId,
        ...assignment.features.toFlagMetadata(),
      },
    );
  }
}

/// An exposure that is recorded only after its evaluation succeeds.
final class PendingExposure {
  final ExposureLogger _logger;
  final String flagKey;
  final FlagAssignment assignment;
  final FlagsEvaluationContext evaluationContext;

  PendingExposure._(
    this._logger,
    this.flagKey,
    this.assignment,
    this.evaluationContext,
  );

  /// Records the exposure and returns whether it was already recorded.
  bool record() => _logger.logExposure(
    flagKey: flagKey,
    assignment: assignment,
    evaluationContext: evaluationContext,
  );
}
