// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';

import 'assignment.dart';
import 'evaluation_aggregator.dart';
import 'exposure_logger.dart';
import 'flags_client.dart';
import 'flags_context.dart';
import 'flags_details.dart';
import 'flags_error.dart';
import 'flags_repository.dart';
import 'json_value.dart';
import 'rum_flag_evaluation_reporter.dart';

class DefaultDatadogFlagsClient implements DatadogFlagsClient {
  @override
  final String name;
  final FlagsRepository _repository;
  final ExposureLogger _exposureLogger;
  final EvaluationAggregator _evaluationAggregator;
  final RumFlagEvaluationReporter _rumFlagEvaluationReporter;

  DefaultDatadogFlagsClient({
    required this.name,
    required FlagsRepository repository,
    required ExposureLogger exposureLogger,
    required EvaluationAggregator evaluationAggregator,
    required RumFlagEvaluationReporter rumFlagEvaluationReporter,
  })  : _repository = repository,
        _exposureLogger = exposureLogger,
        _evaluationAggregator = evaluationAggregator,
        _rumFlagEvaluationReporter = rumFlagEvaluationReporter;

  @override
  Future<void> setEvaluationContext(
    DatadogFlagsEvaluationContext context,
  ) async {
    await _repository.setEvaluationContext(context);
  }

  @override
  FlagDetails<bool> getBooleanDetails({
    required String key,
    required bool defaultValue,
  }) {
    return _getDetails(
      key: key,
      defaultValue: defaultValue,
      requestedType: FlagVariationType.boolean,
    );
  }

  @override
  bool getBooleanValue({
    required String key,
    required bool defaultValue,
  }) {
    return getBooleanDetails(key: key, defaultValue: defaultValue).value;
  }

  @override
  FlagDetails<String> getStringDetails({
    required String key,
    required String defaultValue,
  }) {
    return _getDetails(
      key: key,
      defaultValue: defaultValue,
      requestedType: FlagVariationType.string,
    );
  }

  @override
  String getStringValue({
    required String key,
    required String defaultValue,
  }) {
    return getStringDetails(key: key, defaultValue: defaultValue).value;
  }

  @override
  FlagDetails<int> getIntegerDetails({
    required String key,
    required int defaultValue,
  }) {
    return _getDetails(
      key: key,
      defaultValue: defaultValue,
      requestedType: FlagVariationType.integer,
    );
  }

  @override
  int getIntegerValue({
    required String key,
    required int defaultValue,
  }) {
    return getIntegerDetails(key: key, defaultValue: defaultValue).value;
  }

  @override
  FlagDetails<double> getDoubleDetails({
    required String key,
    required double defaultValue,
  }) {
    return _getDetails(
      key: key,
      defaultValue: defaultValue,
      requestedType: FlagVariationType.float,
    );
  }

  @override
  double getDoubleValue({
    required String key,
    required double defaultValue,
  }) {
    return getDoubleDetails(key: key, defaultValue: defaultValue).value;
  }

  @override
  FlagDetails<Object?> getObjectDetails({
    required String key,
    required Object? defaultValue,
  }) {
    return _getDetails(
      key: key,
      defaultValue: sanitizeJsonValue(defaultValue),
      requestedType: FlagVariationType.object,
    );
  }

  @override
  Object? getObjectValue({
    required String key,
    required Object? defaultValue,
  }) {
    return getObjectDetails(key: key, defaultValue: defaultValue).value;
  }

  @override
  Future<void> flush() {
    return _evaluationAggregator.flush();
  }

  @override
  Future<void> reset() async {
    _evaluationAggregator.dispose();
    await _repository.reset();
  }

  @override
  Future<void> dispose() async {
    _evaluationAggregator.dispose();
  }

  FlagDetails<T> _getDetails<T>({
    required String key,
    required T defaultValue,
    required FlagVariationType requestedType,
  }) {
    final context = _repository.context;
    if (context == null) {
      _evaluationAggregator.recordEvaluation(
        flagKey: key,
        assignment: FlagAssignment.defaultAssignment,
        evaluationContext: DatadogFlagsEvaluationContext.empty,
        error: _EvaluationErrorCode.providerNotReady,
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
        assignment: FlagAssignment.defaultAssignment,
        evaluationContext: context,
        error: _EvaluationErrorCode.flagNotFound,
      );
      return FlagDetails(
        key: key,
        value: defaultValue,
        error: FlagEvaluationError.flagNotFound,
      );
    }

    if (requestedType == FlagVariationType.object &&
        assignment.variationType != FlagVariationType.object) {
      _evaluationAggregator.recordEvaluation(
        flagKey: key,
        assignment: assignment,
        evaluationContext: context,
        error: _EvaluationErrorCode.typeMismatch,
      );
      return FlagDetails(
        key: key,
        value: defaultValue,
        error: FlagEvaluationError.typeMismatch,
      );
    }

    final typedValue = assignment.typedValue(requestedType);
    if (typedValue == null && requestedType != FlagVariationType.object) {
      _evaluationAggregator.recordEvaluation(
        flagKey: key,
        assignment: assignment,
        evaluationContext: context,
        error: _EvaluationErrorCode.typeMismatch,
      );
      return FlagDetails(
        key: key,
        value: defaultValue,
        error: FlagEvaluationError.typeMismatch,
      );
    }

    final value = typedValue as T;
    _trackEvaluation(key, assignment, value, context);
    return FlagDetails(
      key: key,
      value: value,
      variant: assignment.variationKey,
      reason: assignment.reason,
    );
  }

  void _trackEvaluation<T>(
    String key,
    FlagAssignment assignment,
    T value,
    DatadogFlagsEvaluationContext context,
  ) {
    unawaited(_exposureLogger.logExposure(
      flagKey: key,
      assignment: assignment,
      evaluationContext: context,
    ));
    _evaluationAggregator.recordEvaluation(
      flagKey: key,
      assignment: assignment,
      evaluationContext: context,
      error: null,
    );
    if (value != null) {
      _rumFlagEvaluationReporter.report(key, value as Object);
    }
  }
}

class _EvaluationErrorCode {
  static const providerNotReady = 'PROVIDER_NOT_READY';
  static const flagNotFound = 'FLAG_NOT_FOUND';
  static const typeMismatch = 'TYPE_MISMATCH';

  _EvaluationErrorCode._();
}
