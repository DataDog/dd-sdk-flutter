// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:releaser/llm/ai_gateway.dart';

/// A canned-response [AiGatewayClient] for testing the LLM pipeline without
/// a live token -- also a stand-in for [HttpAiGatewayClient] until the AI
/// Gateway token-minting prerequisite is wired up for this repo's CI.
///
/// Returns [responses] in call order; records every prompt it was sent so
/// tests can assert on prompt content without re-deriving it.
class FakeAiGatewayClient implements AiGatewayClient {
  final List<Map<String, dynamic>> responses;
  final List<String> prompts = [];
  final LlmUsage usage;
  var _index = 0;

  FakeAiGatewayClient(
    this.responses, {
    this.usage = const LlmUsage(
      model: 'fake-model',
      inputTokens: 10,
      outputTokens: 5,
    ),
  });

  @override
  Future<StructuredResponse> createStructuredMessage({
    required String prompt,
    required Map<String, dynamic> schema,
    String model = defaultModel,
    int maxTokens = 4096,
  }) async {
    prompts.add(prompt);
    if (_index >= responses.length) {
      throw StateError(
        'FakeAiGatewayClient received more calls (${_index + 1}) than it '
        'was given responses for (${responses.length}).',
      );
    }
    return StructuredResponse(content: responses[_index++], usage: usage);
  }
}
