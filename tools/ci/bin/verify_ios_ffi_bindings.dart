// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.
// ignore_for_file: avoid_print

// Regenerates datadog_session_replay's iOS FFI bindings and fails if the
// result differs from what is committed.
//
// Unlike the desktop bindings (ffi_bindings.dart, generated from headers
// CMake FetchContent pulls at build time), the iOS bridge is generated from
// this repo's own Swift source in two steps:
//
//   1. `swift build` on the datadog_session_replay Swift package emits an
//      Objective-C bridging header via `-emit-objc-header`
//      (Sources/ObjC/include/datadog_session_replay_bridge.h). This build is
//      expected to fail -- the package has no access to the `Flutter` module
//      outside of a full app build -- but the header is written before that
//      failure, per CONTRIBUTING.md.
//   2. `ffigen --config ffigen_ios.yaml` reads that header and generates both
//      the Dart bindings and an Objective-C shim (.dart.m) from it.
//
// A drift in any of the three files means the Dart/Swift bridge no longer
// matches the Swift interface it wraps.
//
// Usage:
//   dart tools/ci/bin/verify_ios_ffi_bindings.dart [--write]
//
//     --write   Leave the regenerated files in place instead of restoring
//               them (i.e. accept the new output).

import 'dart:io';

import 'package:ci_helpers/generated_file_verifier.dart';
import 'package:path/path.dart' as path;

const _pkgRelPath = 'packages/datadog_session_replay';
const _swiftPkgRelPath = 'ios/datadog_session_replay';
const _headerRelPath = 'Sources/ObjC/include/datadog_session_replay_bridge.h';
const _objcShimRelPath = 'Sources/ObjC/datadog_session_replay_bridge.dart.m';
const _dartBindingsRelPath = 'lib/src/ios/datadog_session_replay_bridge_ios.dart';

/// Runs the two-step iOS FFI pipeline and reports it as a single result.
ProcessResult _regenerate(Directory pkg, File header) {
  final swiftPkg = Directory(path.join(pkg.path, _swiftPkgRelPath));
  final swiftResult = Process.runSync('swift', [
    'build',
  ], workingDirectory: swiftPkg.path);

  // `swift build` is expected to fail outside of a full app build (see the
  // file comment above) -- what matters is whether it got far enough to
  // (re)write the bridging header before hitting that failure.
  if (!header.existsSync()) {
    return ProcessResult(
      swiftResult.pid,
      2,
      swiftResult.stdout,
      'swift build did not produce a bridging header at '
      '${header.path}:\n${swiftResult.stderr}',
    );
  }

  return Process.runSync(Platform.resolvedExecutable, [
    'run',
    'ffigen',
    '--config',
    'ffigen_ios.yaml',
  ], workingDirectory: pkg.path);
}

void main(List<String> args) {
  final root = findRepoRoot(Platform.script.toFilePath());
  final pkg = Directory(path.join(root, _pkgRelPath));
  final header = File(
    path.join(pkg.path, _swiftPkgRelPath, _headerRelPath),
  );
  final objcShim = File(
    path.join(pkg.path, _swiftPkgRelPath, _objcShimRelPath),
  );
  final dartBindings = File(path.join(pkg.path, _dartBindingsRelPath));

  final upToDate = verifyGeneratedFiles(
    root: root,
    outputs: [header, dartBindings, objcShim],
    label: _pkgRelPath,
    toolName: 'swift build / ffigen',
    write: args.contains('--write'),
    regenerate: () => _regenerate(pkg, header),
  );

  if (upToDate) {
    exit(0);
  }

  print(
    'ERROR: the iOS FFI bridge is out of date with its Swift source.\n\n'
    'Regenerate and commit:\n'
    '  dart tools/ci/bin/verify_ios_ffi_bindings.dart --write',
  );
  exit(1);
}
