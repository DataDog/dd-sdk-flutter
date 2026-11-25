// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fixture_wire_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FixtureRequest _$FixtureRequestFromJson(Map<String, dynamic> json) =>
    FixtureRequest(
      FixtureRequestData.fromJson(json['data'] as Map<String, dynamic>),
    );

FixtureRequestData _$FixtureRequestDataFromJson(Map<String, dynamic> json) =>
    FixtureRequestData(
      FixtureRequestAttributes.fromJson(
        json['attributes'] as Map<String, dynamic>,
      ),
    );

FixtureRequestAttributes _$FixtureRequestAttributesFromJson(
  Map<String, dynamic> json,
) => FixtureRequestAttributes(
  FixtureSubject.fromJson(json['subject'] as Map<String, dynamic>),
);

FixtureSubject _$FixtureSubjectFromJson(Map<String, dynamic> json) =>
    FixtureSubject(json['targeting_key'] as String?);

Map<String, dynamic> _$FixtureResponseToJson(FixtureResponse instance) =>
    <String, dynamic>{'data': instance.data.toJson()};

Map<String, dynamic> _$FixtureResponseDataToJson(
  FixtureResponseData instance,
) => <String, dynamic>{'attributes': instance.attributes.toJson()};

Map<String, dynamic> _$FixtureResponseAttributesToJson(
  FixtureResponseAttributes instance,
) => <String, dynamic>{
  'flags': instance.flags.map((k, e) => MapEntry(k, e.toJson())),
};

Map<String, dynamic> _$FixtureFlagToJson(FixtureFlag instance) =>
    <String, dynamic>{
      'allocationKey': instance.allocationKey,
      'variationKey': instance.variationKey,
      'variationValue': instance.variationValue,
      'variationType': instance.variationType,
      'reason': instance.reason,
      'doLog': instance.doLog,
    };
