// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.
// ignore_for_file: avoid_print

// Regenerates the jnigen bindings for every package that declares a
// jnigen.yaml and fails if the result differs from the checked-in file on
// disk.
//
// jnigen resolves the Android classpath itself (it runs
// `flutter build apk --config-only` against the package's `android_example`
// and reads the Gradle dependency graph), so unlike verify_ffi_bindings.dart
// this needs no separate build step -- just an Android SDK on PATH.
//
// A drift here means the generated bridge no longer matches either the
// Kotlin source it wraps or the installed jnigen version. The latter matters
// on its own: jnigen 0.17.0 fixed a bug where jnigen <=0.16.x dropped the
// keep-alive reference on JNI receivers, which the GC could then collect out
// from under a native call and crash ART with a use-after-free. Bumping the
// jnigen constraint in pubspec.yaml does nothing until the generated file is
// refreshed, so this check also catches that class of drift.
//
// Usage:
//   dart tools/ci/bin/verify_jni_bindings.dart [--write]
//
//     --write   Leave the regenerated files in place instead of restoring
//               them (i.e. accept the new output).

import 'dart:io';

import 'package:ci_helpers/generated_file_verifier.dart';
import 'package:path/path.dart' as path;

class _JniPackage {
  const _JniPackage(this.pkgRelPath, this.bindingsRelPath);

  final String pkgRelPath;
  final String bindingsRelPath;
}

const _packages = [
  _JniPackage(
    'packages/datadog_flutter_plugin/datadog_flutter_plugin_android',
    'lib/src/datadog_android_bridge.dart',
  ),
  _JniPackage(
    'packages/datadog_session_replay',
    'lib/src/android/datadog_session_replay_bridge_android.dart',
  ),
];

void main(List<String> args) {
  final root = findRepoRoot(Platform.script.toFilePath());
  final write = args.contains('--write');

  var allUpToDate = true;
  for (final pkg in _packages) {
    final pkgDir = Directory(path.join(root, pkg.pkgRelPath));
    final bindings = File(path.join(pkgDir.path, pkg.bindingsRelPath));

    final upToDate = verifyGeneratedFile(
      root: root,
      bindings: bindings,
      label: pkg.pkgRelPath,
      toolName: 'jnigen',
      write: write,
      regenerate: () => Process.runSync(Platform.resolvedExecutable, [
        'run',
        'jnigen',
        '--config',
        'jnigen.yaml',
      ], workingDirectory: pkgDir.path),
    );
    if (!upToDate) allUpToDate = false;
  }

  if (allUpToDate) {
    exit(0);
  }

  print(
    'ERROR: one or more jnigen bindings are out of date with their Kotlin '
    'source or the installed jnigen version.\n\n'
    'Regenerate and commit:\n'
    '  dart tools/ci/bin/verify_jni_bindings.dart --write',
  );
  exit(1);
}
