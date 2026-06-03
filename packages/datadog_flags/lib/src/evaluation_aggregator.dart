// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'assignment.dart';
import 'datadog_context.dart';
import 'datadog_event_context.dart';
import 'flags_configuration.dart';
import 'flags_context.dart';
import 'json_value.dart';

class EvaluationAggregator {
  final DatadogFlagsContext datadogContext;
  final DatadogFlagsConfiguration configuration;
  final http.Client httpClient;
  final Map<String, _AggregatedEvaluation> _aggregations = {};
  Timer? _flushTimer;

  EvaluationAggregator({
    required this.datadogContext,
    required this.configuration,
    required this.httpClient,
  }) {
    if (configuration.trackEvaluations) {
      _flushTimer = Timer.periodic(
        configuration.evaluationFlushInterval,
        (_) => unawaited(flush()),
      );
    }
  }

  void recordEvaluation({
    required String flagKey,
    required FlagAssignment assignment,
    required DatadogFlagsEvaluationContext evaluationContext,
    required String? error,
  }) {
    if (!configuration.trackEvaluations) {
      return;
    }

    final now = configuration.dateProvider().millisecondsSinceEpoch;
    final ddContext = ddContextFor(datadogContext);
    final key = _aggregationKey(
      flagKey: flagKey,
      assignment: assignment,
      evaluationContext: evaluationContext,
      ddContext: ddContext,
      error: error,
    );
    final existing = _aggregations[key];
    if (existing != null) {
      existing.evaluationCount += 1;
      existing.lastEvaluation = now;
      return;
    }

    final runtimeDefaultUsed = assignment.reason == 'DEFAULT' || error != null;
    _aggregations[key] = _AggregatedEvaluation(
      flagKey: flagKey,
      variantKey: assignment.variationKey,
      allocationKey: assignment.allocationKey,
      targetingKey: evaluationContext.targetingKey,
      error: error,
      attributes: evaluationContext.attributes,
      ddContext: ddContext,
      firstEvaluation: now,
      lastEvaluation: now,
      evaluationCount: 1,
      runtimeDefaultUsed: runtimeDefaultUsed,
    );

    if (_aggregations.length >= configuration.evaluationMaxBatchSize) {
      unawaited(flush());
    }
  }

  Future<void> flush() async {
    if (!configuration.trackEvaluations || _aggregations.isEmpty) {
      return;
    }

    final evaluations = List<_AggregatedEvaluation>.from(_aggregations.values);
    _aggregations.clear();

    final endpoint = configuration.customEvaluationEndpoint ??
        datadogContext.intakeEndpoint().replace(
          path: '/api/v2/flagevaluation',
          queryParameters: {'ddsource': datadogContext.source},
        );
    final body = jsonEncode({
      'context': datadogContext.evaluationBatchContext(),
      'flagEvaluations': evaluations.map((e) => e.toJson()).toList(),
    });

    try {
      final response = await httpClient.post(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'DD-API-KEY': datadogContext.clientToken,
          'DD-EVP-ORIGIN': datadogContext.source,
          'DD-EVP-ORIGIN-VERSION': datadogContext.sdkVersion,
          'DD-REQUEST-ID': const Uuid().v4(),
        },
        body: body,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _restore(evaluations);
      }
    } catch (_) {
      _restore(evaluations);
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  void _restore(List<_AggregatedEvaluation> evaluations) {
    for (final evaluation in evaluations) {
      _aggregations[_aggregationKey(
        flagKey: evaluation.flagKey,
        assignment: FlagAssignment(
          allocationKey: evaluation.allocationKey,
          variationKey: evaluation.variantKey,
          variationType: FlagVariationType.unknown,
          variationValue: null,
          reason: evaluation.runtimeDefaultUsed ? 'DEFAULT' : '',
          doLog: false,
        ),
        evaluationContext: DatadogFlagsEvaluationContext(
          targetingKey: evaluation.targetingKey,
          attributes: evaluation.attributes,
        ),
        ddContext: evaluation.ddContext,
        error: evaluation.error,
      )] = evaluation;
    }
  }
}

String _aggregationKey({
  required String flagKey,
  required FlagAssignment assignment,
  required DatadogFlagsEvaluationContext evaluationContext,
  required Map<String, Object?>? ddContext,
  required String? error,
}) {
  return jsonEncode({
    'flagKey': flagKey,
    'variantKey': assignment.variationKey,
    'allocationKey': assignment.allocationKey,
    'targetingKey': evaluationContext.targetingKey,
    'error': error,
    'context': sortedJson(evaluationContext.attributes),
    'dd': sortedJson(ddContext),
  });
}

class _AggregatedEvaluation {
  final String flagKey;
  final String variantKey;
  final String allocationKey;
  final String targetingKey;
  final String? error;
  final Map<String, Object?> attributes;
  final Map<String, Object?>? ddContext;
  final int firstEvaluation;
  int lastEvaluation;
  int evaluationCount;
  final bool runtimeDefaultUsed;

  _AggregatedEvaluation({
    required this.flagKey,
    required this.variantKey,
    required this.allocationKey,
    required this.targetingKey,
    required this.error,
    required this.attributes,
    required this.ddContext,
    required this.firstEvaluation,
    required this.lastEvaluation,
    required this.evaluationCount,
    required this.runtimeDefaultUsed,
  });

  Map<String, Object?> toJson() {
    final eventContext = removeNullValues({
      'evaluation': attributes.isEmpty ? null : sanitizeJsonValue(attributes),
      'dd': ddContext,
    });

    return removeNullValues({
      'timestamp': firstEvaluation,
      'flag': {'key': flagKey},
      'first_evaluation': firstEvaluation,
      'last_evaluation': lastEvaluation,
      'evaluation_count': evaluationCount,
      'variant': runtimeDefaultUsed ? null : {'key': variantKey},
      'allocation': runtimeDefaultUsed ? null : {'key': allocationKey},
      'targeting_rule': null,
      'targeting_key': targetingKey,
      'runtime_default_used': runtimeDefaultUsed ? true : null,
      'error': error == null ? null : {'message': error},
      'context': eventContext.isEmpty ? null : eventContext,
    });
  }
}
