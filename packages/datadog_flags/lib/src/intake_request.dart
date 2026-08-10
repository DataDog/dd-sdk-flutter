// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import 'intake_platform.dart';
import 'sdk_metadata.dart';

@immutable
final class FlagsIntakeRequest {
  final Uri endpoint;
  final Map<String, String> headers;
  final String body;

  const FlagsIntakeRequest({
    required this.endpoint,
    required this.headers,
    required this.body,
  });
}

FlagsIntakeRequest buildFlagsIntakeRequest({
  required Uri endpoint,
  required String clientToken,
  required String nativeContentType,
  required String Function() nativeBodyBuilder,
  required String Function() webBodyBuilder,
}) {
  final requestId = const Uuid().v4();
  final queryParameters = {
    ...endpoint.queryParameters,
    'ddsource': datadogFlagsSource,
    if (isWebFlagsIntake) ...{
      'dd-api-key': clientToken,
      'dd-evp-origin-version': datadogFlagsSdkVersion,
      'dd-evp-origin': datadogFlagsSource,
      'dd-request-id': requestId,
    },
  };

  if (isWebFlagsIntake) {
    // Match the Browser SDK transport so the browser does not send an OPTIONS
    // CORS preflight before each intake request.
    return FlagsIntakeRequest(
      endpoint: endpoint.replace(queryParameters: queryParameters),
      headers: const {'Content-Type': 'text/plain'},
      body: webBodyBuilder(),
    );
  }

  return FlagsIntakeRequest(
    endpoint: endpoint.replace(queryParameters: queryParameters),
    headers: {
      'Content-Type': nativeContentType,
      'DD-API-KEY': clientToken,
      'DD-EVP-ORIGIN': datadogFlagsSource,
      'DD-EVP-ORIGIN-VERSION': datadogFlagsSdkVersion,
      'DD-REQUEST-ID': requestId,
    },
    body: nativeBodyBuilder(),
  );
}
