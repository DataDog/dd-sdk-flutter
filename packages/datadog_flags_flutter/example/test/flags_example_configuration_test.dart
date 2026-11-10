// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:datadog_flags_flutter_example/flags_example_configuration.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unsupported government site does not create a Flags configuration', () {
    expect(
      flagsExampleConfiguration(
        site: DatadogSite.us1Fed,
        clientToken: 'test-token',
        env: 'test',
      ),
      isNull,
    );
  });

  test('supported site preserves the configured region', () {
    final configuration = flagsExampleConfiguration(
      site: DatadogSite.eu1,
      clientToken: 'test-token',
      env: 'test',
    );
    expect(configuration?.site, DatadogFlagsSite.eu1);
  });
}
