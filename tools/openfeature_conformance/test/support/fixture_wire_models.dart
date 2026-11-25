// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:json_annotation/json_annotation.dart';

part 'fixture_wire_models.g.dart';

// These fixture models are independent of the SDK's transport models.
@JsonSerializable(createToJson: false)
final class FixtureRequest {
  final FixtureRequestData data;
  FixtureRequest(this.data);
  factory FixtureRequest.fromJson(Map<String, dynamic> json) =>
      _$FixtureRequestFromJson(json);
}

@JsonSerializable(createToJson: false)
final class FixtureRequestData {
  final FixtureRequestAttributes attributes;
  FixtureRequestData(this.attributes);
  factory FixtureRequestData.fromJson(Map<String, dynamic> json) =>
      _$FixtureRequestDataFromJson(json);
}

@JsonSerializable(createToJson: false)
final class FixtureRequestAttributes {
  final FixtureSubject subject;
  FixtureRequestAttributes(this.subject);
  factory FixtureRequestAttributes.fromJson(Map<String, dynamic> json) =>
      _$FixtureRequestAttributesFromJson(json);
}

@JsonSerializable(createToJson: false)
final class FixtureSubject {
  @JsonKey(name: 'targeting_key')
  final String? targetingKey;
  FixtureSubject(this.targetingKey);
  factory FixtureSubject.fromJson(Map<String, dynamic> json) =>
      _$FixtureSubjectFromJson(json);
}

@JsonSerializable(createFactory: false, explicitToJson: true)
final class FixtureResponse {
  final FixtureResponseData data;
  FixtureResponse(this.data);
  Map<String, dynamic> toJson() => _$FixtureResponseToJson(this);
}

@JsonSerializable(createFactory: false, explicitToJson: true)
final class FixtureResponseData {
  final FixtureResponseAttributes attributes;
  FixtureResponseData(this.attributes);
  Map<String, dynamic> toJson() => _$FixtureResponseDataToJson(this);
}

@JsonSerializable(createFactory: false, explicitToJson: true)
final class FixtureResponseAttributes {
  final Map<String, FixtureFlag> flags;
  FixtureResponseAttributes(this.flags);
  Map<String, dynamic> toJson() => _$FixtureResponseAttributesToJson(this);
}

@JsonSerializable(createFactory: false)
final class FixtureFlag {
  final String allocationKey = 'contract-allocation';
  final String variationKey = 'contract-variant';
  final Object variationValue;
  final String variationType;
  final String reason = 'TARGETING_MATCH';
  final bool doLog = false;

  FixtureFlag(this.variationValue)
    : variationType = switch (variationValue) {
        bool() => 'boolean',
        int() => 'integer',
        double() => 'float',
        String() => 'string',
        _ => 'object',
      };

  Map<String, dynamic> toJson() => _$FixtureFlagToJson(this);
}
