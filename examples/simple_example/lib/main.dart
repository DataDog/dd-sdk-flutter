// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_gql_link/datadog_gql_link.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_tracking_http_client/datadog_tracking_http_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'app.dart';
import 'flags/flags_example_config.dart';
import 'url_strategy_stub.dart' if (dart.library.html) 'url_strategy_web.dart';

const graphQlUrl = 'http://localhost:3000/graphql';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  configureUrlStrategy();

  DatadogSdk.instance.sdkVerbosity = CoreLoggerLevel.debug;
  final siteConfig = FlagsExampleSiteConfig.fromName(
    dotenv.maybeGet('DD_SITE'),
  );
  final clientToken = dotenv.get('DD_CLIENT_TOKEN', fallback: '');
  final env = dotenv.get('DD_ENV', fallback: '');
  final applicationId = dotenv.get('DD_APPLICATION_ID', fallback: '');
  final flagsConfig = FlagsExampleConfig.fromDotEnv(
    clientToken: clientToken,
    env: env,
    site: siteConfig.flagsSite,
    applicationId: applicationId,
  );

  final datadogConfig =
      DatadogConfiguration(
          clientToken: clientToken,
          env: env,
          site: siteConfig.datadogSite,
          service: 'com.datadoghq.example.flutter',
          loggingConfiguration: DatadogLoggingConfiguration(
            customEndpoint: siteConfig.logsCustomEndpoint,
          ),
          firstPartyHosts: ['localhost'],
          rumConfiguration: DatadogRumConfiguration(
            applicationId: applicationId,
            customEndpoint: siteConfig.rumCustomEndpoint,
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
            ),
          ),
        )
        ..enableHttpTracking(
          // Using ignoreUrlPatterns is needed if you want to combine HttpClient
          // tracking and GraphQL tracking through datadog_gql_link
          ignoreUrlPatterns: [RegExp('localhost')],
        )
        ..addPlugin(
          DatadogFlagsPluginConfiguration(
            flagsConfiguration: flagsConfig.configuration,
          ),
        );

  if (siteConfig.sessionReplayEnabled) {
    datadogConfig.enableSessionReplay(
      DatadogSessionReplayConfiguration(replaySampleRate: 100),
    );
  }

  // runUsingRunApp(datadogConfig, flagsConfig);
  runUsingAlternativeInit(datadogConfig, flagsConfig);
}

Future<void> runUsingAlternativeInit(
  DatadogConfiguration datadogConfig,
  FlagsExampleConfig flagsConfig,
) async {
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
  final link = Link.from([
    DatadogGqlLink(DatadogSdk.instance, Uri.parse(graphQlUrl)),
    HttpLink(graphQlUrl),
  ]);

  final graphQlClient = GraphQLClient(link: link, cache: GraphQLCache());
  runApp(MyApp(graphQLClient: graphQlClient, flagsConfig: flagsConfig));
}

Future<void> runUsingRunApp(
  DatadogConfiguration datadogConfig,
  FlagsExampleConfig flagsConfig,
) async {
  await DatadogSdk.runApp(datadogConfig, TrackingConsent.granted, () {
    final link = Link.from([
      DatadogGqlLink(DatadogSdk.instance, Uri.parse(graphQlUrl)),
      HttpLink(graphQlUrl),
    ]);
    final graphQlClient = GraphQLClient(link: link, cache: GraphQLCache());

    runApp(MyApp(graphQLClient: graphQlClient, flagsConfig: flagsConfig));
  });
}
