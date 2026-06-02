// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:http/http.dart' as http;

import 'datadog_context.dart';
import 'flags_store.dart';

class DatadogFlagsConfiguration {
  final Uri? customFlagsEndpoint;
  final Map<String, String>? customFlagsHeaders;
  final Uri? customExposureEndpoint;
  final bool trackExposures;
  final Uri? customEvaluationEndpoint;
  final bool trackEvaluations;
  final Duration evaluationFlushInterval;
  final bool rumIntegrationEnabled;
  final DatadogFlagsStore? store;
  final http.Client? httpClient;
  final DatadogFlagsContext? datadogContext;
  final DateTime Function() dateProvider;
  final int evaluationMaxBatchSize;

  const DatadogFlagsConfiguration({
    this.customFlagsEndpoint,
    this.customFlagsHeaders,
    this.customExposureEndpoint,
    this.trackExposures = true,
    this.customEvaluationEndpoint,
    this.trackEvaluations = true,
    this.evaluationFlushInterval = const Duration(seconds: 10),
    this.rumIntegrationEnabled = true,
    this.store,
    this.httpClient,
    this.datadogContext,
    this.dateProvider = DateTime.now,
    this.evaluationMaxBatchSize = 1000,
  });

  DatadogFlagsConfiguration normalized() {
    return DatadogFlagsConfiguration(
      customFlagsEndpoint: customFlagsEndpoint,
      customFlagsHeaders: customFlagsHeaders,
      customExposureEndpoint: customExposureEndpoint,
      trackExposures: trackExposures,
      customEvaluationEndpoint: customEvaluationEndpoint,
      trackEvaluations: trackEvaluations,
      evaluationFlushInterval: _clamp(evaluationFlushInterval, min: 1, max: 60),
      rumIntegrationEnabled: rumIntegrationEnabled,
      store: store,
      httpClient: httpClient,
      datadogContext: datadogContext,
      dateProvider: dateProvider,
      evaluationMaxBatchSize: evaluationMaxBatchSize,
    );
  }
}

Duration _clamp(Duration value, {required int min, required int max}) {
  if (value < Duration(seconds: min)) {
    return Duration(seconds: min);
  }
  if (value > Duration(seconds: max)) {
    return Duration(seconds: max);
  }
  return value;
}
