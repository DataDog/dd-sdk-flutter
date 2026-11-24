// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:test/test.dart';

import '../bin/sr_models_generator.dart';

void main() {
  // Arguments -> the options they give.
  final valid = {
    <String>[]: (check: false, ref: null),
    ['--check']: (check: true, ref: null),
    ['--ref', 'master']: (check: false, ref: 'master'),
  };
  for (final MapEntry(key: arguments, value: options) in valid.entries) {
    test('parses [${arguments.join(' ')}]', () {
      expect(parseArguments(arguments), options);
    });
  }

  test('gives no options with --help', () {
    expect(parseArguments(['--help']), isNull);
  });

  // Arguments -> the error they give.
  final invalid = {
    ['--nope']: 'Could not find an option named "--nope"',
    ['--ref', 'master', '--check']:
        '--ref and --check cannot be used together.',
    ['--ref', '']: '--ref needs a branch, tag or SHA.',
  };
  for (final MapEntry(key: arguments, value: message) in invalid.entries) {
    test('rejects ${arguments.join(' ')}', () {
      expect(
        () => parseArguments(arguments),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(message),
          ),
        ),
      );
    });
  }

  test('describes every option in the usage', () {
    expect(usage, contains('Usage: dart run sr_models_generator'));
    expect(usage, contains('--check'));
    expect(usage, contains('--ref'));
  });
}
