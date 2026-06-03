// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'assignment.dart';
import 'datadog_context.dart';
import 'flags_configuration.dart';
import 'flags_context.dart';
import 'flags_error.dart';
import 'json_value.dart';

class FlagAssignmentsFetcher {
  final DatadogFlagsContext datadogContext;
  final DatadogFlagsConfiguration configuration;
  final http.Client httpClient;

  FlagAssignmentsFetcher({
    required this.datadogContext,
    required this.configuration,
    required this.httpClient,
  });

  Future<Map<String, FlagAssignment>> fetch(
    DatadogFlagsEvaluationContext evaluationContext,
  ) async {
    final endpoint = configuration.customFlagsEndpoint ??
        datadogContext.flagsEndpoint().replace(
              path: '/precompute-assignments',
            );
    final response = await httpClient.post(
      endpoint,
      headers: _headers(),
      body: jsonEncode(_requestBody(evaluationContext)),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FlagsException.networkError(
        'Unexpected flag assignments response status ${response.statusCode}.',
      );
    }

    try {
      final decoded = jsonDecode(response.body) as Map<String, Object?>;
      final data = decoded['data'] as Map<String, Object?>;
      final attributes = data['attributes'] as Map<String, Object?>;
      final flags = attributes['flags'] as Map<String, Object?>;
      final assignments = <String, FlagAssignment>{};
      for (final entry in flags.entries) {
        final assignmentJson = entry.value as Map<String, Object?>;
        final variationType = normalizeVariationType(
          assignmentJson['variationType'] as String?,
          assignmentJson['variationValue'],
        );
        if (variationType == FlagVariationType.unknown) {
          continue;
        }
        assignments[entry.key] = FlagAssignment(
          allocationKey: assignmentJson['allocationKey'] as String,
          variationKey: assignmentJson['variationKey'] as String,
          variationType: variationType,
          variationValue: _valueForType(
            variationType,
            assignmentJson['variationValue'],
          ),
          reason: assignmentJson['reason'] as String,
          doLog: assignmentJson['doLog'] as bool,
        );
      }
      return assignments;
    } catch (error) {
      throw FlagsException.invalidResponse(
        'Failed to decode flag assignments response: $error',
      );
    }
  }

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/vnd.api+json',
      'dd-client-token': datadogContext.clientToken,
      if (datadogContext.applicationId != null)
        'dd-application-id': datadogContext.applicationId!,
      ...?configuration.customFlagsHeaders,
    };
  }

  Map<String, Object?> _requestBody(
    DatadogFlagsEvaluationContext evaluationContext,
  ) {
    return {
      'data': {
        'type': 'precompute-assignments-request',
        'attributes': {
          'env': {
            'dd_env': datadogContext.env,
          },
          'subject': {
            'targeting_key': evaluationContext.targetingKey,
            'targeting_attributes': sanitizeJsonValue(
              evaluationContext.attributes,
            ),
          },
        },
      },
    };
  }
}

Object? _valueForType(FlagVariationType type, Object? value) {
  return switch (type) {
    FlagVariationType.integer when value is int => value,
    FlagVariationType.float when value is num => value.toDouble(),
    FlagVariationType.object => sanitizeJsonValue(value),
    _ => value,
  };
}
