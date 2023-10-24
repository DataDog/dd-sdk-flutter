// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:async';
import 'dart:io';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

typedef AsyncVoidCallback = FutureOr<void> Function();
typedef DatadogConfigCallback = void Function(DatadogConfiguration config);

DatadogLogger? logger;

Future<void> initializeDatadog({
  DatadogConfigCallback? configCallback,
  TrackingConsent trackingConsent = TrackingConsent.granted,
}) async {
  await dotenv.load();

  DatadogSdk.instance.sdkVerbosity = CoreLoggerLevel.debug;

  var applicationId = dotenv.get('DD_APPLICATION_ID');
  var clientToken = dotenv.get('DD_CLIENT_TOKEN');
  var env = dotenv.get('DD_E2E_IS_ON_CI').toLowerCase() == 'true'
      ? 'instrumentation'
      : 'debug';

  final configuration = DatadogConfiguration(
    clientToken: clientToken,
    env: env,
    site: DatadogSite.us1,
  )
    ..loggingConfiguration = DatadogLoggingConfiguration()
    ..rumConfiguration = DatadogRumConfiguration(
      applicationId: applicationId,
      detectLongTasks: false,
    )
    ..service = 'com.datadog.flutter.nightly';

  if (configCallback != null) {
    configCallback(configuration);
  }

  await DatadogSdk.instance.initialize(configuration, trackingConsent);
  logger = DatadogSdk.instance.logs?.createLogger(DatadogLoggerConfiguration());
}

Future<void> measure(String resourceName, AsyncVoidCallback callback,
    [double targetSeconds = 0.02]) async {
  var stopwatch = Stopwatch();
  stopwatch.start();
  await callback();
  stopwatch.stop();
  // ignore: unused_local_variable
  final elapsedSeconds = stopwatch.elapsedMicroseconds / 1000000.0;
  // TODO: Determine best way to monitor this moving forward
  if (elapsedSeconds > targetSeconds) {
    logger?.error(
        'PERF ERROR: `$resourceName` took ${elapsedSeconds.toStringAsFixed(3)} (targeting ${targetSeconds.toStringAsFixed(3)})');
  }
}

Map<String, Object> e2eAttributes(WidgetTester tester) {
  return {
    'test_method_name': tester.testDescription,
    'operating_system': Platform.operatingSystem,
  };
}

void sendRandomLog(DatadogLogger? logger, WidgetTester tester) {
  var methods = [
    logger?.debug,
    logger?.info,
    logger?.warn,
    logger?.error,
  ];

  var method = methods.randomElement();

  method!(
    randomString(),
    attributes: e2eAttributes(tester),
  );
}
