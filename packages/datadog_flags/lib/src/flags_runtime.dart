// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:http/http.dart' as http;

import 'datadog_flags_config.dart';
import 'flags_configuration.dart';

class FlagsRuntime {
  final DatadogFlagsConfiguration configuration;
  final DatadogFlagsConfig datadogConfig;
  final http.Client httpClient;

  const FlagsRuntime({
    required this.configuration,
    required this.datadogConfig,
    required this.httpClient,
  });
}

bool shouldRetryFlagsUpload(int statusCode) {
  return statusCode == 408 || statusCode == 429 || statusCode >= 500;
}
