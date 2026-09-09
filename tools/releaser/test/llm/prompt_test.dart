// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:logging/logging.dart';
import 'package:releaser/llm/ai_gateway.dart';
import 'package:releaser/llm/costs.dart';
import 'package:releaser/llm/prompt.dart';
import 'package:test/test.dart';

import 'support/fake_ai_gateway_client.dart';

void main() {
  group('runStructuredPrompt', () {
    test('deserializes the response content via fromJson', () async {
      final client = FakeAiGatewayClient([
        {'greeting': 'hello'},
      ]);

      final result = await runStructuredPrompt(client, 'say hi', {
        'type': 'object',
      }, (json) => json['greeting'] as String);

      expect(result, 'hello');
      expect(client.prompts, ['say hi']);
    });

    test('records usage against the cost tracker when given one', () async {
      final client = FakeAiGatewayClient(
        [
          {'greeting': 'hello'},
        ],
        usage: const LlmUsage(
          model: 'claude-sonnet-4-6',
          inputTokens: 100,
          outputTokens: 50,
        ),
      );
      final tracker = LlmCostTracker();

      await runStructuredPrompt(
        client,
        'say hi',
        {'type': 'object'},
        (json) => json['greeting'] as String,
        costTracker: tracker,
        costLabel: 'Greeting',
      );

      final messages = <String>[];
      tracker.printSummary(
        Logger.detached('test')
          ..onRecord.listen((r) => messages.add(r.message)),
      );

      expect(messages, [contains('100in + 50out'), contains('Estimated cost')]);
    });

    test('is a no-op on the cost tracker when none is given', () async {
      final client = FakeAiGatewayClient([
        {'greeting': 'hello'},
      ]);

      // Should not throw for lack of a cost tracker.
      await runStructuredPrompt(client, 'say hi', {
        'type': 'object',
      }, (json) => json['greeting'] as String);
    });
  });
}
