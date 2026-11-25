// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'ai_gateway.dart';
import 'costs.dart';

/// One structured-output LLM call, bundled as a single value: the rendered
/// prompt [text], the [schema] its response must satisfy, and [fromJson] to
/// turn that response back into [T]. The three are never useful apart from
/// each other -- a schema with no matching parser is meaningless, and a
/// prompt written against a schema nobody enforces is just a hope -- so one
/// object carries all three rather than three parameters that happen to be
/// passed around together.
///
/// Each concrete prompt (see `prompts/`) is a top-level function that builds
/// one of these from its specific inputs, rather than a subclass -- there's
/// no behaviour to override, only data to assemble.
class Prompt<T> {
  final String text;
  final Map<String, dynamic> schema;
  final T Function(Map<String, dynamic>) fromJson;

  const Prompt({
    required this.text,
    required this.schema,
    required this.fromJson,
  });
}

/// Sends [prompt]'s text to [client] with its schema as the required output
/// shape, and returns the response deserialized by its `fromJson`.
Future<T> runStructuredPrompt<T>(
  AiGatewayClient client,
  Prompt<T> prompt, {
  String model = defaultModel,
  int maxTokens = 4096,
  LlmCostTracker? costTracker,
  String costLabel = '',
}) async {
  final response = await client.createStructuredMessage(
    prompt: prompt.text,
    schema: prompt.schema,
    model: model,
    maxTokens: maxTokens,
  );
  costTracker?.record(response.usage, costLabel);
  return prompt.fromJson(response.content);
}
