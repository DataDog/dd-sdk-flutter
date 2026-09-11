// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:json_annotation/json_annotation.dart';

part 'ai_gateway.g.dart';

const defaultModel = 'claude-sonnet-4-6';

/// This tool's AI Gateway feature id, registered via #project-gamma-q-and-a.
const mlAppId = 'dd-sdk-flutter.releaser.changelog';

/// One LLM call's token usage, for [LlmCostTracker] (`costs.dart`).
class LlmUsage {
  final String model;
  final int inputTokens;
  final int outputTokens;

  const LlmUsage({
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
  });
}

/// The result of a schema-constrained prompt: the raw parsed JSON payload
/// (deserialized by the caller into its own response type -- see
/// `prompt.dart`'s `runStructuredPrompt`) plus usage for cost tracking.
class StructuredResponse {
  final Map<String, dynamic> content;
  final LlmUsage usage;

  const StructuredResponse({required this.content, required this.usage});
}

/// The Anthropic Messages API response shape the AI Gateway returns --
/// only the fields this tool reads. Read-only: never re-serialized.
@JsonSerializable(createToJson: false)
class AnthropicMessageResponse {
  final String model;
  final List<AnthropicContentBlock> content;
  final AnthropicUsage usage;

  AnthropicMessageResponse({
    required this.model,
    required this.content,
    required this.usage,
  });

  factory AnthropicMessageResponse.fromJson(Map<String, dynamic> json) =>
      _$AnthropicMessageResponseFromJson(json);
}

@JsonSerializable(createToJson: false)
class AnthropicContentBlock {
  final String text;

  AnthropicContentBlock({required this.text});

  factory AnthropicContentBlock.fromJson(Map<String, dynamic> json) =>
      _$AnthropicContentBlockFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class AnthropicUsage {
  final int inputTokens;
  final int outputTokens;

  AnthropicUsage({required this.inputTokens, required this.outputTokens});

  factory AnthropicUsage.fromJson(Map<String, dynamic> json) =>
      _$AnthropicUsageFromJson(json);
}

/// An Anthropic Messages API request body, schema-constrained via
/// `output_config`. Write-only: never deserialized.
@JsonSerializable(fieldRename: FieldRename.snake, createFactory: false)
class AnthropicMessageRequest {
  final String model;
  final int maxTokens;
  final AnthropicOutputConfig outputConfig;
  final List<AnthropicMessage> messages;

  AnthropicMessageRequest({
    required this.model,
    required this.maxTokens,
    required this.outputConfig,
    required this.messages,
  });

  Map<String, dynamic> toJson() => _$AnthropicMessageRequestToJson(this);
}

@JsonSerializable(createFactory: false)
class AnthropicOutputConfig {
  final AnthropicFormat format;

  AnthropicOutputConfig({required this.format});

  Map<String, dynamic> toJson() => _$AnthropicOutputConfigToJson(this);
}

@JsonSerializable(createFactory: false)
class AnthropicFormat {
  final String type;
  final Map<String, dynamic> schema;

  AnthropicFormat({required this.type, required this.schema});

  Map<String, dynamic> toJson() => _$AnthropicFormatToJson(this);
}

@JsonSerializable(createFactory: false)
class AnthropicMessage {
  final String role;
  final String content;

  AnthropicMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => _$AnthropicMessageToJson(this);
}

/// What `changelog.dart`'s 3-pass pipeline needs from an AI Gateway client --
/// injected so a fake can stand in for [HttpAiGatewayClient] in tests.
abstract class AiGatewayClient {
  Future<StructuredResponse> createStructuredMessage({
    required String prompt,
    required Map<String, dynamic> schema,
    String model = defaultModel,
    int maxTokens = 4096,
  });
}

/// A real [AiGatewayClient] against `ai-gateway.us1.ddbuild.io`. Header
/// values (`provider`/`source`/`org-id`) are likely gateway-side
/// allowlisted for this audience, so they're kept fixed rather than made
/// configurable.
class HttpAiGatewayClient implements AiGatewayClient {
  static final _endpoint = Uri.parse(
    'https://ai-gateway.us1.ddbuild.io/v1/messages',
  );

  final String token;
  final HttpClient _httpClient;

  HttpAiGatewayClient(this.token, {HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  /// Reads `AI_GATEWAY_TOKEN` (e.g. from `ddtool auth token
  /// rapid-ai-platform --datacenter us1.ddbuild.io` locally, or
  /// `authanywhere` in CI).
  factory HttpAiGatewayClient.fromEnvironment() {
    final token = Platform.environment['AI_GATEWAY_TOKEN'];
    if (token == null) {
      throw StateError('AI_GATEWAY_TOKEN is not set.');
    }
    return HttpAiGatewayClient(token);
  }

  @override
  Future<StructuredResponse> createStructuredMessage({
    required String prompt,
    required Map<String, dynamic> schema,
    String model = defaultModel,
    int maxTokens = 4096,
  }) async {
    final request = await _httpClient.postUrl(_endpoint);
    request.headers.contentType = ContentType(
      'application',
      'json',
      charset: 'utf-8',
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set('provider', 'anthropic');
    request.headers.set('source', 'claude-code');
    request.headers.set('org-id', '2');
    request.headers.set('ml_app_id', mlAppId);
    final requestBody = AnthropicMessageRequest(
      model: model,
      maxTokens: maxTokens,
      outputConfig: AnthropicOutputConfig(
        format: AnthropicFormat(type: 'json_schema', schema: schema),
      ),
      messages: [AnthropicMessage(role: 'user', content: prompt)],
    );
    // request.write() defaults to Latin-1, which throws on the em-dashes
    // and smart quotes these prompts contain -- add() writes raw UTF-8
    // bytes instead.
    request.add(utf8.encode(jsonEncode(requestBody.toJson())));

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw Exception('AI Gateway returned ${response.statusCode}: $body');
    }

    final message = AnthropicMessageResponse.fromJson(
      jsonDecode(body) as Map<String, dynamic>,
    );

    return StructuredResponse(
      content: jsonDecode(message.content.first.text) as Map<String, dynamic>,
      usage: LlmUsage(
        model: message.model,
        inputTokens: message.usage.inputTokens,
        outputTokens: message.usage.outputTokens,
      ),
    );
  }
}
