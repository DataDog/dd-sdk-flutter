// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'assignment.dart';
import 'datadog_flags_config.dart';
import 'flags_configuration.dart';
import 'evaluation_context.dart';
import 'flag_key_obfuscation.dart';
import 'flags_error.dart';
import 'flags_log.dart';
import 'precompute_request.dart';
import 'precompute_response.dart';
import 'response_protection.dart';
import 'split_features.dart';

/// Returns the precompute assignments endpoint for [datadogConfig].
Uri flagAssignmentsEndpoint({
  required DatadogFlagsConfig datadogConfig,
  required DatadogFlagsConfiguration configuration,
}) {
  return configuration.customFlagsEndpoint ??
      datadogConfig.flagsEndpoint().replace(path: '/precompute-assignments');
}

class FlagAssignmentsFetcher {
  final DatadogFlagsConfig datadogConfig;
  final DatadogFlagsConfiguration configuration;
  final http.Client httpClient;

  /// Protected assignment transport. When set, it replaces [httpClient] for
  /// assignment requests.
  final AssignmentProtection? protection;
  final UnknownDestinationWarnings _unknownDestinations;

  FlagAssignmentsFetcher({
    required this.datadogConfig,
    required this.configuration,
    required this.httpClient,
    this.protection,
    FlagsLogger logger = const FlagsLogger(),
  }) : _unknownDestinations = UnknownDestinationWarnings(logger);

  /// Policy identifier recorded with assignments that this fetcher returns.
  ///
  /// `null` means that assignments are fetched without response protection.
  String? get responseProtectionPolicy => protection?.policyId;

  Future<PrecomputedAssignments> fetch(
    FlagsEvaluationContext evaluationContext,
  ) async {
    final endpoint = flagAssignmentsEndpoint(
      datadogConfig: datadogConfig,
      configuration: configuration,
    );
    final client = switch (protection) {
      null => httpClient,
      AssignmentProtection(error: final error?) => throw error,
      AssignmentProtection(client: final client?) => client,
      AssignmentProtection() => throw FlagsException.invalidConfiguration(
        'Response protection has no assignment transport.',
      ),
    };
    final http.Response response;
    try {
      response = await client.post(
        endpoint,
        headers: _headers(),
        body: jsonEncode(
          PrecomputeRequest.fromContext(
            datadogConfig: datadogConfig,
            evaluationContext: evaluationContext,
          ).toJson(),
        ),
      );
    } catch (error) {
      throw FlagsException.networkError(
        'Failed to fetch flag assignments.',
        cause: error,
      );
    }

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
      for (final assignment in attributes.flags.values) {
        _unknownDestinations.check(assignment.features);
      }
      return PrecomputedAssignments(
        flags: attributes.flags,
        createdAt: attributes.createdAt,
        environment: attributes.environment,
        obfuscation: attributes.obfuscation,
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
      // Avoid adding a header that a web proxy's CORS policy may reject.
      if (configuration.customFlagsEndpoint == null)
        'X-DD-FEATURE-FLAGS-CAPABILITIES':
            (supportedFlagsCapabilities
                    .map((capability) => capability.wireName)
                    .toList()
                  ..sort())
                .join(','),
      'dd-client-token': datadogConfig.clientToken,
      'dd-application-id': ?datadogConfig.applicationId,
      ...?configuration.customFlagsHeaders,
    };
  }
}

Map<String, Object?> _asObject(Object? value, String name) {
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  throw FormatException('$name must be a JSON object');
}
