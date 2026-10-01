// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

@TestOn('vm')
library;

import 'dart:io';

import 'package:datadog_flags/src/sdk_metadata.dart';
import 'package:datadog_flags/src/version.dart';
import 'package:test/test.dart';

void main() {
  test('assignment identity uses the published Flags package version', () {
    final manifest = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version: (\S+)$', multiLine: true)
        .firstMatch(manifest)!
        .group(1);
    expect(ddPackageVersion, version);
    expect(datadogFlagsSdkVersion, ddPackageVersion);
    expect(datadogFlagsSdkName, 'dd-sdk-dart');
  });
}
