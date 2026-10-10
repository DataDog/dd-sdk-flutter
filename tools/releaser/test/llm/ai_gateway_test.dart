// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:releaser/llm/ai_gateway.dart';
import 'package:test/test.dart';

void main() {
  group('AnthropicMessageResponse.fromJson', () {
    test('parses a real-shaped Messages API response', () {
      final response = AnthropicMessageResponse.fromJson(
        jsonDecode('''
{
  "model": "claude-sonnet-4-6",
  "content": [{"type": "text", "text": "{\\"greeting\\": \\"hello\\"}"}],
  "usage": {"input_tokens": 100, "output_tokens": 50}
}
'''),
      );

      expect(response.model, 'claude-sonnet-4-6');
      expect(response.content.single.text, '{"greeting": "hello"}');
      expect(response.usage.inputTokens, 100);
      expect(response.usage.outputTokens, 50);
    });
  });

  group('AnthropicMessageRequest.toJson', () {
    test(
      'round-trips through jsonEncode, including nested request objects',
      () {
        final request = AnthropicMessageRequest(
          model: 'claude-sonnet-4-6',
          maxTokens: 4096,
          outputConfig: AnthropicOutputConfig(
            format: AnthropicFormat(
              type: 'json_schema',
              schema: {'type': 'object'},
            ),
          ),
          messages: [AnthropicMessage(role: 'user', content: 'hi — there')],
        );

        final decoded =
            jsonDecode(jsonEncode(request.toJson())) as Map<String, dynamic>;

        expect(decoded, {
          'model': 'claude-sonnet-4-6',
          'max_tokens': 4096,
          'output_config': {
            'format': {
              'type': 'json_schema',
              'schema': {'type': 'object'},
            },
          },
          'messages': [
            {'role': 'user', 'content': 'hi — there'},
          ],
        });
      },
    );
  });
}
