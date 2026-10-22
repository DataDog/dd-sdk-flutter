// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.
// ignore_for_file: avoid_print

import 'dart:io';

// Writes a `.env` file from environment variables. Replaces a bash `tee <<
// END` heredoc that melos previously ran via `cmd.exe` on Windows, where
// `tee` doesn't exist.
void main(List<String> arguments) {
  final isE2e = arguments.contains('--e2e');
  final clientTokenVar = isE2e ? 'DD_E2E_CLIENT_TOKEN' : 'DD_CLIENT_TOKEN';
  final applicationIdVar = isE2e
      ? 'DD_E2E_APPLICATION_ID'
      : 'DD_APPLICATION_ID';

  final clientToken = Platform.environment[clientTokenVar] ?? '';
  final applicationId = Platform.environment[applicationIdVar] ?? '';

  final buffer =
      StringBuffer()
        ..writeln(
          '# Edit this file with your Datadog client token, environment and application id',
        )
        ..writeln('DD_CLIENT_TOKEN=$clientToken')
        ..writeln('DD_APPLICATION_ID=$applicationId');

  if (isE2e) {
    final isOnCi = Platform.environment['IS_ON_CI'] ?? 'false';
    buffer.writeln('DD_E2E_IS_ON_CI=$isOnCi');
  }
  buffer.writeln('DD_ENV=prod');

  print('Generating .env');
  File('.env').writeAsStringSync(buffer.toString());
}
