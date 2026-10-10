// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:path/path.dart' as p;

/// A directory under this package's own `build/` (gitignored, stable)
/// rather than [Directory.systemTemp] -- macOS's `$TMPDIR` is subject to
/// periodic cleanup sweeps that raced these fixtures under a full test
/// run, deleting a still-running test's directory out from under it
/// (`git rev-parse` failing with "Unable to read current working
/// directory", or `GitDir.fromExisting` with a dangling symlink). `build/`
/// isn't swept the same way, and only `dart test` itself ever deletes
/// what it creates here (each fixture's own `tearDown`).
Future<Directory> createTestTempDir(String prefix) async {
  final base = Directory(p.join(Directory.current.path, 'build', 'test_tmp'));
  await base.create(recursive: true);
  return base.createTemp(prefix);
}
