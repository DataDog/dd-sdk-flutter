// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:logging/logging.dart';

import 'ai_gateway.dart';

/// (input, output) advertised price per million tokens. Quick-and-dirty by
/// design: an estimate for a human glancing at CI output, not a billing
/// record.
const _pricePerMillionTokens = {
  'claude-sonnet-4-6': (input: 3.00, output: 15.00),
};

/// Aggregates [LlmUsage] across a run's LLM calls and prints an estimated
/// cost summary.
class LlmCostTracker {
  final _calls = <(String label, LlmUsage usage)>[];

  void record(LlmUsage usage, [String label = '']) {
    _calls.add((label, usage));
  }

  void printSummary(Logger logger) {
    var totalInputTokens = 0;
    var totalOutputTokens = 0;
    var totalCost = 0.0;

    for (final (label, usage) in _calls) {
      final prices = _pricePerMillionTokens[usage.model];
      if (prices == null) {
        logger.warning(
          'Usage costs for model ${usage.model} not known; falling back to '
          'claude-sonnet-4-6 pricing.',
        );
      }
      final (:input, :output) =
          prices ?? _pricePerMillionTokens['claude-sonnet-4-6']!;
      final cost =
          usage.inputTokens / 1e6 * input + usage.outputTokens / 1e6 * output;
      totalInputTokens += usage.inputTokens;
      totalOutputTokens += usage.outputTokens;
      totalCost += cost;

      final suffix = label.isEmpty ? '' : ' ($label)';
      logger.info(
        '  ${usage.model}$suffix: ${usage.inputTokens}in + '
        '${usage.outputTokens}out = \$${cost.toStringAsFixed(4)}',
      );
    }

    logger.info(
      '  Estimated cost: \$${totalCost.toStringAsFixed(4)} '
      '(${_calls.length} LLM calls with $totalInputTokens input tokens, '
      '$totalOutputTokens output tokens)',
    );
  }
}
