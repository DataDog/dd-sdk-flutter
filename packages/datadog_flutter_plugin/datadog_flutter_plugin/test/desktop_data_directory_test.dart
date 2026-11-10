// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDesktopPlatform extends DatadogSdkNoOpPlatform {
  String? lastApplicationName;

  @override
  String? getSuggestedDesktopDataDirectory(String applicationName) {
    lastApplicationName = applicationName;
    return '/data/$applicationName';
  }
}

void main() {
  tearDown(() {
    DatadogSdkPlatform.instance = DatadogSdkNoOpPlatform();
  });

  test('getSuggestedDesktopDataDirectory returns null by default', () {
    expect(
      DatadogConfiguration.getSuggestedDesktopDataDirectory('app'),
      isNull,
    );
  });

  test('getSuggestedDesktopDataDirectory delegates to the platform', () {
    final platform = _FakeDesktopPlatform();
    DatadogSdkPlatform.instance = platform;

    expect(
      DatadogConfiguration.getSuggestedDesktopDataDirectory('my.app'),
      '/data/my.app',
    );
    expect(platform.lastApplicationName, 'my.app');
  });

  test('desktopDataDirectory is not sent to native platforms', () {
    final configuration = DatadogConfiguration(
      clientToken: 'token',
      env: 'env',
      site: DatadogSite.us1,
      service: 'service',
      desktopDataDirectory: '/data/app',
    );

    expect(configuration.encode().values, isNot(contains('/data/app')));
  });
}
