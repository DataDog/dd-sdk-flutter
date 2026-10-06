// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'datadog_flags_config.dart';
import 'evaluation_context.dart';
import 'json_value.dart';
import 'sdk_metadata.dart';

part 'precompute_request.g.dart';

@immutable
@JsonSerializable(createFactory: false, explicitToJson: true)
final class PrecomputeRequest {
  final PrecomputeRequestData data;

  const PrecomputeRequest({required this.data});

  factory PrecomputeRequest.fromContext({
    required DatadogFlagsConfig datadogConfig,
    required FlagsEvaluationContext evaluationContext,
  }) {
    return PrecomputeRequest(
      data: PrecomputeRequestData(
        attributes: PrecomputeRequestAttributes(
          env: PrecomputeRequestEnv(ddEnv: datadogConfig.env),
          source: PrecomputeRequestSource(
            sdkName: datadogFlagsSdkName,
            sdkVersion: datadogFlagsSdkVersion,
          ),
          subject: PrecomputeRequestSubject(
            targetingKey: evaluationContext.targetingKey ?? '',
            targetingAttributes: evaluationContext.attributes,
          ),
        ),
      ),
    );
  }

  Map<String, Object?> toJson() => _$PrecomputeRequestToJson(this);
}

@immutable
@JsonSerializable(createFactory: false, explicitToJson: true)
final class PrecomputeRequestData {
  final String type;
  final PrecomputeRequestAttributes attributes;

  const PrecomputeRequestData({
    this.type = 'precompute-assignments-request',
    required this.attributes,
  });

  Map<String, Object?> toJson() => _$PrecomputeRequestDataToJson(this);
}

@immutable
@JsonSerializable(createFactory: false, explicitToJson: true)
final class PrecomputeRequestAttributes {
  final PrecomputeRequestEnv env;
  final PrecomputeRequestSource source;
  final PrecomputeRequestSubject subject;

  const PrecomputeRequestAttributes({
    required this.env,
    required this.source,
    required this.subject,
  });

  Map<String, Object?> toJson() => _$PrecomputeRequestAttributesToJson(this);
}

@immutable
@JsonSerializable(createFactory: false)
final class PrecomputeRequestEnv {
  @JsonKey(name: 'dd_env')
  final String ddEnv;

  const PrecomputeRequestEnv({required this.ddEnv});

  Map<String, Object?> toJson() => _$PrecomputeRequestEnvToJson(this);
}

@immutable
@JsonSerializable(createFactory: false)
final class PrecomputeRequestSource {
  @JsonKey(name: 'sdk_name')
  final String sdkName;
  @JsonKey(name: 'sdk_version')
  final String sdkVersion;

  const PrecomputeRequestSource({
    required this.sdkName,
    required this.sdkVersion,
  });

  Map<String, Object?> toJson() => _$PrecomputeRequestSourceToJson(this);
}

@immutable
@JsonSerializable(createFactory: false)
final class PrecomputeRequestSubject {
  @JsonKey(name: 'targeting_key')
  final String targetingKey;
  @JsonKey(name: 'targeting_attributes', toJson: sanitizeJsonScalarObject)
  final Map<String, Object?> targetingAttributes;

  const PrecomputeRequestSubject({
    required this.targetingKey,
    required this.targetingAttributes,
  });

  Map<String, Object?> toJson() => _$PrecomputeRequestSubjectToJson(this);
}
