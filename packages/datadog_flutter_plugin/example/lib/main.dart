// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:async';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'example_app.dart';

// Rewrite log messages to remove sensitive information
LogEvent? _testLogEventMapper(LogEvent event) {
  if (event.message == 'overwrite me') {
    event.message = 'overwritten';
  } else if (event.message == 'stop me') {
    // Return null if you don't want a message to be sent
    return null;
  }

  return event;
}

RumViewEvent _testViewEventMapper(RumViewEvent event) {
  if (event.view.name == 'overwrite me') {
    event.view.name = 'overwritten';
  }

  return event;
}

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load();

    var applicationId = dotenv.maybeGet('DD_APPLICATION_ID');

    final configuration = DdSdkConfiguration(
      clientToken: dotenv.get('DD_CLIENT_TOKEN', fallback: ''),
      env: dotenv.get('DD_ENV', fallback: ''),
      site: DatadogSite.us1,
      trackingConsent: TrackingConsent.granted,
      nativeCrashReportEnabled: true,
      logEventMapper: _testLogEventMapper,
      loggingConfiguration: LoggingConfiguration(
        sendNetworkInfo: true,
        printLogsToConsole: true,
      ),
      rumConfiguration: applicationId != null
          ? RumConfiguration(
              applicationId: applicationId,
              detectLongTasks: true,
              rumViewEventMapper: _testViewEventMapper,
            )
          : null,
    );

    final ddsdk = DatadogSdk.instance;
    ddsdk.sdkVerbosity = Verbosity.verbose;

    DatadogSdk.instance.initialize(configuration);

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      ddsdk.rum?.handleFlutterError(details);
    };

    runApp(const ExampleApp());
  }, (e, s) {
    DatadogSdk.instance.rum
        ?.addErrorInfo(e.toString(), RumErrorSource.source, stackTrace: s);
    throw e;
  });
}
