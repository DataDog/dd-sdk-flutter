// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:collection/collection.dart';
import 'package:git/git.dart';
import 'package:version/version.dart';

/// A package's release tag paired with the version parsed out of its name --
/// returned together so callers don't re-parse `{package}/v{version}` (and
/// can't disagree with [findLastReleaseTag] about how to).
typedef ReleaseTag = ({Tag tag, Version version});

/// The highest-versioned tag matching `{packageName}/v*`, or null if the
/// package has never been tagged (its first release, or a brand-new federated
/// sub-package -- see [commitMessagesSince]'s no-`sinceSha` path).
///
/// Deliberately *not* filtered by reachability from HEAD. Release tags in this
/// repo land on `release/...` branches that are never merged back, so no
/// release tag is an ancestor of `develop` or of a pre-release branch like
/// `v4` -- an ancestor check would reject every real release and fall back to
/// ancient tags. The two callers that need to exclude something exclude it by
/// what the tag *is*, not by where it sits in the graph:
///
/// [versionScope], when given, restricts the search to tags at that
/// major/minor -- and, when its `patch` is non-null, that exact
/// major.minor.patch. A patch branch scopes to its own release line, so a tag
/// mainline has since cut for a newer major/minor can't be picked up instead.
/// A pre-release run scopes to the full version its pubspec declares as the
/// target, since "the last release at 4.0.0" is the only tag that can continue
/// its counter -- an unrelated higher tag (a `4.0.1` patch, a concurrent
/// `5.0.0-beta.1`) would otherwise be selected and mask the real one.
///
/// [stableOnly] drops pre-release versions. Mainline passes this: a
/// `4.0.0-beta.3` tag cut off a long-lived pre-release line sorts above the
/// last stable `3.5.0` but doesn't represent anything shipped stably, so it
/// must not become mainline's baseline. The pre-release path itself wants the
/// opposite (its whole job is continuing that counter) and leaves it false.
Future<ReleaseTag?> findLastReleaseTag(
  GitDir gitDir,
  String packageName, {
  ({int major, int minor, int? patch})? versionScope,
  bool stableOnly = false,
}) async {
  final prefix = '$packageName/v';

  Version? versionOf(Tag tag) {
    try {
      return Version.parse(tag.tag.substring(prefix.length));
    } catch (_) {
      return null;
    }
  }

  final candidates =
      (await gitDir.tags().where((t) => t.tag.startsWith(prefix)).toList())
          .map((tag) => (tag: tag, version: versionOf(tag)))
          .where((pair) => pair.version != null)
          .map((pair) => (tag: pair.tag, version: pair.version!))
          .where((pair) => !stableOnly || !pair.version.isPreRelease)
          .where(
            (pair) =>
                versionScope == null ||
                (pair.version.major == versionScope.major &&
                    pair.version.minor == versionScope.minor &&
                    (versionScope.patch == null ||
                        pair.version.patch == versionScope.patch)),
          )
          .toList()
        ..sort((a, b) => a.version.compareTo(b.version));

  return candidates.lastOrNull;
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
