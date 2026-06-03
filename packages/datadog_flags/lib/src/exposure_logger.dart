// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'assignment.dart';
import 'datadog_context.dart';
import 'datadog_event_context.dart';
import 'flags_configuration.dart';
import 'flags_context.dart';
import 'json_value.dart';

class ExposureLogger {
  final DatadogFlagsContext datadogContext;
  final DatadogFlagsConfiguration configuration;
  final http.Client httpClient;
  final Set<String> _loggedExposures = {};

  ExposureLogger({
    required this.datadogContext,
    required this.configuration,
    required this.httpClient,
  });

  Future<void> logExposure({
    required String flagKey,
    required FlagAssignment assignment,
    required DatadogFlagsEvaluationContext evaluationContext,
  }) async {
    if (!configuration.trackExposures || !assignment.doLog) {
      return;
    }

    final exposureKey = [
      evaluationContext.targetingKey,
      flagKey,
      assignment.allocationKey,
      assignment.variationKey,
    ].join('|');
    if (!_loggedExposures.add(exposureKey)) {
      return;
    }

    final endpoint = configuration.customExposureEndpoint ??
        datadogContext.intakeEndpoint().replace(
          path: '/api/v2/exposures',
          queryParameters: {'ddsource': datadogContext.source},
        );
    final event = removeNullValues({
      'timestamp': configuration.dateProvider().millisecondsSinceEpoch,
      'service': datadogContext.service,
      'rum': rumContextFor(datadogContext),
      'allocation': {'key': assignment.allocationKey},
      'flag': {'key': flagKey},
      'variant': {'key': assignment.variationKey},
      'subject': {
        'id': evaluationContext.targetingKey,
        'attributes': sanitizeJsonValue(evaluationContext.attributes),
      },
    });

    try {
      final response = await httpClient.post(
        endpoint,
        headers: {
          'Content-Type': 'text/plain;charset=UTF-8',
          'DD-API-KEY': datadogContext.clientToken,
          'DD-EVP-ORIGIN': datadogContext.source,
          'DD-EVP-ORIGIN-VERSION': datadogContext.sdkVersion,
          'DD-REQUEST-ID': const Uuid().v4(),
        },
        body: jsonEncode(event),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _loggedExposures.remove(exposureKey);
      }
    } catch (_) {
      _loggedExposures.remove(exposureKey);
    }
  }
}
