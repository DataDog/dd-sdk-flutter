// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:args/command_runner.dart';
import 'package:ci_helpers/secrets_command.dart';
import 'package:test/test.dart';

void main() {
  final cases = {
    'get without a secret': ['get'],
    'get with an unknown group': ['get', 'nope/client_token'],
    'get with an unknown field': ['get', 'e2e/nope'],
    'get without a field': ['get', 'e2e'],
    'set without a group': ['set'],
    'set with an unknown group': ['set', 'nope'],
  };
  for (final MapEntry(key: name, value: arguments) in cases.entries) {
    test('$name is a usage error', () {
      final runner = CommandRunner<void>('ci', '')
        ..addCommand(SecretsCommand());
      expect(
        runner.run(['secrets', ...arguments]),
        throwsA(isA<UsageException>()),
      );
    });
  }
}
