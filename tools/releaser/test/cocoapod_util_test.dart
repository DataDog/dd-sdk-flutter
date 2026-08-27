// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:releaser/cocoapod_util.dart';
import 'package:test/test.dart';

void main() {
  test('pins the constraint, preserving indentation', () {
    expect(
      pinIosPodspecDependencyLine(
        "  s.dependency 'DatadogCore', '~> 3'",
        '3.13.0',
      ),
      "  s.dependency 'DatadogCore', '3.13.0'",
    );
  });

  test('keeps the podspec\'s own spacing around the comma', () {
    // datadog_inappwebview_tracking writes it this way. The old pattern
    // required a single space and never matched the line at all; now that it
    // does, the rewrite must not reformat what it matched.
    expect(
      pinIosPodspecDependencyLine(
        "  s.dependency 'DatadogCore',  '~> 3.0'",
        '3.13.0',
      ),
      "  s.dependency 'DatadogCore',  '3.13.0'",
    );
  });

  test('leaves anything after the constraint alone', () {
    expect(
      pinIosPodspecDependencyLine(
        "  s.dependency 'DatadogCore', '~> 3' # floating on develop",
        '3.13.0',
      ),
      "  s.dependency 'DatadogCore', '3.13.0' # floating on develop",
    );
  });

  test('leaves a non-Datadog dependency untouched', () {
    const line = "  s.dependency 'Flutter'";
    expect(pinIosPodspecDependencyLine(line, '3.13.0'), line);
    const other = "  s.dependency 'DictionaryCoder', '1.2.0'";
    expect(pinIosPodspecDependencyLine(other, '3.13.0'), other);
  });
}
