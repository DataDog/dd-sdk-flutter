// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sr_models_generator/sr_models_generator.dart';
import 'package:test/test.dart';

/// Runs git in [dir] with an identity and no signing, so that the tests do
/// not depend on the global git configuration.
String git(String dir, List<String> args) {
  final result = Process.runSync('git', [
    '-c', 'user.name=Test', '-c', 'user.email=test@example.com', //
    '-c', 'commit.gpgsign=false', '-c', 'tag.gpgsign=false',
    ...args,
  ], workingDirectory: dir);
  if (result.exitCode != 0) {
    fail('git ${args.join(' ')} failed: ${result.stderr}');
  }
  return (result.stdout as String).trim();
}

/// Writes [content] to `schema.json` in [dir] and commits it.
String commitSchema(String dir, String content) {
  File(p.join(dir, 'schema.json')).writeAsStringSync(content);
  git(dir, ['add', '.']);
  git(dir, ['commit', '--quiet', '-m', content]);
  return git(dir, ['rev-parse', 'HEAD']);
}

void main() {
  late Directory temp;
  late String remoteDir;

  /// `file://` URL of the fake rum-events-format; git ignores `--depth` for
  /// plain local paths.
  late String remote;
  late String firstCommit;
  late String secondCommit;
  late String cache;

  String readSchema(SchemaCheckout checkout) =>
      File(p.join(checkout.directory, 'schema.json')).readAsStringSync();

  Future<SchemaCheckout> checkout(String sha, {String? cacheDirectory}) =>
      checkoutCommit(
        repository: remote,
        sha: sha,
        cacheDirectory: cacheDirectory ?? cache,
      );

  Future<SchemaCheckout> latest(String branchOrTag) => fetchLatest(
    repository: remote,
    branchOrTag: branchOrTag,
    cacheDirectory: cache,
  );

  setUp(() {
    temp = Directory.systemTemp.createTempSync('sr_schema_source_test');
    remoteDir = p.join(temp.path, 'remote');
    Directory(remoteDir).createSync();
    git(remoteDir, ['init', '--quiet', '--initial-branch=master']);
    // Lets clients fetch a commit by SHA, as GitHub does.
    git(remoteDir, ['config', 'uploadpack.allowAnySHA1InWant', 'true']);
    firstCommit = commitSchema(remoteDir, 'first');
    secondCommit = commitSchema(remoteDir, 'second');
    git(remoteDir, ['tag', 'v1', firstCommit]);
    remote = Uri.directory(remoteDir).toString();
    cache = p.join(temp.path, 'cache');
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('isFullCommitSha accepts only full lowercase SHAs', () {
    expect(isFullCommitSha(firstCommit), isTrue);
    expect(isFullCommitSha(firstCommit.substring(0, 7)), isFalse);
    expect(isFullCommitSha(firstCommit.toUpperCase()), isFalse);
    expect(isFullCommitSha('master'), isFalse);
  });

  group('checkoutCommit', () {
    test('checks out the commit', () async {
      final result = await checkout(firstCommit);
      expect(result.commit, firstCommit);
      expect(result.directory, p.absolute(cache));
      expect(readSchema(result), 'first');
    });

    test('downloads only that commit', () async {
      await checkout(secondCommit);
      expect(git(cache, ['rev-list', '--count', 'HEAD']), '1');
    });

    test('reuses a cached commit without contacting the repository', () async {
      await checkout(firstCommit);
      Directory(remoteDir).deleteSync(recursive: true);

      final result = await checkout(firstCommit);
      expect(result.commit, firstCommit);
      expect(readSchema(result), 'first');
    });

    test('switches between commits and discards local changes', () async {
      await checkout(firstCommit);
      await checkout(secondCommit);
      File(p.join(cache, 'schema.json')).writeAsStringSync('edited');

      expect(readSchema(await checkout(firstCommit)), 'first');
    });

    test('rejects branches, tags and short SHAs', () async {
      for (final revision in ['master', 'v1', firstCommit.substring(0, 7)]) {
        await expectLater(
          checkout(revision),
          throwsA(isA<ArgumentError>()),
          reason: revision,
        );
      }
    });

    test('fails on a commit the repository does not have', () async {
      await expectLater(
        checkout('0' * 40),
        throwsA(isA<SchemaFetchException>()),
      );
    });
  });

  group('fetchLatest', () {
    test('returns the commit a branch or tag points to', () async {
      final branch = await latest('master');
      expect(branch.commit, secondCommit);
      expect(readSchema(branch), 'second');

      final tag = await latest('v1');
      expect(tag.commit, firstCommit);
      expect(readSchema(tag), 'first');
    });

    test('sees new commits on the branch', () async {
      await latest('master');
      final thirdCommit = commitSchema(remoteDir, 'third');

      final result = await latest('master');
      expect(result.commit, thirdCommit);
      expect(readSchema(result), 'third');
    });

    test('rejects commit SHAs', () async {
      await expectLater(latest(firstCommit), throwsA(isA<ArgumentError>()));
    });

    test('fails on unknown branches and repositories', () async {
      await expectLater(
        latest('no-such-branch'),
        throwsA(isA<SchemaFetchException>()),
      );
      await expectLater(
        fetchLatest(
          repository: Uri.directory(p.join(temp.path, 'missing')).toString(),
          branchOrTag: 'master',
          cacheDirectory: cache,
        ),
        throwsA(isA<SchemaFetchException>()),
      );
    });
  });

  test('never runs git in a surrounding repository', () async {
    // The real cache lives in .dart_tool/ inside the dd-sdk-flutter
    // repository; a cache directory without its own .git must not make git
    // act on that outer repository.
    final outer = p.join(temp.path, 'outer');
    Directory(outer).createSync();
    git(outer, ['init', '--quiet']);
    File(p.join(outer, 'schema.json')).writeAsStringSync('outer');
    git(outer, ['add', '.']);
    git(outer, ['commit', '--quiet', '-m', 'outer']);
    File(p.join(outer, 'schema.json')).writeAsStringSync('uncommitted work');

    final nested = p.join(outer, '.dart_tool', 'rum-events-format');
    Directory(nested).createSync(recursive: true);
    final result = await checkout(firstCommit, cacheDirectory: nested);

    expect(readSchema(result), 'first');
    expect(
      File(p.join(outer, 'schema.json')).readAsStringSync(),
      'uncommitted work',
    );
    expect(Directory(p.join(nested, '.git')).existsSync(), isTrue);
  });
}
