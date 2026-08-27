// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:releaser/spm_util.dart';
import 'package:test/test.dart';

const _pin = 'exact: "3.13.0"';

void main() {
  test('pins a from: constraint, preserving indentation', () {
    expect(
      pinSpmDependencyLine(
        '        .package(url: "https://github.com/Datadog/dd-sdk-ios.git", from: "3.0.0")',
        _pin,
      ),
      '        .package(url: "https://github.com/Datadog/dd-sdk-ios.git", $_pin)',
    );
  });

  test('pins a branch-tracking dependency', () {
    expect(
      pinSpmDependencyLine(
        '        .package(url: "https://github.com/Datadog/dd-sdk-ios.git", branch: "develop")',
        _pin,
      ),
      '        .package(url: "https://github.com/Datadog/dd-sdk-ios.git", $_pin)',
    );
  });

  test('keeps a trailing comma between array elements', () {
    expect(
      pinSpmDependencyLine(
        '        .package(url: "https://github.com/Datadog/dd-sdk-ios.git", from: "3.0.0"),',
        _pin,
      ),
      '        .package(url: "https://github.com/Datadog/dd-sdk-ios.git", $_pin),',
    );
  });

  test('keeps the manifest\'s own URL rather than one canonical spelling', () {
    // `DataDog` and `Datadog` both appear across this repo's manifests.
    // Gating the rewrite on an exact match let discovery report a manifest
    // that the rewrite then silently skipped.
    expect(
      pinSpmDependencyLine(
        '        .package(url: "https://github.com/DataDog/dd-sdk-ios.git", from: "3.0.0")',
        _pin,
      ),
      '        .package(url: "https://github.com/DataDog/dd-sdk-ios.git", $_pin)',
    );
  });

  test('leaves a non-Datadog dependency untouched', () {
    const line =
        '        .package(url: "https://github.com/other/pkg.git", from: "1.0.0")';
    expect(pinSpmDependencyLine(line, _pin), line);
  });
}
