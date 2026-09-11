// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_gateway.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AnthropicMessageResponse _$AnthropicMessageResponseFromJson(
  Map<String, dynamic> json,
) => AnthropicMessageResponse(
  model: json['model'] as String,
  content: (json['content'] as List<dynamic>)
      .map((e) => AnthropicContentBlock.fromJson(e as Map<String, dynamic>))
      .toList(),
  usage: AnthropicUsage.fromJson(json['usage'] as Map<String, dynamic>),
);

AnthropicContentBlock _$AnthropicContentBlockFromJson(
  Map<String, dynamic> json,
) => AnthropicContentBlock(text: json['text'] as String);

AnthropicUsage _$AnthropicUsageFromJson(Map<String, dynamic> json) =>
    AnthropicUsage(
      inputTokens: (json['input_tokens'] as num).toInt(),
      outputTokens: (json['output_tokens'] as num).toInt(),
    );

Map<String, dynamic> _$AnthropicMessageRequestToJson(
  AnthropicMessageRequest instance,
) => <String, dynamic>{
  'model': instance.model,
  'max_tokens': instance.maxTokens,
  'output_config': instance.outputConfig,
  'messages': instance.messages,
};

Map<String, dynamic> _$AnthropicOutputConfigToJson(
  AnthropicOutputConfig instance,
) => <String, dynamic>{'format': instance.format};

Map<String, dynamic> _$AnthropicFormatToJson(AnthropicFormat instance) =>
    <String, dynamic>{'type': instance.type, 'schema': instance.schema};

Map<String, dynamic> _$AnthropicMessageToJson(AnthropicMessage instance) =>
    <String, dynamic>{'role': instance.role, 'content': instance.content};
