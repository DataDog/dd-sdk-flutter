// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'common.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  kManualIsWeb = kIsWeb;

  testWidgets('logger reflects user and account changes', (tester) async {
    var recordedSession = await openTestScenario(
      tester,
      additionalConfig: {
        DatadogConfigKey.telemetryConfigurationSampleRate: 0.0,
      },
      menuTitle: 'Logging User & Account Scenario',
    );
    var logs = <LogDecoder>[];

    await recordedSession.pollForLogs(
      const Duration(seconds: 60),
      (logRequests) {
        logs = logRequests;
        return logs.length >= 5;
      },
    );

    expect(logs[0].userAnonymousId, isNotNull);
    expect(logs[0].userId, isNull);
    expect(logs[0].userEmail, isNull);
    expect(logs[0].userName, isNull);
    expect(logs[0].accountId, isNull);
    expect(logs[0].accountName, isNull);

    expect(logs[1].userAnonymousId, isNotNull);
    expect(logs[1].userId, 'bits');
    expect(logs[1].userEmail, 'bits@datadoghq.com');
    expect(logs[1].userName, 'Bits Dawoof');
    expect(logs[1].getUserProperty('type'), 'dog');
    expect(logs[1].getUserProperty('department'), 'data');
    expect(logs[1].accountId, isNull);
    expect(logs[1].accountName, isNull);

    expect(logs[2].userAnonymousId, isNotNull);
    expect(logs[2].userId, 'bits');
    expect(logs[2].userEmail, 'bits@datadoghq.com');
    expect(logs[2].userName, 'Bits Dawoof');
    expect(logs[2].getUserProperty('type'), 'dog');
    expect(logs[2].getUserProperty('department'), 'data');
    expect(logs[2].accountId, 'bits-account');
    expect(logs[2].accountName, 'Dawoof, Bits');
    expect(logs[2].getAccountProperty('type'), 'top_dog');
    expect(logs[2].getAccountProperty('department'), 'fetching');

    expect(logs[3].userAnonymousId, isNotNull);
    expect(logs[3].userId, isNull);
    expect(logs[3].userEmail, isNull);
    expect(logs[3].userName, isNull);
    expect(logs[3].getUserProperty('type'), isNull);
    expect(logs[3].getUserProperty('department'), isNull);
    expect(logs[3].accountId, 'bits-account');
    expect(logs[3].accountName, 'Dawoof, Bits');
    expect(logs[3].getAccountProperty('type'), 'top_dog');
    expect(logs[3].getAccountProperty('department'), 'fetching');

    expect(logs[4].userAnonymousId, isNotNull);
    expect(logs[4].userId, isNull);
    expect(logs[4].userEmail, isNull);
    expect(logs[4].userName, isNull);
    expect(logs[4].getUserProperty('type'), isNull);
    expect(logs[4].getUserProperty('department'), isNull);
    expect(logs[4].accountId, isNull);
    expect(logs[4].accountName, isNull);
    expect(logs[4].getAccountProperty('type'), isNull);
    expect(logs[4].getAccountProperty('department'), isNull);
  });
}
