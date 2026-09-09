// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'ai_gateway.dart';
import 'costs.dart';

/// Sends [prompt] to [client] with [schema] as the required output shape,
/// and returns the response deserialized by [fromJson].
///
/// [schema] is hand-written per response type rather than derived from a
/// class at runtime as there are only a few response shapes in this
/// pipeline (`changelog.dart`'s `groupedPrsSchema`/`changelogEntryListSchema`),
/// so writing them out is simpler than building a reflection-based
/// generator for a handful of call sites.
Future<T> runStructuredPrompt<T>(
  AiGatewayClient client,
  String prompt,
  Map<String, dynamic> schema,
  T Function(Map<String, dynamic>) fromJson, {
  String model = defaultModel,
  int maxTokens = 4096,
  LlmCostTracker? costTracker,
  String costLabel = '',
}) async {
  final response = await client.createStructuredMessage(
    prompt: prompt,
    schema: schema,
    model: model,
    maxTokens: maxTokens,
  );
  costTracker?.record(response.usage, costLabel);
  return fromJson(response.content);
}
