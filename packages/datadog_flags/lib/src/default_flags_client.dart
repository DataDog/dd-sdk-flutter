// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'assignment.dart';
import 'evaluation_aggregator.dart';
import 'evaluation_context.dart';
import 'exposure_logger.dart';
import 'flags_client.dart';
import 'flags_error.dart';
import 'flags_repository.dart';

class DefaultDatadogFlagsClient implements DatadogFlagsClient {
  static final Object _typeMismatch = Object();

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
  })  : _repository = repository,
        _exposureLogger = exposureLogger,
        _evaluationAggregator = evaluationAggregator;

  @override
  Future<void> initialize(FlagsEvaluationContext context) async {
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
    await Future.wait([
      _evaluationAggregator.shutdown(),
      _exposureLogger.shutdown(),
    ]);
    await _repository.clearMemory();
  }

  @override
  Future<void> reset() async {
    await _repository.reset();
  }

  FlagDetails<T> getDetails<T>({
    required String key,
    required T defaultValue,
    required FlagVariationType requestedType,
  }) {
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

    if (identical(resolvedValue, _typeMismatch)) {
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

    _exposureLogger.logExposure(
      flagKey: key,
      assignment: assignment,
      evaluationContext: context,
    );

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
      reason: assignment.reason,
    );
  }
}
