// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';

import 'assignment.dart';
import 'evaluation_context.dart';
import 'flags_runtime.dart';
import 'intake_request.dart';
import 'json_value.dart';
import 'split_features.dart';

class EvaluationAggregator {
  static const int defaultMaxBatchSize = 1000;
  static const Duration defaultUploadTimeout = Duration(seconds: 15);

  @visibleForTesting
  static int maxBatchSize = defaultMaxBatchSize;

  @visibleForTesting
  static Duration uploadTimeout = defaultUploadTimeout;

  final FlagsRuntime runtime;
  final Map<String, _AggregatedEvaluation> _aggregations = {};
  Future<bool>? _uploadInFlight;
  Future<void>? _shutdownInFlight;
  Timer? _periodicFlushTimer;
  Timer? _retryFlushTimer;
  bool _shutdownDrainActive = false;
  final UploadBackoff _backoff = UploadBackoff();

  EvaluationAggregator(this.runtime) {
    if (runtime.configuration.trackEvaluations) {
      _schedulePeriodicFlush(runtime.configuration.evaluationFlushInterval);
    }
  }

  void _schedulePeriodicFlush(Duration delay) {
    _periodicFlushTimer?.cancel();
    _periodicFlushTimer = Timer(delay, () {
      _schedulePeriodicFlush(runtime.configuration.evaluationFlushInterval);
      unawaited(flush());
    });
  }

  void recordEvaluation({
    required String flagKey,
    required FlagAssignment? assignment,
    required FlagsEvaluationContext? evaluationContext,
    required String? error,
  }) {
    final configuration = runtime.configuration;
    if (!configuration.trackEvaluations) {
      return;
    }

    final now = configuration.dateProvider().millisecondsSinceEpoch;
    final features = error == null && assignment != null
        ? assignment.features.forDestination(SplitFeatureDestination.evaluation)
        : const <String, Object>{};
    final key = _aggregationKey(
      flagKey: flagKey,
      allocationKey: assignment?.allocationKey,
      variantKey: assignment?.variationKey,
      evaluationContext: evaluationContext,
      error: error,
      features: features,
    );
    final existing = _aggregations[key];
    if (existing != null) {
      existing.evaluationCount += 1;
      existing.lastEvaluation = now;
      return;
    }

    final runtimeDefaultUsed =
        assignment == null || assignment.reason == 'DEFAULT' || error != null;
    _aggregations[key] = _AggregatedEvaluation(
      aggregationKey: key,
      flagKey: flagKey,
      variantKey: assignment?.variationKey,
      allocationKey: assignment?.allocationKey,
      targetingKey: evaluationContext == null
          ? null
          : evaluationContext.targetingKey ?? '',
      error: error,
      attributes: evaluationContext?.attributes ?? const {},
      features: features,
      firstEvaluation: now,
      lastEvaluation: now,
      evaluationCount: 1,
      runtimeDefaultUsed: runtimeDefaultUsed,
    );

    if (_aggregations.length >= maxBatchSize) {
      unawaited(_flushPendingEvaluations(rescheduleOnFailure: true));
    }
  }

  Future<void> flush() {
    return _flushPendingEvaluations(rescheduleOnFailure: true);
  }

  Future<void> shutdown() {
    _periodicFlushTimer?.cancel();
    _periodicFlushTimer = null;
    _retryFlushTimer?.cancel();
    _retryFlushTimer = null;

    final shutdownInFlight = _shutdownInFlight;
    if (shutdownInFlight != null) {
      return shutdownInFlight;
    }

    late final Future<void> shutdownOperation;
    shutdownOperation = _shutdownDrain().whenComplete(() {
      if (identical(_shutdownInFlight, shutdownOperation)) {
        _shutdownInFlight = null;
      }
    });
    _shutdownInFlight = shutdownOperation;
    return shutdownOperation;
  }

  Future<void> _shutdownDrain() async {
    _shutdownDrainActive = true;
    try {
      final activeUpload = _uploadInFlight;
      final activeSucceeded = await activeUpload ?? true;
      if (!activeSucceeded) return;
      await _uploadPendingEvaluations(rescheduleOnFailure: false);
    } finally {
      _shutdownDrainActive = false;
    }
  }

  Future<void> _flushPendingEvaluations({
    required bool rescheduleOnFailure,
  }) async {
    if (_backoff.remaining > Duration.zero) {
      _scheduleRetryFlush(_backoff.remaining);
      return;
    }
    if (_uploadInFlight != null) {
      if (rescheduleOnFailure) {
        _scheduleRetryFlush();
      }
      return;
    }

    await _uploadPendingEvaluations(rescheduleOnFailure: rescheduleOnFailure);
  }

  Future<bool> _uploadPendingEvaluations({required bool rescheduleOnFailure}) {
    final configuration = runtime.configuration;
    if (!configuration.trackEvaluations || _aggregations.isEmpty) {
      return Future.value(true);
    }

    final evaluations = List<_AggregatedEvaluation>.from(_aggregations.values);
    _aggregations.clear();

    late final Future<bool> uploadOperation;
    uploadOperation =
        _sendEvaluations(
          evaluations,
          rescheduleOnFailure: rescheduleOnFailure,
        ).whenComplete(() {
          if (identical(_uploadInFlight, uploadOperation)) {
            _uploadInFlight = null;
          }
        });
    _uploadInFlight = uploadOperation;
    return uploadOperation;
  }

  Future<bool> _sendEvaluations(
    List<_AggregatedEvaluation> evaluations, {
    required bool rescheduleOnFailure,
  }) async {
    final request = buildFlagsIntakeRequest(
      endpoint: _evaluationEndpoint(),
      clientToken: runtime.datadogConfig.clientToken,
      nativeContentType: 'application/json',
      nativeBodyBuilder: () => jsonEncode({
        'context': _batchDatadogContext(),
        'flagEvaluations': evaluations.map((e) => e.toJson()).toList(),
      }),
      webBodyBuilder: () => evaluations.map(_webEvaluationJson).join('\n'),
    );

    try {
      final response = await runtime.httpClient
          .post(request.endpoint, headers: request.headers, body: request.body)
          .timeout(uploadTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (shouldRetryFlagsUpload(response.statusCode)) {
          _backoff.failed();
          _restore(evaluations, reschedule: rescheduleOnFailure);
          return false;
        }
        _backoff.reset();
        return true;
      }
      _backoff.reset();
      return true;
    } catch (_) {
      _backoff.failed();
      _restore(evaluations, reschedule: rescheduleOnFailure);
      return false;
    }
  }

  void dispose() {
    unawaited(shutdown());
  }

  void _restore(
    List<_AggregatedEvaluation> evaluations, {
    required bool reschedule,
  }) {
    for (final evaluation in evaluations) {
      final existing = _aggregations[evaluation.aggregationKey];
      if (existing == null) {
        _aggregations[evaluation.aggregationKey] = evaluation;
        continue;
      }

      existing.firstEvaluation =
          existing.firstEvaluation < evaluation.firstEvaluation
          ? existing.firstEvaluation
          : evaluation.firstEvaluation;
      existing.lastEvaluation =
          existing.lastEvaluation > evaluation.lastEvaluation
          ? existing.lastEvaluation
          : evaluation.lastEvaluation;
      existing.evaluationCount += evaluation.evaluationCount;
    }

    if (reschedule && !_shutdownDrainActive) {
      _scheduleRetryFlush();
    }
  }

  Uri _evaluationEndpoint() {
    final datadogConfig = runtime.datadogConfig;
    return runtime.configuration.customEvaluationEndpoint ??
        datadogConfig.intakeEndpoint().replace(path: '/api/v2/flagevaluation');
  }

  String _webEvaluationJson(_AggregatedEvaluation evaluation) {
    final event = evaluation.toJson();
    final eventContext = switch (event['context']) {
      Map<String, Object?> context => Map<String, Object?>.from(context),
      _ => <String, Object?>{},
    };
    final datadogContext = _evaluationDatadogContext();
    if (datadogContext.isNotEmpty) {
      eventContext['dd'] = datadogContext;
      event['context'] = eventContext;
    }
    return jsonEncode(event);
  }

  Map<String, Object?> _batchDatadogContext() {
    return _removeNullValues({
      ..._evaluationDatadogContext(),
      'env': runtime.datadogConfig.env,
      'version': runtime.datadogConfig.version,
    });
  }

  Map<String, Object?> _evaluationDatadogContext() {
    final applicationId = runtime.datadogConfig.applicationId;
    return _removeNullValues({
      'service': runtime.datadogConfig.service,
      'rum': applicationId == null
          ? null
          : {
              'application': {'id': applicationId},
            },
    });
  }

  void _scheduleRetryFlush([Duration? remaining]) {
    final delay =
        remaining ??
        (_backoff.remaining > Duration.zero
            ? _backoff.remaining
            : _evaluationFlushRetryDelay);
    if (_retryFlushTimer != null) {
      return;
    }

    _retryFlushTimer = Timer(delay, () {
      _retryFlushTimer = null;
      unawaited(_flushPendingEvaluations(rescheduleOnFailure: true));
    });
  }
}

String _aggregationKey({
  required String flagKey,
  required String? allocationKey,
  required String? variantKey,
  required FlagsEvaluationContext? evaluationContext,
  required String? error,
  required Map<String, Object> features,
}) {
  return jsonEncode({
    'flagKey': flagKey,
    'variantKey': variantKey,
    'allocationKey': allocationKey,
    'targetingKey': evaluationContext == null
        ? null
        : evaluationContext.targetingKey ?? '',
    'error': error,
    'context': _sortedJson(evaluationContext?.attributes ?? const {}),
    if (features.isNotEmpty) 'features': _sortedJson(features),
  });
}

class _AggregatedEvaluation {
  final String aggregationKey;
  final String flagKey;
  final String? variantKey;
  final String? allocationKey;
  final String? targetingKey;
  final String? error;
  final Map<String, Object?> attributes;
  final Map<String, Object> features;
  int firstEvaluation;
  int lastEvaluation;
  int evaluationCount;
  final bool runtimeDefaultUsed;

  _AggregatedEvaluation({
    required this.aggregationKey,
    required this.flagKey,
    required this.variantKey,
    required this.allocationKey,
    required this.targetingKey,
    required this.error,
    required this.attributes,
    required this.features,
    required this.firstEvaluation,
    required this.lastEvaluation,
    required this.evaluationCount,
    required this.runtimeDefaultUsed,
  });

  Map<String, Object?> toJson() {
    final includeAssignment =
        !runtimeDefaultUsed && variantKey != null && allocationKey != null;
    final eventContext = _removeNullValues({
      'evaluation': attributes.isEmpty ? null : sanitizeJsonValue(attributes),
    });

    return _removeNullValues({
      'timestamp': firstEvaluation,
      'flag': {'key': flagKey},
      'first_evaluation': firstEvaluation,
      'last_evaluation': lastEvaluation,
      'evaluation_count': evaluationCount,
      'variant': includeAssignment ? {'key': variantKey} : null,
      'allocation': includeAssignment ? {'key': allocationKey} : null,
      'targeting_rule': null,
      'targeting_key': targetingKey,
      'runtime_default_used': runtimeDefaultUsed ? true : null,
      'error': error == null ? null : {'message': error},
      'context': eventContext.isEmpty ? null : eventContext,
      'features': features.isEmpty ? null : features,
    });
  }
}

Map<String, Object?> _removeNullValues(Map<String, Object?> input) {
  return Map.fromEntries(
    input.entries
        .where((entry) => entry.value != null)
        .map(
          (entry) => MapEntry(entry.key, _removeNestedNullValues(entry.value)),
        ),
  );
}

Object? _removeNestedNullValues(Object? value) {
  if (value is Map<Object?, Object?>) {
    return Map.fromEntries(
      value.entries.where((entry) => entry.value != null).map((entry) {
        return MapEntry(
          entry.key.toString(),
          _removeNestedNullValues(entry.value),
        );
      }),
    );
  }
  if (value is Iterable<Object?>) {
    return value.map(_removeNestedNullValues).toList();
  }
  return value;
}

const _evaluationFlushRetryDelay = Duration(milliseconds: 500);

Object? _sortedJson(Object? value) {
  if (value is Map<Object?, Object?>) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return {
      for (final entry in entries)
        entry.key.toString(): _sortedJson(entry.value),
    };
  }
  if (value is Iterable<Object?>) {
    return value.map(_sortedJson).toList();
  }
  return value;
}
