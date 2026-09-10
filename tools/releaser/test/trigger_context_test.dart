// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:releaser/trigger_context.dart';
import 'package:test/test.dart';

void main() {
  group('TriggerContext.parse', () {
    test('parses each named context', () {
      expect(TriggerContext.parse('mainline'), TriggerContext.mainline);
      expect(TriggerContext.parse('patch'), TriggerContext.patch);
      expect(TriggerContext.parse('prerelease'), TriggerContext.preRelease);
    });

    test('"auto" is null -- it asks for branch-name detection, not a name', () {
      expect(TriggerContext.parse('auto'), isNull);
    });

    test('anything unrecognized is null', () {
      expect(TriggerContext.parse('nonsense'), isNull);
      expect(TriggerContext.parse(''), isNull);
    });
  });
}
