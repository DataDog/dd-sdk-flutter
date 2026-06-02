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
const flagsMode = String.fromEnvironment('FLAGS_MODE', defaultValue: 'local');

Future<void> main() async {
  await dotenv.load();

  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();

  DatadogSdk.instance.sdkVerbosity = CoreLoggerLevel.debug;

  final datadogConfig = DatadogConfiguration(
    clientToken: _dotenvValue(
      'DD_CLIENT_TOKEN',
      localFallback: 'local-client-token',
    ),
    env: _dotenvValue('DD_ENV', localFallback: 'local'),
    site: DatadogSite.us1,
    loggingConfiguration: DatadogLoggingConfiguration(),
    firstPartyHosts: ['localhost'],
    rumConfiguration: DatadogRumConfiguration(
        applicationId: _dotenvValue(
          'DD_APPLICATION_ID',
          localFallback: 'local-application-id',
        ),
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
  );
}

String _dotenvValue(String name, {required String localFallback}) {
  final value = dotenv.maybeGet(name);
  if (value != null && value.isNotEmpty) {
    return value;
  }
  return flagsMode == 'local' ? localFallback : '';
}

Future<void> runUsingAlternativeInit(DatadogConfiguration datadogConfig) async {
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
  final flagsRuntime = await FlagsDemoRuntime.create();
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
    FlagsDemoRuntime.create().then((flagsRuntime) async {
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
