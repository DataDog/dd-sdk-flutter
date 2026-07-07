// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assignment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FlagAssignment _$FlagAssignmentFromJson(Map<String, dynamic> json) =>
    FlagAssignment._(
      allocationKey: json['allocationKey'] as String,
      variationKey: json['variationKey'] as String,
      variationType:
          FlagVariationType.fromWireName(json['variationType'] as String),
      variationValue: json['variationValue'] as Object,
      reason: json['reason'] as String,
      doLog: json['doLog'] as bool,
    );

Map<String, dynamic> _$FlagAssignmentToJson(FlagAssignment instance) =>
    <String, dynamic>{
      'allocationKey': instance.allocationKey,
      'variationKey': instance.variationKey,
      'variationType': FlagVariationType.toWireName(instance.variationType),
      'variationValue': sanitizeJsonValue(instance.variationValue),
      'reason': instance.reason,
      'doLog': instance.doLog,
    };
