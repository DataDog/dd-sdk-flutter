// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:releaser/gradle_util.dart';
import 'package:test/test.dart';

void main() {
  test('pins the version, preserving indentation', () {
    expect(
      pinAndroidGradleVersionLine('    ext.datadog_version = "3+"', '3.11.0'),
      '    ext.datadog_version = "3.11.0"',
    );
  });

  test('pins regardless of the spacing around the assignment', () {
    // The pattern tolerates any spacing, so the rewrite has to as well --
    // rebuilding a literal `ext.datadog_version = "..."` matched these lines
    // and then silently replaced nothing in them.
    expect(
      pinAndroidGradleVersionLine(
        '    ext.datadog_version    =    "3+"',
        '3.11.0',
      ),
      '    ext.datadog_version    =    "3.11.0"',
    );
    expect(
      pinAndroidGradleVersionLine('    ext.datadog_version="3+"', '3.11.0'),
      '    ext.datadog_version="3.11.0"',
    );
  });

  test('leaves anything after the assignment alone', () {
    expect(
      pinAndroidGradleVersionLine(
        '    ext.datadog_version = "3+" // floating on develop',
        '3.11.0',
      ),
      '    ext.datadog_version = "3.11.0" // floating on develop',
    );
  });

  test('leaves an unrelated line untouched', () {
    expect(
      pinAndroidGradleVersionLine(
        '    ext.kotlin_version = "2.2.20"',
        '3.11.0',
      ),
      '    ext.kotlin_version = "2.2.20"',
    );
  });
}
