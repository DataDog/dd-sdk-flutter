// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_gql_link/datadog_gql_link.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_tracking_http_client/datadog_tracking_http_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'app.dart';
import 'flags/flags_demo_runtime.dart';
import 'url_strategy_stub.dart' if (dart.library.html) 'url_strategy_web.dart';

const graphQlUrl = 'http://localhost:3000/graphql';
const ddClientToken = String.fromEnvironment('DD_CLIENT_TOKEN');
const ddApplicationId = String.fromEnvironment('DD_APPLICATION_ID');
const ddEnv = String.fromEnvironment('DD_ENV');
const ddSite = String.fromEnvironment('DD_SITE', defaultValue: 'us1');

Future<void> main() async {
  await dotenv.load();

  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();

  DatadogSdk.instance.sdkVerbosity = CoreLoggerLevel.debug;

  final siteName = _configValue(
    'DD_SITE',
    defineValue: ddSite,
    defaultValue: 'us1',
  );
  final intakeEndpoint = _intakeEndpointForSite(siteName);
  final applicationId = _configValue(
    'DD_APPLICATION_ID',
    defineValue: ddApplicationId,
    defaultValue: '',
  );
  final env = _configValue(
    'DD_ENV',
    defineValue: ddEnv,
    defaultValue: siteName == 'datad0g.com' ? 'staging' : 'dev',
  );
  final datadogConfig = DatadogConfiguration(
    clientToken: _configValue(
      'DD_CLIENT_TOKEN',
      defineValue: ddClientToken,
      defaultValue: '',
    ),
    env: env,
    site: _siteForName(siteName),
    loggingConfiguration:
        DatadogLoggingConfiguration(customEndpoint: intakeEndpoint),
    firstPartyHosts: ['localhost'],
    rumConfiguration: DatadogRumConfiguration(
        applicationId: applicationId,
        customEndpoint: intakeEndpoint,
        traceSampleRate: 100.0,
        trackResourceHeaders: ResourceHeadersExtractor(
          captureHeaders: [
            'accept-ranges',
            'content-disposition',
            'server',
            'user-agent',
            'via',
            'x-cache-hits',
            'x-served-by',
            'x-datadog-trace-id',
            'x-datadog-parent-id',
            'x-datadog-origin',
            'traceparent',
          ],
        )),
  )
    ..enableHttpTracking(
      // Using ignoreUrlPatterns is needed if you want to combine HttpClient
      // tracking and GraphQL tracking through datadog_gql_link
      ignoreUrlPatterns: [
        RegExp('localhost'),
      ],
    )
    ..enableSessionReplay(
        DatadogSessionReplayConfiguration(replaySampleRate: 100));

  // runUsingRunApp(datadogConfig);
  runUsingAlternativeInit(
    datadogConfig,
    siteName: siteName,
  );
}

String _configValue(
  String name, {
  required String defineValue,
  required String defaultValue,
}) {
  if (defineValue.isNotEmpty) {
    return defineValue;
  }
  final value = dotenv.maybeGet(name);
  if (value != null && value.isNotEmpty) {
    return value;
  }
  return defaultValue;
}

DatadogSite _siteForName(String siteName) {
  return switch (siteName) {
    'us3' || 'us3.datadoghq.com' => DatadogSite.us3,
    'us5' || 'us5.datadoghq.com' => DatadogSite.us5,
    'eu1' || 'datadoghq.eu' => DatadogSite.eu1,
    'ap1' || 'ap1.datadoghq.com' => DatadogSite.ap1,
    'ap2' || 'ap2.datadoghq.com' => DatadogSite.ap2,
    'us1_fed' || 'ddog-gov.com' => DatadogSite.us1Fed,
    // The Flutter plugin does not expose a staging enum. Use custom endpoints
    // for staging intake and flags while keeping the closest SDK site value.
    'datad0g.com' => DatadogSite.us1,
    _ => DatadogSite.us1,
  };
}

String? _intakeEndpointForSite(String siteName) {
  return switch (siteName) {
    'datad0g.com' => 'https://browser-intake-datad0g.com',
    _ => null,
  };
}

Future<void> runUsingAlternativeInit(
  DatadogConfiguration datadogConfig, {
  required String siteName,
}) async {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    DatadogSdk.instance.rum?.handleFlutterError(details);
    originalOnError?.call(details);
  };

  final platformOriginalOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (e, st) {
    DatadogSdk.instance.rum?.addErrorInfo(
      e.toString(),
      RumErrorSource.source,
      stackTrace: st,
    );
    return platformOriginalOnError?.call(e, st) ?? false;
  };

  await DatadogSdk.instance.initialize(datadogConfig, TrackingConsent.granted);
  final flagsRuntime = await FlagsDemoRuntime.create(
    clientToken: datadogConfig.clientToken,
    env: datadogConfig.env,
    siteName: siteName,
    applicationId: datadogConfig.rumConfiguration?.applicationId,
  );
  await DatadogFlags.enable(configuration: flagsRuntime.configuration);
  final link = Link.from([
    DatadogGqlLink(DatadogSdk.instance, Uri.parse(graphQlUrl)),
    HttpLink(graphQlUrl),
  ]);

  final graphQlClient = GraphQLClient(link: link, cache: GraphQLCache());
  runApp(MyApp(
    graphQLClient: graphQlClient,
    flagsRuntime: flagsRuntime,
  ));
}

Future<void> runUsingRunApp(DatadogConfiguration datadogConfig) async {
  await DatadogSdk.runApp(datadogConfig, TrackingConsent.granted, () {
    // This path is not used by default, but keep flags configured for parity
    // if the example is switched back to DatadogSdk.runApp.
    final siteName = _configValue(
      'DD_SITE',
      defineValue: ddSite,
      defaultValue: 'us1',
    );
    FlagsDemoRuntime.create(
      clientToken: datadogConfig.clientToken,
      env: datadogConfig.env,
      siteName: siteName,
      applicationId: datadogConfig.rumConfiguration?.applicationId,
    ).then((flagsRuntime) async {
      await DatadogFlags.enable(configuration: flagsRuntime.configuration);
      final link = Link.from([
        DatadogGqlLink(DatadogSdk.instance, Uri.parse(graphQlUrl)),
        HttpLink(graphQlUrl),
      ]);
      final graphQlClient = GraphQLClient(link: link, cache: GraphQLCache());

      runApp(MyApp(
        graphQLClient: graphQlClient,
        flagsRuntime: flagsRuntime,
      ));
    });
  });
}
