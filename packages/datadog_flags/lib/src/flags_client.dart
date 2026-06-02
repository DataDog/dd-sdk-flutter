// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';

import 'assignment.dart';
import 'datadog_flags.dart';
import 'evaluation_aggregator.dart';
import 'exposure_logger.dart';
import 'flags_context.dart';
import 'flags_details.dart';
import 'flags_error.dart';
import 'flags_repository.dart';
import 'json_value.dart';
import 'rum_flag_evaluation_reporter.dart';

class DatadogFlagsClient {
  static const defaultName = 'default';

  final String name;
  final FlagsRepository _repository;
  final ExposureLogger _exposureLogger;
  final EvaluationAggregator _evaluationAggregator;
  final RumFlagEvaluationReporter _rumFlagEvaluationReporter;

  DatadogFlagsClient({
    required this.name,
    required FlagsRepository repository,
    required ExposureLogger exposureLogger,
    required EvaluationAggregator evaluationAggregator,
    required RumFlagEvaluationReporter rumFlagEvaluationReporter,
  })  : _repository = repository,
        _exposureLogger = exposureLogger,
        _evaluationAggregator = evaluationAggregator,
        _rumFlagEvaluationReporter = rumFlagEvaluationReporter;

  static Future<DatadogFlagsClient> create({
    String name = defaultName,
  }) {
    return DatadogFlags.createClient(name: name);
  }

  static DatadogFlagsClient shared({
    String name = defaultName,
  }) {
    return DatadogFlags.sharedClient(name: name);
  }

  Future<void> setEvaluationContext(
    DatadogFlagsEvaluationContext context,
  ) async {
    await _repository.setEvaluationContext(context);
  }

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

  bool getBooleanValue({
    required String key,
    required bool defaultValue,
  }) {
    return getBooleanDetails(key: key, defaultValue: defaultValue).value;
  }

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

  String getStringValue({
    required String key,
    required String defaultValue,
  }) {
    return getStringDetails(key: key, defaultValue: defaultValue).value;
  }

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

  int getIntegerValue({
    required String key,
    required int defaultValue,
  }) {
    return getIntegerDetails(key: key, defaultValue: defaultValue).value;
  }

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

  double getDoubleValue({
    required String key,
    required double defaultValue,
  }) {
    return getDoubleDetails(key: key, defaultValue: defaultValue).value;
  }

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

  Object? getObjectValue({
    required String key,
    required Object? defaultValue,
  }) {
    return getObjectDetails(key: key, defaultValue: defaultValue).value;
  }

  Future<void> flush() {
    return _evaluationAggregator.flush();
  }

  Future<void> reset() async {
    _evaluationAggregator.dispose();
    await _repository.reset();
  }

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
        error: EvaluationErrorCode.providerNotReady,
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
        error: EvaluationErrorCode.flagNotFound,
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
        error: EvaluationErrorCode.typeMismatch,
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
        error: EvaluationErrorCode.typeMismatch,
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

class EvaluationErrorCode {
  static const providerNotReady = 'PROVIDER_NOT_READY';
  static const flagNotFound = 'FLAG_NOT_FOUND';
  static const typeMismatch = 'TYPE_MISMATCH';

  EvaluationErrorCode._();
}
