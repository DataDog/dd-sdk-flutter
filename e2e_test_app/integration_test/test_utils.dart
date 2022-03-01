// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:io';
import 'dart:math';

import 'package:datadog_sdk/datadog_sdk.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

typedef AsyncVoidCallback = Future<void> Function();
typedef DatadogConfigCallback = void Function(DdSdkConfiguration config);

Future<void> initializeDatadog([DatadogConfigCallback? configCallback]) async {
  await dotenv.load();

  DatadogSdk.instance.sdkVerbosity = Verbosity.verbose;

  var applicationId = dotenv.get('DD_APPLICATION_ID');
  var clientToken = dotenv.get('DD_CLIENT_TOKEN');
  var env = dotenv.get('DD_E2E_IS_ON_CI').toLowerCase() == 'true'
      ? 'instrumentation'
      : 'debug';

  final configuration = DdSdkConfiguration(
      clientToken: clientToken,
      env: env,
      trackingConsent: TrackingConsent.granted)
    ..loggingConfiguration = LoggingConfiguration()
    ..tracingConfiguration = TracingConfiguration()
    ..rumConfiguration = RumConfiguration(applicationId: applicationId)
    ..additionalConfig[DatadogConfigKey.serviceName] =
        'com.datadog.flutter.nightly';

  if (configCallback != null) {
    configCallback(configuration);
  }

  await DatadogSdk.instance.initialize(configuration);
}

Future<void> measure(String resourceName, AsyncVoidCallback callback) async {
  // TODO: Have spans record time from Dart instead of waiting for the PlatformChannel.
  var span = await DatadogSdk.instance.traces?.startRootSpan(
    'perf_measure',
    resourceName: resourceName,
    tags: {'operating_system': Platform.operatingSystem},
  );
  await callback();
  await span?.finish();
}

final _random = Random();
const _alphas = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
const _numerics = '0123456789';
const _alphaNumerics = _alphas + _numerics;

String randomString({int length = 10}) {
  final result = String.fromCharCodes(Iterable.generate(
    length,
    (_) => _alphaNumerics.codeUnitAt(_random.nextInt(_alphaNumerics.length)),
  ));

  return result;
}

extension RandomExtension<T> on List<T> {
  T randomElement() {
    return this[_random.nextInt(length)];
  }
}

Map<String, Object> e2eAttributes(WidgetTester tester) {
  return {
    'test_method_name': tester.testDescription,
    'operating_system': Platform.operatingSystem,
  };
}

Future<void> sendRandomLog(WidgetTester tester) async {
  var methods = [
    DatadogSdk.instance.logs?.debug,
    DatadogSdk.instance.logs?.info,
    DatadogSdk.instance.logs?.warn,
    DatadogSdk.instance.logs?.error,
  ];

  var method = methods.randomElement();

  await method!(
    randomString(),
    e2eAttributes(tester),
  );
}

Future<DdSpan> startSpan(String operationName) {
  return DatadogSdk.instance.traces!.startSpan(operationName, tags: {
    'operating_system': Platform.operatingSystem,
  });
}
