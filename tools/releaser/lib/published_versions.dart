// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:version/version.dart';

/// Every version of one package that has actually been published, newest
/// last.
///
/// pub.dev is the source of truth for release history here, in preference to
/// git tags or GitHub Releases, because publishing *is* the event. A tag or a
/// GitHub Release is created after the fact and can therefore be skipped --
/// measured against this repo, GitHub Releases are missing 5 of
/// `datadog_flutter_plugin`'s 65 published versions and tags are missing 2,
/// while pub.dev by definition cannot be missing any. Drift is entirely
/// one-directional.
///
/// It also has no topology. Release commits land on `release/...` branches
/// that never merge back, so "which versions exist" cannot be answered from
/// the commit graph of the branch being planned.
class PublishedVersions {
  /// Ascending semver order. Empty when the package has never been published.
  final List<Version> versions;

  PublishedVersions(List<Version> versions)
    : versions = List.unmodifiable(versions.toList()..sort());

  /// A package pub.dev has never heard of -- its first release. Distinct from
  /// a lookup failure, which throws.
  static final never = PublishedVersions(const []);

  bool get isEmpty => versions.isEmpty;

  /// The newest release of any kind, pre-release included.
  ///
  /// This is "when did we last ship anything", which is what a commit range
  /// and an eligibility check want -- as opposed to [latestStable], which is
  /// what a *version* is computed from. On a pre-release line those differ,
  /// and conflating them is what made an untouched package pick up its entire
  /// history and qualify for a spurious beta.
  Version? get latest => versions.lastOrNull;

  /// The newest non-pre-release version. Mainline's baseline, and the base a
  /// pre-release target is computed from.
  Version? get latestStable =>
      versions.where((v) => !v.isPreRelease).lastOrNull;

  /// The newest release on a `{major}.{minor}.x` line -- a patch branch's own
  /// line, so a newer major/minor mainline has since cut can't be picked up.
  Version? latestOn(int major, int minor) =>
      versions.where((v) => v.major == major && v.minor == minor).lastOrNull;

  /// Pre-releases already published against [target]'s exact
  /// major.minor.patch, ascending -- the counter a new pre-release continues.
  /// [target]'s own pre-release suffix, if any, is ignored: a pubspec sitting
  /// at `4.0.0-beta.1` is still working towards `4.0.0`.
  List<Version> prereleasesAt(Version target) => versions
      .where(
        (v) =>
            v.isPreRelease &&
            v.major == target.major &&
            v.minor == target.minor &&
            v.patch == target.patch,
      )
      .toList();

  /// Whether [target]'s exact major.minor.patch has already shipped stably --
  /// a new pre-release against it would sort below an existing release.
  bool hasStableAt(Version target) => versions.any(
    (v) =>
        !v.isPreRelease &&
        v.major == target.major &&
        v.minor == target.minor &&
        v.patch == target.patch,
  );
}

/// Fetches a package's published versions. Injected so tests -- and
/// `preview_release.dart`'s unit tests -- don't reach the network.
typedef PublishedVersionsGateway =
    Future<PublishedVersions> Function(String packageName);

/// Reads release history from pub.dev's public API.
///
/// A 404 means the package has never been published ([PublishedVersions.never])
/// -- the first-release path, and the expected state of the federated
/// sub-packages that have yet to ship. Any other failure throws rather than
/// degrading to a guess: an under-reported history silently recomputes a
/// version that already exists, and there is deliberately no fallback to tag
/// scanning, since that is the archaeology this module exists to replace.
Future<PublishedVersions> fetchPublishedVersions(String packageName) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.https('pub.dev', '/api/packages/$packageName'),
    );
    final response = await request.close();

    if (response.statusCode == HttpStatus.notFound) {
      await response.drain<void>();
      return PublishedVersions.never;
    }
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw StateError(
        'pub.dev returned ${response.statusCode} for "$packageName". Release '
        'history is read from pub.dev, so planning cannot continue without '
        'it.',
      );
    }

    final body =
        jsonDecode(await response.transform(utf8.decoder).join())
            as Map<String, dynamic>;
    return PublishedVersions(parsePubDevVersions(body));
  } on SocketException catch (e) {
    throw StateError(
      'Could not reach pub.dev to read release history for "$packageName" '
      '(${e.message}). Planning reads published versions from pub.dev and has '
      'no offline fallback.',
    );
  } finally {
    client.close();
  }
}

/// Pulls the version list out of a pub.dev `/api/packages/{name}` payload.
///
/// Split out from [fetchPublishedVersions] so the parsing is testable against
/// a captured payload without a network round-trip. Entries that don't parse
/// as semver are skipped rather than failing the run -- pub.dev won't serve
/// one, but a malformed entry shouldn't be able to block a release.
List<Version> parsePubDevVersions(Map<String, dynamic> body) {
  final entries = (body['versions'] as List?) ?? const [];
  final versions = <Version>[];
  for (final entry in entries) {
    final raw = (entry as Map<String, dynamic>)['version'];
    if (raw is! String) continue;
    try {
      versions.add(Version.parse(raw));
    } catch (_) {
      continue;
    }
  }
  return versions;
}
