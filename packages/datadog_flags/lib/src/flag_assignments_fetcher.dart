// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'assignment.dart';
import 'assignment_request_client.dart';
import 'datadog_flags_config.dart';
import 'evaluation_context.dart';
import 'flags_error.dart';
import 'flags_configuration.dart';
import 'precompute_request.dart';
import 'precompute_response.dart';

class FlagAssignmentsFetcher {
  final DatadogFlagsConfig datadogConfig;
  final DatadogFlagsConfiguration configuration;
  final http.Client httpClient;
  final Future<void> Function(Duration) _delay;
  final double Function() _randomDouble;

  FlagAssignmentsFetcher({
    required this.datadogConfig,
    required this.configuration,
    required this.httpClient,
    Future<void> Function(Duration)? delay,
    double Function()? randomDouble,
  })  : _delay = delay ?? _defaultDelay,
        _randomDouble = randomDouble ?? Random().nextDouble;

  Future<PrecomputedAssignments> fetch(
    FlagsEvaluationContext evaluationContext,
  ) async {
    final endpoint = configuration.customFlagsEndpoint ??
        datadogConfig.flagsEndpoint().replace(path: '/precompute-assignments');
    final body = jsonEncode(
      PrecomputeRequest.fromContext(
        datadogConfig: datadogConfig,
        evaluationContext: evaluationContext,
      ).toJson(),
    );
    final response = await _fetchResponse(endpoint, body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FlagsException.networkError(
        'Unexpected flag assignments response status ${response.statusCode}.',
      );
    }

    try {
      final decoded = PrecomputeResponse.fromJson(
        _asObject(jsonDecode(response.body), 'response'),
      );
      final attributes = decoded.data.attributes;
      return PrecomputedAssignments(
        flags: attributes.flags,
        createdAt: attributes.createdAt,
        environment: attributes.environment,
      );
    } catch (error) {
      throw FlagsException.invalidResponse(
        'Failed to decode flag assignments response: $error',
        cause: error,
      );
    }
  }

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/vnd.api+json',
      'dd-client-token': datadogConfig.clientToken,
      if (datadogConfig.applicationId case final applicationId?)
        'dd-application-id': applicationId,
      ...?configuration.customFlagsHeaders,
    };
  }

  Future<http.Response> _fetchResponse(Uri endpoint, String body) async {
    final customClient = configuration.assignmentRequestHttpClient;
    final client = customClient ??
        buildAssignmentRequestClient(
          httpClient,
          timeout: configuration.assignmentRequestTimeout,
          retries: configuration.assignmentRequestRetryCount,
          delay: _delay,
          randomDouble: _randomDouble,
          dateProvider: configuration.dateProvider,
        );
    final request = http.Request('POST', endpoint);
    request.headers.addAll(_headers());
    request.body = body;

    try {
      final streamedResponse = await client.send(request);
      return await http.Response.fromStream(streamedResponse);
    } catch (error) {
      throw FlagsException.networkError(
        'Failed to fetch flag assignments.',
        cause: error,
      );
    }
  }
}

Future<void> _defaultDelay(Duration duration) => Future<void>.delayed(duration);

Map<String, Object?> _asObject(Object? value, String name) {
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  throw FormatException('$name must be a JSON object');
}
