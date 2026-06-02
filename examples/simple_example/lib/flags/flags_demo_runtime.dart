// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';

import 'local_flags_collector.dart';

const _externalFlagsEndpoint = String.fromEnvironment('FLAGS_ENDPOINT');
const _externalExposureEndpoint =
    String.fromEnvironment('FLAGS_EXPOSURE_ENDPOINT');
const _externalEvaluationEndpoint =
    String.fromEnvironment('FLAGS_EVALUATION_ENDPOINT');

class FlagsDemoRuntime {
  final String mode;
  final LocalFlagsCollector? collector;
  final DatadogFlagsConfiguration configuration;

  const FlagsDemoRuntime._({
    required this.mode,
    required this.collector,
    required this.configuration,
  });

  Future<void> stop() async {
    await collector?.stop();
  }

  static Future<FlagsDemoRuntime> create() async {
    const mode = String.fromEnvironment('FLAGS_MODE', defaultValue: 'local');
    final externalFlagsEndpoint = _uriFromEnvironment(_externalFlagsEndpoint);
    final externalExposureEndpoint =
        _uriFromEnvironment(_externalExposureEndpoint);
    final externalEvaluationEndpoint =
        _uriFromEnvironment(_externalEvaluationEndpoint);

    LocalFlagsCollector? collector;
    if (mode == 'local' && externalFlagsEndpoint == null) {
      collector = await LocalFlagsCollector.start();
    }

    return FlagsDemoRuntime._(
      mode: mode,
      collector: collector,
      configuration: DatadogFlagsConfiguration(
        customFlagsEndpoint:
            externalFlagsEndpoint ?? collector?.precomputeEndpoint,
        customExposureEndpoint:
            externalExposureEndpoint ?? collector?.exposureEndpoint,
        customEvaluationEndpoint:
            externalEvaluationEndpoint ?? collector?.evaluationEndpoint,
        httpClient: collector?.httpClient,
        store: mode == 'local' ? InMemoryDatadogFlagsStore() : null,
        datadogContext: mode == 'local'
            ? const DatadogFlagsContext(
                clientToken: 'local-client-token',
                env: 'local',
                site: DatadogSite.us1,
                service: 'simple-example',
                version: '1.0.0',
                applicationId: 'local-application-id',
                sdkVersion: '3.3.0',
              )
            : null,
        evaluationFlushInterval: const Duration(seconds: 1),
      ),
    );
  }
}

Uri? _uriFromEnvironment(String value) {
  if (value.isEmpty) {
    return null;
  }
  return Uri.parse(value);
}
