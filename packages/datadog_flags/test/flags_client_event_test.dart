// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flags/datadog_flags.dart';
import 'package:test/test.dart';

void main() {
  test('omitted and explicitly null keys stay absent', () {
    final omitted = FlagsClientEvent(
      type: FlagsClientEventType.configurationChanged,
    );
    final explicitNull = FlagsClientEvent(
      type: FlagsClientEventType.configurationChanged,
      flagsChanged: null,
    );
    expect(omitted.flagsChanged, isNull);
    expect(explicitNull.flagsChanged, isNull);
  });

  test('explicit empty keys remain present and immutable', () {
    final keys = <String>[];
    final event = FlagsClientEvent(
      type: FlagsClientEventType.configurationChanged,
      flagsChanged: keys,
    );
    keys.add('later');
    expect(event.flagsChanged, isNotNull);
    expect(event.flagsChanged, isEmpty);
    expect(() => event.flagsChanged!.add('mutation'), throwsUnsupportedError);
  });

  test('snapshots mutable keys without filtering or reordering', () {
    final keys = ['second', 'first', 'first'];
    final event = FlagsClientEvent(
      type: FlagsClientEventType.configurationChanged,
      flagsChanged: keys,
    );
    keys[0] = 'replacement';
    keys.clear();
    expect(event.flagsChanged, ['second', 'first', 'first']);
    expect(() => event.flagsChanged![0] = 'mutation', throwsUnsupportedError);
    expect(() => event.flagsChanged!.clear(), throwsUnsupportedError);
  });
}
