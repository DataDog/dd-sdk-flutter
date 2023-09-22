// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'example_app.dart';

// Rewrite log messages to remove sensitive information
LogEvent? _logEventMapper(LogEvent event) {
  if (event.message == 'overwrite me') {
    event.message = 'overwritten';
  } else if (event.message == 'stop me') {
    // Return null if you don't want a message to be sent
    return null;
  }

  return event;
}

RumViewEvent _viewEventMapper(RumViewEvent event) {
  if (event.view.name == 'overwrite me') {
    event.view.name = 'overwritten';
  }

  return event;
}

RumActionEvent? _actionEventMapper(RumActionEvent event) {
  if (event.view.name == 'overwrite me') {
    event.view.name = 'overwritten';
  }

  if (event.action.target?.name == 'discard') {
    return null;
  } else if (event.action.target?.name == 'censor me!') {
    event.action.target?.name = 'xxxxxxx me';
  }

  return event;
}

RumResourceEvent? _resourceEventMapper(RumResourceEvent event) {
  event.resource.url =
      event.resource.url.replaceAll(RegExp(r'email=[^&]+'), 'email=REDACTED');

  if (event.resource.url.contains('discard')) {
    return null;
  }

  return event;
}

RumErrorEvent? _errorEventMapper(RumErrorEvent event) {
  if (event.error.message == 'discard') {
    return null;
  }

  if (event.error.resource != null) {
    event.error.resource!.url = event.error.resource!.url
        .replaceAll(RegExp(r'email=[^&]+'), 'email=REDACTED');
  }

  return event;
}

RumLongTaskEvent? _longTaskEventMapper(RumLongTaskEvent event) {
  if (event.view.name == 'discard') {
    return null;
  }

  return event;
}

void main() async {
  await dotenv.load();

  var applicationId = dotenv.maybeGet('DD_APPLICATION_ID');

  final configuration = DatadogConfiguration(
    clientToken: dotenv.get('DD_CLIENT_TOKEN', fallback: ''),
    env: dotenv.get('DD_ENV', fallback: ''),
    service: 'com.datadoghq.example.flutter',
    version: '1.2.3',
    site: DatadogSite.us1,
    nativeCrashReportEnabled: true,
    loggingConfiguration: DatadogLoggingConfiguration(),
    rumConfiguration: applicationId != null
        ? DatadogRumConfiguration(
            applicationId: applicationId,
            detectLongTasks: true,
            reportFlutterPerformance: true,
            viewEventMapper: _viewEventMapper,
            actionEventMapper: _actionEventMapper,
            resourceEventMapper: _resourceEventMapper,
            errorEventMapper: _errorEventMapper,
            longTaskEventMapper: _longTaskEventMapper,
          )
        : null,
  );

  final ddsdk = DatadogSdk.instance;
  ddsdk.sdkVerbosity = CoreLoggerLevel.debug;
  DatadogSdk.runApp(configuration, TrackingConsent.granted, () async {
    ddsdk.setUserInfo(id: 'test_id', extraInfo: {
      'user_attribute_1': true,
      'user_attribute_2': 'testing',
    });

    return runApp(const ExampleApp());
  });
}
