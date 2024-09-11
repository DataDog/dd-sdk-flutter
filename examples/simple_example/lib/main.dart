// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_gql_link/datadog_gql_link.dart';
import 'package:datadog_tracking_http_client/datadog_tracking_http_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'app.dart';
import 'url_strategy_stub.dart' if (dart.library.html) 'url_strategy_web.dart';

const graphQlUrl = 'http://localhost:3000/graphql';

void main() async {
  await dotenv.load();

  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();

  DatadogSdk.instance.sdkVerbosity = CoreLoggerLevel.debug;

  final datadogConfig = DatadogConfiguration(
    clientToken: dotenv.get('DD_CLIENT_TOKEN', fallback: ''),
    env: dotenv.get('DD_ENV', fallback: ''),
    site: DatadogSite.us1,
    loggingConfiguration: DatadogLoggingConfiguration(),
    firstPartyHosts: ['localhost'],
    rumConfiguration: DatadogRumConfiguration(
      applicationId: dotenv.get('DD_APPLICATION_ID', fallback: ''),
      traceSampleRate: 100.0,
    ),
  )..enableHttpTracking(
      // Using ignoreUrlPatterns is needed if you want to combine HttpClient
      // tracking and GraphQL tracking through datadog_gql_link
      ignoreUrlPatterns: [
        RegExp('localhost'),
      ],
    );

  // runUsingRunApp(datadogConfig);
  runUsingAlternativeInit(
    datadogConfig,
  );
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
  final link = Link.from([
    DatadogGqlLink(DatadogSdk.instance, Uri.parse(graphQlUrl)),
    HttpLink(graphQlUrl),
  ]);

  final graphQlClient = GraphQLClient(link: link, cache: GraphQLCache());
  runApp(MyApp(
    graphQLClient: graphQlClient,
  ));
}

Future<void> runUsingRunApp(DatadogConfiguration datadogConfig) async {
  await DatadogSdk.runApp(datadogConfig, TrackingConsent.granted, () {
    final link = Link.from([
      DatadogGqlLink(DatadogSdk.instance, Uri.parse(graphQlUrl)),
      HttpLink(graphQlUrl),
    ]);
    final graphQlClient = GraphQLClient(link: link, cache: GraphQLCache());

    runApp(MyApp(
      graphQLClient: graphQlClient,
    ));
  });
}
