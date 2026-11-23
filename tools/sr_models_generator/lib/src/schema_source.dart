// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

/// A rum-events-format checkout at a known commit.
@immutable
final class SchemaCheckout {
  SchemaCheckout(this.directory, this.commit);

  /// Root of the checkout; the schemas root for `SchemaLoader`.
  final String directory;

  /// Full SHA of the checked out commit.
  final String commit;
}

/// Whether [value] is a full, lowercase, 40-character git commit SHA.
bool isFullCommitSha(String value) => RegExp(r'^[0-9a-f]{40}$').hasMatch(value);

/// Checks out the commit [sha] of [repository] in [cacheDirectory].
///
/// [cacheDirectory] belongs to the generator: local changes in it are
/// discarded. [progress] is told when the commit has to be downloaded.
Future<SchemaCheckout> checkoutCommit({
  required String repository,
  required String sha,
  required String cacheDirectory,
  void Function(String message)? progress,
}) async {
  if (!isFullCommitSha(sha)) {
    throw ArgumentError.value(
      sha,
      'sha',
      'Must be a full 40-character commit SHA; '
          'use fetchLatest for branches and tags',
    );
  }
  final dir = await _prepareCache(cacheDirectory);
  if (!await _hasCommit(dir, sha)) {
    await _fetch(dir, repository, sha, progress);
  }
  final checkout = await _checkout(dir, sha);
  if (checkout.commit != sha) {
    throw SchemaFetchException(
      'Checked out ${checkout.commit} instead of $sha',
    );
  }
  return checkout;
}

/// Downloads the commit that [branchOrTag] of [repository] points to now
/// (e.g. `master`) and checks it out in [cacheDirectory].
///
/// [cacheDirectory] belongs to the generator: local changes in it are
/// discarded. [progress] is told when the commit is downloaded.
Future<SchemaCheckout> fetchLatest({
  required String repository,
  required String branchOrTag,
  required String cacheDirectory,
  void Function(String message)? progress,
}) async {
  if (isFullCommitSha(branchOrTag)) {
    throw ArgumentError.value(
      branchOrTag,
      'branchOrTag',
      'Is a commit SHA; use checkoutCommit',
    );
  }
  final dir = await _prepareCache(cacheDirectory);
  await _fetch(dir, repository, branchOrTag, progress);
  return _checkout(dir, 'FETCH_HEAD');
}

Future<String> _prepareCache(String cacheDirectory) async {
  final dir = p.absolute(cacheDirectory);
  await _ensureRepository(dir);
  return dir;
}

Future<void> _fetch(
  String dir,
  String repository,
  String revision,
  void Function(String message)? progress,
) async {
  progress?.call('Fetching $repository at $revision...');
  await _git(dir, ['fetch', '--quiet', '--depth', '1', repository, revision]);
}

/// Checks out [revision] (a SHA or `FETCH_HEAD`) and reads back its SHA.
Future<SchemaCheckout> _checkout(String dir, String revision) async {
  await _git(dir, ['checkout', '--quiet', '--force', '--detach', revision]);
  final commit = (await _git(dir, ['rev-parse', 'HEAD'])).trim();
  return SchemaCheckout(dir, commit);
}

/// Makes [dir] a git repository of its own.
Future<void> _ensureRepository(String dir) async {
  if (Directory(p.join(dir, '.git')).existsSync()) return;
  Directory(dir).createSync(recursive: true);
  await _git(dir, ['init', '--quiet']);
  if (!Directory(p.join(dir, '.git')).existsSync()) {
    throw SchemaFetchException('Could not create a git repository in $dir');
  }
}

Future<bool> _hasCommit(String dir, String sha) async {
  final result = await _run(dir, ['cat-file', '-e', '$sha^{commit}']);
  return result.exitCode == 0;
}

Future<String> _git(String dir, List<String> args) async {
  final result = await _run(dir, args);
  if (result.exitCode != 0) {
    throw SchemaFetchException(
      '`git ${args.join(' ')}` failed (exit code ${result.exitCode}):\n'
      '${result.stderr.toString().trim()}',
    );
  }
  return result.stdout.toString();
}

Future<ProcessResult> _run(String dir, List<String> args) async {
  try {
    return await Process.run('git', args, workingDirectory: dir);
  } on ProcessException catch (e) {
    throw SchemaFetchException('Could not run git: ${e.message}');
  }
}

/// The schemas could not be downloaded or checked out.
@immutable
final class SchemaFetchException implements Exception {
  SchemaFetchException(this.message);

  final String message;

  @override
  String toString() => message;
}
