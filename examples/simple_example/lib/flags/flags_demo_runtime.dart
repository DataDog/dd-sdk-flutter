// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';

import 'flags_request_counter.dart';
import 'forwarding_flags_counter.dart';

const _externalFlagsEndpoint = String.fromEnvironment('FLAGS_ENDPOINT');
const _externalExposureEndpoint =
    String.fromEnvironment('FLAGS_EXPOSURE_ENDPOINT');
const _externalEvaluationEndpoint =
    String.fromEnvironment('FLAGS_EVALUATION_ENDPOINT');
const _countRequests =
    bool.fromEnvironment('FLAGS_COUNT_REQUESTS', defaultValue: true);

class FlagsDemoRuntime {
  final FlagsRequestCounter? counter;
  final DatadogFlagsConfiguration configuration;

  const FlagsDemoRuntime._({
    required this.counter,
    required this.configuration,
  });

  Future<void> stop() async {
    await counter?.stop();
  }

  static Future<FlagsDemoRuntime> create({
    String? clientToken,
    String? env,
    String? siteName,
    String? applicationId,
  }) async {
    final externalFlagsEndpoint = _uriFromEnvironment(_externalFlagsEndpoint);
    final externalExposureEndpoint =
        _uriFromEnvironment(_externalExposureEndpoint);
    final externalEvaluationEndpoint =
        _uriFromEnvironment(_externalEvaluationEndpoint);

    final useDatad0g = siteName == 'datad0g.com';
    final counter = _countRequests ? ForwardingFlagsCounter.create() : null;

    return FlagsDemoRuntime._(
      counter: counter,
      configuration: DatadogFlagsConfiguration(
        customFlagsEndpoint: externalFlagsEndpoint ??
            (useDatad0g
                ? Uri.https(
                    'preview.ff-cdn.datad0g.com',
                    '/precompute-assignments',
                  )
                : null),
        customExposureEndpoint: externalExposureEndpoint ??
            (useDatad0g
                ? Uri.parse(
                    'https://browser-intake-datad0g.com/api/v2/exposures?ddsource=flutter',
                  )
                : null),
        customEvaluationEndpoint: externalEvaluationEndpoint ??
            (useDatad0g
                ? Uri.parse(
                    'https://browser-intake-datad0g.com/api/v2/flagevaluation?ddsource=flutter',
                  )
                : null),
        httpClient:
            counter is ForwardingFlagsCounter ? counter.httpClient : null,
        datadogContext: _datadogContext(
          useDatad0g: useDatad0g,
          clientToken: clientToken,
          env: env,
          applicationId: applicationId,
        ),
        evaluationFlushInterval: const Duration(seconds: 1),
      ),
    );
  }
}

DatadogFlagsContext? _datadogContext({
  required bool useDatad0g,
  required String? clientToken,
  required String? env,
  required String? applicationId,
}) {
  if (!useDatad0g) {
    return null;
  }

  return DatadogFlagsContext(
    clientToken: clientToken ?? '',
    env: env ?? 'staging',
    site: DatadogFlagsSite.us1,
    service: 'simple-example',
    version: '1.0.0',
    applicationId: _emptyToNull(applicationId),
    sdkVersion: DatadogSdk.sdkVersion,
  );
}

Uri? _uriFromEnvironment(String value) {
  if (value.isEmpty) {
    return null;
  }
  return Uri.parse(value);
}

String? _emptyToNull(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}
