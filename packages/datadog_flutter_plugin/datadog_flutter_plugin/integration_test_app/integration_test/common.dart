// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'dart:async';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_integration_test_app/main.dart' as app;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _IsDecimalVersionOfHex extends CustomMatcher {
  _IsDecimalVersionOfHex(Object? valueOrMatcher)
      : super(
          "Decimal string who's hex representation is",
          'hex string',
          valueOrMatcher is String
              ? valueOrMatcher.toLowerCase()
              : valueOrMatcher,
        );

  @override
  Object? featureValueOf(dynamic actual) =>
      int.parse(actual).toRadixString(16).toLowerCase();
}

Matcher isDecimalVersionOfHex(Object value) => _IsDecimalVersionOfHex(value);

RecordingHttpServer? _mockHttpServer;

Future<RecordingServerClient> startMockServer() async {
  if (kIsWeb) {
    final client = RemoteRecordingServerClient();
    await client.startNewSession();
    return client;
  } else {
    if (_mockHttpServer == null) {
      _mockHttpServer = RecordingHttpServer();
      unawaited(_mockHttpServer!.start());
    }

    final client = LocalRecordingServerClient(_mockHttpServer!);
    await client.startNewSession();

    return client;
  }
}

Future<RecordingServerClient> openTestScenario(
  WidgetTester tester, {
  String? scenarioName,
  String? menuTitle,
  Map<String, Object?> additionalConfig = const {},
}) async {
  var client = await startMockServer();

  // These need to be set as const in order to work, so we
  // can't refactor this out to a function.
  const clientToken = bool.hasEnvironment('DD_CLIENT_TOKEN')
      ? String.fromEnvironment('DD_CLIENT_TOKEN')
      : null;
  const applicationId = bool.hasEnvironment('DD_APPLICATION_ID')
      ? String.fromEnvironment('DD_APPLICATION_ID')
      : null;

  app.testingConfiguration = TestingConfiguration(
    scenario: scenarioName,
    customEndpoint: client.sessionEndpoint,
    clientToken: clientToken,
    applicationId: applicationId,
    firstPartyHosts: ['localhost'],
    additionalConfig: additionalConfig,
  );

  await app.main();
  await tester.pumpAndSettle();

  if (menuTitle != null) {
    var integrationItem = find.byWidgetPredicate((widget) =>
        widget is Text && (widget.data?.startsWith(menuTitle) ?? false));
    await tester.tap(integrationItem);
    await tester.pumpAndSettle();
  }

  return client;
}

void verifyCommonEventTags(
    RumEventDecoder log, String service, String version, String? variant) {
  final tags = log.ddtags;
  // Likely telemetry
  if (tags.isEmpty) return;

  final sdkVersion = tags['sdk_version'];
  expect(sdkVersion, DatadogSdk.sdkVersion);
  expect(tags['service'], service);
  expect(tags['version'], version);
  expect(tags['variant'], variant);
}

void verifyCommonRequestTags(RequestLog log) {
  expect(log.queryParameters['ddsource'], 'flutter');
}

void verifyUser(RumEventDecoder decoder) {
  final user = decoder.user;
  expect(user, isNotNull);
  expect(user?.email, 'fake@datadoghq.com');
  expect(user?.id, 'fake-id');
  expect(user?.name, 'Johnny Silverhand');
  expect(user?.raw['type'], 'customer');
  expect(user?.raw['profession'], 'rocker');
}
