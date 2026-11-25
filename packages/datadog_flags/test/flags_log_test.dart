// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_flags/src/flag_selection.dart';
import 'package:datadog_flags/src/flags_log.dart';
import 'package:test/test.dart';

void main() {
  late List<String> printed;
  late List<(String, int, Object?)> developerLogged;

  setUp(() {
    printed = [];
    developerLogged = [];
    addTearDown(() => DatadogProvider.verbosity = null);
  });

  void capturePrints(void Function() body) => runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (_, _, _, line) => printed.add(line),
    ),
  );

  final logger = FlagsLogger(
    log: (message, {name = '', level = 0, error}) =>
        developerLogged.add((message, level, error)),
  );

  void logOneOfEach() => capturePrints(() {
    logger.error('e');
    logger.warning('w');
    logger.debug('d');
  });

  const developerLogEntries = [
    ('e', 1000, null),
    ('w', 900, null),
    ('d', 500, null),
  ];

  test('prints nothing by default', () {
    expect(DatadogProvider.verbosity, isNull);

    logOneOfEach();

    expect(printed, isEmpty);
    expect(developerLogged, developerLogEntries);
  });

  final printedByVerbosity = {
    FlagsLoggerLevel.error: ['[Datadog Flags - error] e'],
    FlagsLoggerLevel.warning: [
      '[Datadog Flags - error] e',
      '[Datadog Flags - warning] w',
    ],
    FlagsLoggerLevel.debug: [
      '[Datadog Flags - error] e',
      '[Datadog Flags - warning] w',
      '[Datadog Flags - debug] d',
    ],
  };
  for (final MapEntry(key: verbosity, value: expected)
      in printedByVerbosity.entries) {
    test('verbosity ${verbosity.name} prints that level and above', () {
      DatadogProvider.verbosity = verbosity;

      logOneOfEach();

      expect(printed, expected);
      expect(developerLogged, developerLogEntries);
    });
  }

  test('printed message includes the error', () {
    DatadogProvider.verbosity = FlagsLoggerLevel.warning;
    final error = StateError('boom');

    capturePrints(() => logger.warning('Hook failed.', error: error));

    expect(printed, ['[Datadog Flags - warning] Hook failed. Bad state: boom']);
    expect(developerLogged, [('Hook failed.', 900, error)]);
  });

  test('prints flag selection errors through the default logger', () {
    DatadogProvider.verbosity = FlagsLoggerLevel.error;

    capturePrints(
      () => logIgnoredFlagSelection(const FlagsLogger(), 'too_many_values'),
    );

    expect(printed, [
      '[Datadog Flags - error] flagSelection was ignored by the server '
          '(too_many_values). Loaded the full flag configuration.',
    ]);
  });
}
