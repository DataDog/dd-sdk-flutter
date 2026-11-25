// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.
// ignore_for_file: avoid_print

// Regenerates datadog_flutter_plugin_desktop's ffigen bindings and fails if the
// result differs from the checked-in file on disk.
//
// The bindings mirror C structs from dd-sdk-cpp, which CMake FetchContent pulls
// at build time, so the C API can move without anything in this repo changing.
// Drift is not a compile error: Dart allocates sizeOf<T>() bytes from the arena
// and the C SDK writes sizeof(struct T) bytes into that allocation. When
// dd_rum_config gained a field upstream, Dart kept allocating 24 bytes while
// dd_rum_config_init() wrote 28. glibc does not notice the 4-byte overflow until
// some later, unrelated free(), so the symptom was an abort() ("free(): invalid
// next size") partway through SDK init that read as a test-harness or background
// isolate problem rather than a bindings problem.
//
// Requires a desktop build to have run first, so the FetchContent headers exist.
// ffigen.yaml's header paths point at the Windows build tree; this retargets them
// at whichever tree is actually present, so the same check runs on Linux too.
//
// Usage:
//   dart tools/ci/bin/verify_ffi_bindings.dart [--headers <dir>] [--write]
//
//     --headers <dir>   Path to dd-sdk-cpp include-c. When omitted, the most
//                       recently built FetchContent tree is used.
//     --write           Leave the regenerated file in place instead of restoring
//                       it (i.e. accept the new output).

import 'dart:io';

import 'package:ci_helpers/generated_file_verifier.dart';
import 'package:path/path.dart' as path;

const _desktopPkgRelPath =
    'packages/datadog_flutter_plugin/datadog_flutter_plugin_desktop';
const _bindingsRelPath = 'lib/src/ffi_bindings.dart';

String? _option(List<String> args, String name) {
  final i = args.indexOf(name);
  return (i >= 0 && i + 1 < args.length) ? args[i + 1] : null;
}

/// Where the FetchContent headers land once `integration_test:<platform>:build`
/// has run. That step always builds the same example, so the path is fixed
/// rather than something we have to go looking for.
///
/// The two platforms differ in shape: Ninja is a single-config generator, so on
/// Linux the build config is part of the path, while MSVC is multi-config and
/// puts _deps directly under x64. The Windows layout is the one ffigen.yaml has
/// always referenced.
List<Directory> _candidateHeaderDirs(String root) {
  final exampleBuild = path.join(root, _desktopPkgRelPath, 'example', 'build');
  Directory dir(List<String> parts) => Directory(
    path.joinAll([
      exampleBuild,
      ...parts,
      '_deps',
      'dd-sdk-cpp-src',
      'include-c',
    ]),
  );
  if (Platform.isWindows) {
    return [
      dir(['windows', 'x64']),
    ];
  }
  // The build step uses --debug; accept a release tree too, for local runs.
  return [
    dir(['linux', 'x64', 'debug']),
    dir(['linux', 'x64', 'release']),
  ];
}

Directory _resolveHeaders(String root, List<String> args) {
  final headersArg = _option(args, '--headers');
  if (headersArg != null) {
    return Directory(path.normalize(path.absolute(headersArg)));
  }
  final candidates = _candidateHeaderDirs(root);
  for (final candidate in candidates) {
    if (File(path.join(candidate.path, 'datadog.h')).existsSync()) {
      return candidate;
    }
  }
  final platform = Platform.isWindows ? 'windows' : 'linux';
  print(
    'ERROR: could not find the dd-sdk-cpp headers. Looked in:\n'
    '${candidates.map((c) => '  ${c.path}').join('\n')}\n\n'
    'Run the build step first so CMake FetchContent populates them:\n'
    '  melos run integration_test:$platform:build\n'
    'or pass --headers <dir>.',
  );
  exit(2);
}

/// Writes a copy of ffigen.yaml whose header paths point at [headers].
///
/// ffigen.yaml is checked in with the Windows build tree's path, which does not
/// exist on Linux. Everything else about the config is preserved, so this stays
/// a faithful regeneration rather than a differently-configured one.
File _tempConfig(Directory pkg, Directory headers) {
  final original = File(path.join(pkg.path, 'ffigen.yaml'));
  final target = headers.path.replaceAll(r'\', '/');
  // Keep any leading -I: the path also appears inside a compiler-opt, and
  // swallowing the flag would turn the include dir into a linker input.
  final rewritten = original.readAsStringSync().replaceAllMapped(
    RegExp(r"""(-I)?[^\s'"]*dd-sdk-cpp-src[/\\]include-c"""),
    (m) => '${m[1] ?? ''}$target',
  );
  final temp = File(path.join(pkg.path, '.ffigen_verify.yaml'))
    ..writeAsStringSync(rewritten);
  return temp;
}

void main(List<String> args) {
  final root = findRepoRoot(Platform.script.toFilePath());
  final pkg = Directory(path.join(root, _desktopPkgRelPath));
  final bindings = File(path.join(pkg.path, _bindingsRelPath));

  final headers = _resolveHeaders(root, args);
  if (!File(path.join(headers.path, 'datadog.h')).existsSync()) {
    print('No datadog.h under ${headers.path}');
    exit(2);
  }

  print('Headers:  ${headers.path}');
  print('Bindings: ${bindings.path}');

  final config = _tempConfig(pkg, headers);
  final bool upToDate;
  try {
    upToDate = verifyGeneratedFile(
      root: root,
      bindings: bindings,
      label: pkg.path,
      toolName: 'ffigen',
      write: args.contains('--write'),
      regenerate: () => Process.runSync(Platform.resolvedExecutable, [
        'run',
        'ffigen',
        '--config',
        path.basename(config.path),
      ], workingDirectory: pkg.path),
    );
  } finally {
    config.deleteSync();
  }

  if (upToDate) {
    exit(0);
  }

  print(
    '\nERROR: ffi_bindings.dart is out of date with the dd-sdk-cpp headers.\n\n'
    'The committed bindings no longer match the C API being built against. '
    'This is not a cosmetic diff: a struct that changed size means Dart and '
    'the C SDK disagree about how many bytes to allocate, which corrupts the '
    'heap at runtime instead of failing to compile.\n\n'
    'Regenerate and commit:\n'
    '  dart tools/ci/bin/verify_ffi_bindings.dart --write',
  );
  exit(1);
}
