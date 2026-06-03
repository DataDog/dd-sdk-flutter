// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';

import 'flags_request_counter.dart';
import 'forwarding_flags_counter.dart';
import 'local_flags_collector.dart';

const _externalFlagsEndpoint = String.fromEnvironment('FLAGS_ENDPOINT');
const _externalExposureEndpoint =
    String.fromEnvironment('FLAGS_EXPOSURE_ENDPOINT');
const _externalEvaluationEndpoint =
    String.fromEnvironment('FLAGS_EVALUATION_ENDPOINT');

class FlagsDemoRuntime {
  final String mode;
  final LocalFlagsCollector? collector;
  final FlagsRequestCounter? counter;
  final DatadogFlagsConfiguration configuration;

  const FlagsDemoRuntime._({
    required this.mode,
    required this.collector,
    required this.counter,
    required this.configuration,
  });

  bool get usesFixtureFlags => mode == 'local' || mode == 'fixture';

  Future<void> stop() async {
    await counter?.stop();
  }

  static Future<FlagsDemoRuntime> create({
    String? clientToken,
    String? env,
    String? siteName,
    String? applicationId,
  }) async {
    const mode = String.fromEnvironment('FLAGS_MODE', defaultValue: 'local');
    final externalFlagsEndpoint = _uriFromEnvironment(_externalFlagsEndpoint);
    final externalExposureEndpoint =
        _uriFromEnvironment(_externalExposureEndpoint);
    final externalEvaluationEndpoint =
        _uriFromEnvironment(_externalEvaluationEndpoint);

    final useFixture = mode == 'local' || mode == 'fixture';
    final useForwardingCounter = !useFixture;
    final useDatad0g = siteName == 'datad0g.com';

    LocalFlagsCollector? collector;
    if (useFixture && externalFlagsEndpoint == null) {
      collector = await LocalFlagsCollector.start();
    }
    final forwardingCounter =
        useForwardingCounter ? ForwardingFlagsCounter.create() : null;
    final counter = collector ?? forwardingCounter;

    return FlagsDemoRuntime._(
      mode: mode,
      collector: collector,
      counter: counter,
      configuration: DatadogFlagsConfiguration(
        customFlagsEndpoint: externalFlagsEndpoint ??
            collector?.precomputeEndpoint ??
            (useDatad0g
                ? Uri.https(
                    'preview.ff-cdn.datad0g.com',
                    '/precompute-assignments',
                    {'dd_env': env ?? 'dev'},
                  )
                : null),
        customExposureEndpoint: externalExposureEndpoint ??
            collector?.exposureEndpoint ??
            (useDatad0g
                ? Uri.parse(
                    'https://browser-intake-datad0g.com/api/v2/exposures?ddsource=flutter',
                  )
                : null),
        customEvaluationEndpoint: externalEvaluationEndpoint ??
            collector?.evaluationEndpoint ??
            (useDatad0g
                ? Uri.parse(
                    'https://browser-intake-datad0g.com/api/v2/flagevaluation?ddsource=flutter',
                  )
                : null),
        httpClient: collector?.httpClient ?? forwardingCounter?.httpClient,
        store: useFixture ? InMemoryDatadogFlagsStore() : null,
        datadogContext: _datadogContext(
          useFixture: useFixture,
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
  required bool useFixture,
  required bool useDatad0g,
  required String? clientToken,
  required String? env,
  required String? applicationId,
}) {
  if (useFixture) {
    return const DatadogFlagsContext(
      clientToken: 'local-client-token',
      env: 'local',
      site: DatadogSite.us1,
      service: 'simple-example',
      version: '1.0.0',
      applicationId: 'local-application-id',
      sdkVersion: '3.3.0',
    );
  }

  if (!useDatad0g) {
    return null;
  }

  return DatadogFlagsContext(
    clientToken: clientToken ?? '',
    env: env ?? 'staging',
    site: DatadogSite.us1,
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
