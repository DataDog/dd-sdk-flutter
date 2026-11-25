// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:io';

import 'package:test/test.dart';

/// Runs git in [dir] with an identity and no signing, so that the tests do
/// not depend on the global git configuration, and returns its output.
String git(String dir, List<String> args) {
  final result = Process.runSync('git', [
    '-c', 'user.name=Test', '-c', 'user.email=test@example.com', //
    '-c', 'commit.gpgsign=false', '-c', 'tag.gpgsign=false',
    ...args,
  ], workingDirectory: dir);
  if (result.exitCode != 0) {
    fail('git ${args.join(' ')} failed: ${result.stderr}');
  }
  return result.stdout.toString().trim();
}

void gitInit(String dir) {
  git(dir, ['init', '--quiet']);
  git(dir, ['symbolic-ref', 'HEAD', 'refs/heads/master']);
}
