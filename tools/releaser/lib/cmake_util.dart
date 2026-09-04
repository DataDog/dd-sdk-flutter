// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';

import 'helpers.dart';

/// Matches the `GIT_TAG <ref>` argument anywhere on a line -- not anchored to
/// the line start, since `FetchContent_Declare(dd-sdk-cpp ... GIT_TAG develop)`
/// is valid CMake written on a single line.
final _gitTagPattern = RegExp(r'(?<prefix>GIT_TAG\s+)(?<ref>[\w./-]+)');

/// A trailing `# ...` comment, stripped before [_gitTagPattern] is applied so
/// a previous run's `# <tag>` annotation is replaced rather than duplicated --
/// and so a `#`-commented mention of `GIT_TAG` can't be mistaken for the pin.
final _trailingCommentPattern = RegExp(r'\s*#.*$');

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
    if (scanner.accept(line) &&
        _gitTagPattern.hasMatch(
          line.replaceFirst(_trailingCommentPattern, ''),
        )) {
      return true;
    }
  }
  return false;
}

/// The `GIT_TAG` ref currently declared in [cmakeListsContent]'s
/// `FetchContent_Declare(dd-sdk-cpp ...)` block (e.g. `develop`, or a
/// previously-pinned tag/SHA), or null if there isn't one. Purely
/// informational -- a display string for "what this currently says", never
/// compared against anything; see `NativeSdkDelta.currentDeclaration`.
String? currentGitTag(String cmakeListsContent) {
  final scanner = _DdSdkCppBlockScanner();
  for (final line in cmakeListsContent.split('\n')) {
    if (!scanner.accept(line)) continue;
    final match = _gitTagPattern.firstMatch(
      line.replaceFirst(_trailingCommentPattern, ''),
    );
    if (match != null) return match.namedGroup('ref');
  }
  return null;
}

/// Rewrites [line]'s `GIT_TAG` ref to [targetSha], re-annotated with
/// `# [targetTag]`, leaving everything else on the line as-is -- a trailing
/// `)` closing the `FetchContent_Declare(...` call, a `GIT_REPOSITORY` sharing
/// the line in a single-line declaration, the original indentation. The
/// comment goes at end of line, since a `#` placed before the closing paren
/// would comment it out and break the call.
String _pinGitTagLine(String line, String targetTag, String targetSha) {
  final bare = line.replaceFirst(_trailingCommentPattern, '');
  final match = _gitTagPattern.firstMatch(bare);
  if (match == null) return line;

  final pinned = bare.replaceRange(
    match.start,
    match.end,
    '${match.namedGroup('prefix')}$targetSha',
  );
  return '${pinned.trimRight()}  # $targetTag';
}

/// Rewrites a CMakeLists.txt's dd-sdk-cpp `GIT_TAG` line to pin at
/// [targetSha] -- the resolved commit SHA for [targetTag] (e.g. `v1.4.0`),
/// kept as a trailing `# <tag>` comment since CMake's `FetchContent_Declare`
/// has no field of its own for pairing a tag with a verified commit. A
/// full commit SHA is used as the actual pin (not the tag) because it's
/// immutable, unlike a tag, which can be moved to point elsewhere later.
///
/// Preserves the line's existing whitespace and everything around the ref --
/// see [_pinGitTagLine].
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

  await transformFile(
    cmakeListsFile,
    logger,
    dryRun,
    (line) => scanner.accept(line)
        ? _pinGitTagLine(line, targetTag, targetSha)
        : line,
  );
}
