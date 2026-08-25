// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:collection/collection.dart';
import 'package:git/git.dart';
import 'package:version/version.dart';

/// Finds the most recent tag matching `{packageName}/v*`, or null if the
/// package has never been tagged (its first release, or a brand-new
/// federated sub-package -- see [commitMessagesSince]'s no-`sinceSha` path).
///
/// [releaseLine], when given, restricts the search to tags whose
/// major/minor matches -- a patch branch's own release line, so a tag
/// mainline has since cut for a newer major/minor (which is not an
/// ancestor of the patch branch) can't be picked up instead.
Future<Tag?> findLastReleaseTag(
  GitDir gitDir,
  String packageName, {
  (int major, int minor)? releaseLine,
}) async {
  final prefix = '$packageName/v';
  final matchingTags = await gitDir
      .tags()
      .where((t) => t.tag.startsWith(prefix))
      .toList();

  Version? versionOf(Tag tag) {
    try {
      return Version.parse(tag.tag.substring(prefix.length));
    } catch (_) {
      return null;
    }
  }

  final withVersions =
      matchingTags
          .map((tag) => (tag, versionOf(tag)))
          .where((pair) => pair.$2 != null)
          .where(
            (pair) =>
                releaseLine == null ||
                (pair.$2!.major == releaseLine.$1 &&
                    pair.$2!.minor == releaseLine.$2),
          )
          .toList()
        ..sort((a, b) => a.$2!.compareTo(b.$2!));

  return withVersions.lastOrNull?.$1;
}

/// Full commit messages (subject + body/footers) touching [pathspec], from
/// just after [sinceSha] through HEAD. A null [sinceSha] walks the entire
/// history of [pathspec] -- the "since inception" case for a package with
/// no prior tag.
Future<List<String>> commitMessagesSince(
  GitDir gitDir, {
  required String pathspec,
  String? sinceSha,
}) async {
  final range = sinceSha != null ? '$sinceSha..HEAD' : 'HEAD';
  final result = await gitDir.runCommand([
    '--no-pager',
    'log',
    range,
    '--pretty=format:%B|||END|||',
    '--',
    pathspec,
  ]);

  return (result.stdout as String)
      .split('|||END|||')
      .map((m) => m.trim())
      .where((m) => m.isNotEmpty)
      .toList();
}
