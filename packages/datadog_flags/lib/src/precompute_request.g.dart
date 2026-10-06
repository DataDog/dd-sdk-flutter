// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'precompute_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PrecomputeRequestToJson(PrecomputeRequest instance) =>
    <String, dynamic>{
      'data': instance.data.toJson(),
    };

Map<String, dynamic> _$PrecomputeRequestDataToJson(
        PrecomputeRequestData instance) =>
    <String, dynamic>{
      'type': instance.type,
      'attributes': instance.attributes.toJson(),
    };

Map<String, dynamic> _$PrecomputeRequestAttributesToJson(
        PrecomputeRequestAttributes instance) =>
    <String, dynamic>{
      'env': instance.env.toJson(),
      'source': instance.source.toJson(),
      'subject': instance.subject.toJson(),
    };

Map<String, dynamic> _$PrecomputeRequestEnvToJson(
        PrecomputeRequestEnv instance) =>
    <String, dynamic>{
      'dd_env': instance.ddEnv,
    };

Map<String, dynamic> _$PrecomputeRequestSourceToJson(
        PrecomputeRequestSource instance) =>
    <String, dynamic>{
      'sdk_name': instance.sdkName,
      'sdk_version': instance.sdkVersion,
    };

Map<String, dynamic> _$PrecomputeRequestSubjectToJson(
        PrecomputeRequestSubject instance) =>
    <String, dynamic>{
      'targeting_key': instance.targetingKey,
      'targeting_attributes':
          sanitizeJsonScalarObject(instance.targetingAttributes),
    };
