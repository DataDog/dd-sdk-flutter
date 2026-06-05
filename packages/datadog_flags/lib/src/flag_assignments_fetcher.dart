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
    final httpStopwatch = Stopwatch()..start();
    late http.Response response;
    try {
      response = await httpClient.post(
        endpoint,
        headers: _headers(),
        body: jsonEncode(_requestBody(evaluationContext)),
      );
      httpStopwatch.stop();
    } catch (_) {
      httpStopwatch.stop();
      _reportDiagnostics(DatadogFlagsAssignmentsFetchDiagnostics(
        endpoint: endpoint,
        statusCode: null,
        httpDuration: httpStopwatch.elapsed,
        deserializationDuration: null,
        responseBodyBytes: 0,
        receivedFlagCount: null,
        assignmentCount: null,
      ));
      rethrow;
    }

    final responseBodyBytes = response.bodyBytes.length;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _reportDiagnostics(DatadogFlagsAssignmentsFetchDiagnostics(
        endpoint: endpoint,
        statusCode: response.statusCode,
        httpDuration: httpStopwatch.elapsed,
        deserializationDuration: null,
        responseBodyBytes: responseBodyBytes,
        receivedFlagCount: null,
        assignmentCount: null,
      ));
      throw FlagsException.networkError(
        'Unexpected flag assignments response status ${response.statusCode}.',
      );
    }

    final deserializationStopwatch = Stopwatch()..start();
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
      deserializationStopwatch.stop();
      _reportDiagnostics(DatadogFlagsAssignmentsFetchDiagnostics(
        endpoint: endpoint,
        statusCode: response.statusCode,
        httpDuration: httpStopwatch.elapsed,
        deserializationDuration: deserializationStopwatch.elapsed,
        responseBodyBytes: responseBodyBytes,
        receivedFlagCount: flags.length,
        assignmentCount: assignments.length,
      ));
      return assignments;
    } catch (error) {
      deserializationStopwatch.stop();
      _reportDiagnostics(DatadogFlagsAssignmentsFetchDiagnostics(
        endpoint: endpoint,
        statusCode: response.statusCode,
        httpDuration: httpStopwatch.elapsed,
        deserializationDuration: deserializationStopwatch.elapsed,
        responseBodyBytes: responseBodyBytes,
        receivedFlagCount: null,
        assignmentCount: null,
      ));
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

  void _reportDiagnostics(
    DatadogFlagsAssignmentsFetchDiagnostics diagnostics,
  ) {
    try {
      configuration.assignmentsFetchObserver?.call(diagnostics);
    } catch (_) {
      // Diagnostics callbacks must not affect flag assignment fetching.
    }
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
