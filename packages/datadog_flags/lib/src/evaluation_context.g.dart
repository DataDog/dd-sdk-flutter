// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'evaluation_context.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FlagsEvaluationContext _$FlagsEvaluationContextFromJson(
        Map<String, dynamic> json) =>
    FlagsEvaluationContext(
      targetingKey: json['targetingKey'] as String?,
      attributes: json['attributes'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$FlagsEvaluationContextToJson(
        FlagsEvaluationContext instance) =>
    <String, dynamic>{
      if (instance.targetingKey case final value?) 'targetingKey': value,
      'attributes': sanitizeJsonValue(instance.attributes),
    };
