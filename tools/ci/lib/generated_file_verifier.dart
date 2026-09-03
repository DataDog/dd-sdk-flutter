// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.
// ignore_for_file: avoid_print

// Shared "regenerate checked-in files and diff them" machinery used by
// bin/verify_ffi_bindings.dart, bin/verify_ios_ffi_bindings.dart and
// bin/verify_jni_bindings.dart. All three follow the same shape: back up the
// committed output(s), rerun the generator, compare, and either restore the
// originals (verify mode) or leave the regenerated output in place (--write).

import 'dart:io';

import 'package:path/path.dart' as path;

/// Walks up from [scriptPath] to find the repository root (the directory
/// containing melos.yaml), preferring `$MELOS_ROOT_PATH` when it already
/// points at one.
String findRepoRoot(String scriptPath) {
  final fromEnv = Platform.environment['MELOS_ROOT_PATH'];
  if (fromEnv != null && File(path.join(fromEnv, 'melos.yaml')).existsSync()) {
    return fromEnv;
  }
  var dir = path.dirname(scriptPath);
  for (var i = 0; i < 8; i++) {
    if (File(path.join(dir, 'melos.yaml')).existsSync()) return dir;
    dir = path.dirname(dir);
  }
  print('Could not locate the repository root (no melos.yaml found).');
  exit(2);
}

/// Regenerates [outputs] by running [regenerate] once and diffs each result
/// against what was committed.
///
/// Some generators produce a single file (jnigen, desktop ffigen); others
/// produce several from one pipeline run (iOS: a Swift-emitted bridging
/// header, plus the ffigen bindings and Objective-C shim generated from it).
/// Either way [regenerate] is invoked exactly once, then every path in
/// [outputs] is compared.
///
/// On a mismatch, a real diff (via `git diff --no-index`) is printed for each
/// changed file and the original is restored, unless [write] is true, in
/// which case the regenerated output is left in place. [label] identifies the
/// target in log output (e.g. a package path) and [toolName] names the
/// generator, used in the failure message if [regenerate] exits non-zero.
///
/// Returns true if every output was already up to date.
bool verifyGeneratedFiles({
  required String root,
  required List<File> outputs,
  required String label,
  required String toolName,
  required ProcessResult Function() regenerate,
  required bool write,
}) {
  for (final output in outputs) {
    if (!output.existsSync()) {
      print('Generated file not found at ${output.path}');
      exit(2);
    }
  }

  final backups = {
    for (final output in outputs)
      output: File('${output.path}.verify-backup')
        ..writeAsStringSync(output.readAsStringSync()),
  };

  print('== $label ==');
  print('Regenerating...\n');

  final result = regenerate();
  if (result.exitCode != 0) {
    for (final backup in backups.values) {
      backup.deleteSync();
    }
    print('$toolName failed:\n${result.stdout}\n${result.stderr}');
    exit(2);
  }

  var upToDate = true;
  for (final MapEntry(key: output, value: backup) in backups.entries) {
    final before = backup.readAsStringSync();
    final after = output.readAsStringSync();
    if (after == before) continue;

    upToDate = false;
    final diff = Process.runSync('git', [
      '--no-pager',
      'diff',
      '--no-index',
      '--',
      backup.path,
      output.path,
    ], workingDirectory: root);
    print(diff.stdout);

    if (!write) {
      output.writeAsStringSync(before);
    }
  }

  for (final backup in backups.values) {
    backup.deleteSync();
  }

  if (upToDate) {
    print('Bindings are up to date.\n');
  } else if (write) {
    print('\nRegenerated bindings left in place (--write).\n');
  }

  return upToDate;
}

/// Single-output convenience wrapper around [verifyGeneratedFiles].
bool verifyGeneratedFile({
  required String root,
  required File bindings,
  required String label,
  required String toolName,
  required ProcessResult Function() regenerate,
  required bool write,
}) => verifyGeneratedFiles(
  root: root,
  outputs: [bindings],
  label: label,
  toolName: toolName,
  regenerate: regenerate,
  write: write,
);
