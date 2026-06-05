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
const _perplexityClientToken = 'pub2f0197bbd2a6d0ce1781a08c2c5307eb';

class FlagsDemoRuntime {
  final FlagsRequestCounter? counter;
  final DatadogFlagsConfiguration configuration;
  final String? applicationId;
  final Duration? providerInitializationDuration;
  final String configuredEnv;
  final String obfuscatedClientToken;

  const FlagsDemoRuntime._({
    required this.counter,
    required this.configuration,
    required this.applicationId,
    required this.providerInitializationDuration,
    required this.configuredEnv,
    required this.obfuscatedClientToken,
  });

  Future<void> stop() async {
    await counter?.stop();
  }

  FlagsDemoRuntime withProviderInitializationDuration(Duration duration) {
    return FlagsDemoRuntime._(
      counter: counter,
      configuration: configuration,
      applicationId: applicationId,
      providerInitializationDuration: duration,
      configuredEnv: configuredEnv,
      obfuscatedClientToken: obfuscatedClientToken,
    );
  }

  Future<FlagsDemoProviderDiagnostics> enableProvider(
    FlagsDemoProviderMode mode,
  ) async {
    final provider = providerConfiguration(mode);
    final stopwatch = Stopwatch()..start();
    await DatadogFlags.enable(configuration: provider.configuration);
    stopwatch.stop();
    return FlagsDemoProviderDiagnostics(
      configuredEnv: provider.configuredEnv,
      obfuscatedClientToken: provider.obfuscatedClientToken,
      providerInitializationDuration: stopwatch.elapsed,
    );
  }

  FlagsDemoProviderConfiguration providerConfiguration(
    FlagsDemoProviderMode mode,
  ) {
    final requestCounter = counter;
    return switch (mode) {
      FlagsDemoProviderMode.ffeDogfooding => FlagsDemoProviderConfiguration(
          configuration: configuration,
          configuredEnv: configuredEnv,
          obfuscatedClientToken: obfuscatedClientToken,
        ),
      FlagsDemoProviderMode.perplexityLoadTest =>
        FlagsDemoProviderConfiguration(
          configuration: DatadogFlagsConfiguration(
            httpClient: requestCounter is ForwardingFlagsCounter
                ? requestCounter.httpClient
                : null,
            assignmentsFetchObserver: requestCounter is ForwardingFlagsCounter
                ? requestCounter.recordAssignmentsFetch
                : null,
            datadogContext: DatadogFlagsContext(
              clientToken: _perplexityClientToken,
              env: 'prod',
              site: DatadogSite.us1,
              service: 'simple-example',
              version: '1.0.0',
              applicationId: _emptyToNull(applicationId),
              sdkVersion: DatadogSdk.sdkVersion,
            ),
            evaluationFlushInterval: const Duration(seconds: 1),
          ),
          configuredEnv: 'prod',
          obfuscatedClientToken: _obfuscateToken(_perplexityClientToken),
        ),
    };
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
    final datadogContext = _datadogContext(
      useDatad0g: useDatad0g,
      clientToken: clientToken,
      env: env,
      applicationId: applicationId,
    );

    return FlagsDemoRuntime._(
      counter: counter,
      providerInitializationDuration: null,
      applicationId: applicationId,
      configuredEnv: _configuredEnv(datadogContext, env),
      obfuscatedClientToken: _obfuscateToken(
        datadogContext?.clientToken ?? clientToken,
      ),
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
        assignmentsFetchObserver: counter is ForwardingFlagsCounter
            ? counter.recordAssignmentsFetch
            : null,
        datadogContext: datadogContext,
        evaluationFlushInterval: const Duration(seconds: 1),
      ),
    );
  }
}

enum FlagsDemoProviderMode { ffeDogfooding, perplexityLoadTest }

class FlagsDemoProviderConfiguration {
  final DatadogFlagsConfiguration configuration;
  final String configuredEnv;
  final String obfuscatedClientToken;

  const FlagsDemoProviderConfiguration({
    required this.configuration,
    required this.configuredEnv,
    required this.obfuscatedClientToken,
  });
}

class FlagsDemoProviderDiagnostics {
  final String configuredEnv;
  final String obfuscatedClientToken;
  final Duration? providerInitializationDuration;

  const FlagsDemoProviderDiagnostics({
    required this.configuredEnv,
    required this.obfuscatedClientToken,
    required this.providerInitializationDuration,
  });
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

String _configuredEnv(DatadogFlagsContext? context, String? fallback) {
  if (context != null) {
    return context.env;
  }
  if (fallback != null && fallback.isNotEmpty) {
    return fallback;
  }
  return '-';
}

String _obfuscateToken(String? token) {
  if (token == null || token.isEmpty) {
    return '-';
  }
  if (token.length <= 10) {
    return '${token.substring(0, 1)}...${token.substring(token.length - 1)}';
  }
  return '${token.substring(0, 6)}...${token.substring(token.length - 4)}';
}
