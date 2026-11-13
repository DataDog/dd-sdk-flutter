// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:ci_helpers/secrets_command.dart';
import 'package:ci_helpers/simulator_command.dart';
import 'package:ci_helpers/stop_emulators_command.dart';
import 'package:ci_helpers/web_command.dart';

Future<void> main(List<String> arguments) async {
  final runner =
      CommandRunner(
          'ci',
          'Helper command line utils for CI of the Datadog Flutter SDK',
        )
        ..addCommand(SimulatorCommand())
        ..addCommand(SecretsCommand())
        ..addCommand(StopEmulatorsCommand())
        ..addCommand(WebCommand());
  try {
    await runner.run(arguments);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  } on VaultException catch (e) {
    stderr.writeln(e.message);
    exit(1);
  } on ProcessException catch (e) {
    stderr.writeln('Could not run ${e.executable}: ${e.message}');
    exit(1);
  }
}
