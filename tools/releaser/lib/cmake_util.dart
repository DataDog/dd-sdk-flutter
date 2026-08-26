// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';

import 'helpers.dart';

final _gitTagLinePattern = RegExp(
  r'^(?<prefix>\s*GIT_TAG\s+)(?<ref>[\w./-]+)(?<trailing>[^#]*)(?:#.*)?$',
);

/// Matches the start of the `FetchContent_Declare(dd-sdk-cpp ...` call --
/// used to find where that block begins, since a `CMakeLists.txt` can
/// declare more than one `FetchContent` dependency and only this one's
/// `GIT_TAG` should be read/rewritten. Public so `native_sdk.dart`'s
/// `readCppCMakePin` scopes its read the same way this file scopes its
/// write, instead of risking the two drifting out of sync.
final ddSdkCppDeclareStartPattern = RegExp(
  r'FetchContent_Declare\(\s*dd-sdk-cpp\b',
);

/// Public alongside [ddSdkCppDeclareStartPattern] for the same reason --
/// `native_sdk.dart` needs to track the same multi-line block boundary.
int parenBalance(String line) =>
    '('.allMatches(line).length - ')'.allMatches(line).length;

/// Rewrites a CMakeLists.txt's dd-sdk-cpp `GIT_TAG` line to pin at
/// [targetSha] -- the resolved commit SHA for [targetTag] (e.g. `v1.4.0`),
/// kept as a trailing `# <tag>` comment since CMake's `FetchContent_Declare`
/// has no field of its own for pairing a tag with a verified commit. A
/// full commit SHA is used as the actual pin (not the tag) because it's
/// immutable, unlike a tag, which can be moved to point elsewhere later.
///
/// Preserves the line's existing whitespace and anything between the ref
/// and end of line -- a trailing `)` closing the `FetchContent_Declare(...`
/// call is common, and the new comment is appended *after* it, since a `#`
/// placed before would comment out the paren too and break the call.
///
/// Only rewrites a `GIT_TAG` line while inside the `dd-sdk-cpp`
/// `FetchContent_Declare(...)` block (tracked by paren balance across
/// lines, since the call can span several) -- a file that also vendors
/// another dependency via its own `FetchContent_Declare` must have that
/// dependency's `GIT_TAG` left untouched.
///
/// Only ever called against a release-prep/patch/pre-release branch's copy
/// of the file -- `develop`'s own floating `GIT_TAG develop` is never
/// touched by release tooling.
Future<void> pinCppVersion(
  File cmakeListsFile,
  String targetTag,
  String targetSha,
  Logger logger,
  bool dryRun,
) async {
  logger.info(
    'ℹ️ Pinning dd-sdk-cpp GIT_TAG to $targetSha ($targetTag) in '
    '${cmakeListsFile.path}',
  );

  var insideDdSdkCppDeclare = false;
  var parenDepth = 0;

  await transformFile(cmakeListsFile, logger, dryRun, (line) {
    if (ddSdkCppDeclareStartPattern.hasMatch(line)) {
      insideDdSdkCppDeclare = true;
      parenDepth = parenBalance(line);
    } else if (insideDdSdkCppDeclare) {
      parenDepth += parenBalance(line);
    }

    var result = line;
    if (insideDdSdkCppDeclare) {
      final match = _gitTagLinePattern.firstMatch(line);
      if (match != null) {
        final prefix = match.namedGroup('prefix')!;
        final trailing = (match.namedGroup('trailing') ?? '').trimRight();
        result = '$prefix$targetSha$trailing  # $targetTag';
      }
    }

    if (insideDdSdkCppDeclare && parenDepth <= 0) {
      insideDdSdkCppDeclare = false;
    }

    return result;
  });
}
