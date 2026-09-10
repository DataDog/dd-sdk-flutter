// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:logging/logging.dart';

import 'process_helper.dart';

/// Runs `flutter pub publish --dry-run` in [packageRoot]. Returns whether
/// it succeeded; output is streamed to [logger] either way.
Future<bool> runPublishDryRun(String packageRoot, Logger logger) async {
  logger.info('ℹ️ Running `flutter pub publish --dry-run` in $packageRoot');
  final exitCode = await runProcess(
    'flutter',
    ['pub', 'publish', '--dry-run'],
    workingDirectory: packageRoot,
    stdout: (line) => logger.fine(line),
    stderr: (line) => logger.shout(line),
  );

  if (exitCode != 0) {
    logger.shout('❌ Publish dry-run exited with code $exitCode.');
    return false;
  }
  logger.info('✅ Publish dry-run went fine.');
  return true;
}
