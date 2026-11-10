// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flags/datadog_flags.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_app/flags/flags_example_config.dart';

void main() {
  test('unsupported government site leaves Flags unconfigured', () {
    dotenv.testLoad(fileInput: '');
    final site = FlagsExampleSiteConfig.fromName('ddog-gov.com');
    expect(site.flagsSite, isNull);
    final flags = FlagsExampleConfig.fromDotEnv(
      clientToken: 'test-token',
      env: 'test',
      site: site.flagsSite,
      applicationId: null,
    );
    expect(flags.configuration.datadogConfig, isNull);
  });

  test('supported site preserves its region', () {
    expect(
      FlagsExampleSiteConfig.fromName('datadoghq.eu').flagsSite,
      DatadogFlagsSite.eu1,
    );
  });
}
