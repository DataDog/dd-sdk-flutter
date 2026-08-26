// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';

import 'helpers.dart';

final _gitTagLinePattern = RegExp(
  r'^(?<prefix>\s*GIT_TAG\s+)(?<ref>[\w./-]+)(?<trailing>[^#]*)(?:#.*)?$',
);

final _ddSdkCppDeclareStartPattern = RegExp(
  r'FetchContent_Declare\(\s*dd-sdk-cpp\b',
);

/// Tracks whether a line belongs to the `FetchContent_Declare(dd-sdk-cpp ...)`
/// call, which can span several lines -- a `CMakeLists.txt` is free to declare
/// other `FetchContent` dependencies, and only dd-sdk-cpp's `GIT_TAG` is this
/// tooling's to read or rewrite.
///
/// Shared by [hasDdSdkCppGitTag] (which decides whether a file counts as a
/// dd-sdk-cpp dependency file at all) and [pinCppVersion] (which rewrites it),
/// so the two can't disagree about where the block starts and ends.
class _DdSdkCppBlockScanner {
  var _inBlock = false;
  var _parenDepth = 0;

  static int _parenBalance(String line) =>
      '('.allMatches(line).length - ')'.allMatches(line).length;

  /// Advances the scanner over [line] and returns whether that line is inside
  /// the block -- the opening `FetchContent_Declare(dd-sdk-cpp` line included,
  /// since a single-line declaration carries its `GIT_TAG` there.
  bool accept(String line) {
    if (_ddSdkCppDeclareStartPattern.hasMatch(line)) {
      _inBlock = true;
      _parenDepth = _parenBalance(line);
    } else if (_inBlock) {
      _parenDepth += _parenBalance(line);
    }

    final result = _inBlock;
    if (_inBlock && _parenDepth <= 0) _inBlock = false;
    return result;
  }
}

/// Whether [cmakeListsContent] pins dd-sdk-cpp -- a `GIT_TAG` line inside a
/// `FetchContent_Declare(dd-sdk-cpp ...)` call. This is what makes a
/// `windows/`/`linux/` `CMakeLists.txt` a native-dependency file as far as
/// `native_sdk.dart`'s discovery is concerned; a file whose only `GIT_TAG`
/// belongs to some other vendored dependency isn't one.
bool hasDdSdkCppGitTag(String cmakeListsContent) {
  final scanner = _DdSdkCppBlockScanner();
  for (final line in cmakeListsContent.split('\n')) {
    if (scanner.accept(line) && _gitTagLinePattern.hasMatch(line)) return true;
  }
  return false;
}

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

  final scanner = _DdSdkCppBlockScanner();

  await transformFile(cmakeListsFile, logger, dryRun, (line) {
    if (!scanner.accept(line)) return line;

    final match = _gitTagLinePattern.firstMatch(line);
    if (match == null) return line;

    final prefix = match.namedGroup('prefix')!;
    final trailing = (match.namedGroup('trailing') ?? '').trimRight();
    return '$prefix$targetSha$trailing  # $targetTag';
  });
}
