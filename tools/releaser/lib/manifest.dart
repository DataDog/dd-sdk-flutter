// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// One package's entry in a [ReleaseManifest] -- what Phase 2 needs to
/// publish, tag, and release it, without diffing anything.
class ManifestPackageEntry {
  final String package;
  final String fromVersion;
  final String toVersion;
  final String sourceBranch;
  final bool prerelease;

  ManifestPackageEntry({
    required this.package,
    required this.fromVersion,
    required this.toVersion,
    required this.sourceBranch,
    required this.prerelease,
  });

  factory ManifestPackageEntry.fromJson(Map<String, dynamic> json) =>
      ManifestPackageEntry(
        package: json['package'] as String,
        fromVersion: json['from_version'] as String,
        toVersion: json['to_version'] as String,
        sourceBranch: json['source_branch'] as String,
        prerelease: json['prerelease'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'package': package,
    'from_version': fromVersion,
    'to_version': toVersion,
    'source_branch': sourceBranch,
    'prerelease': prerelease,
  };
}

/// The canonical record of what one `prepare_release.dart` run did, written
/// to `.release/manifest.json` as part of the publish-prep commit (commit
/// B). Phase 2 reads this instead of diffing, and reads [contentCommit] to
/// know exactly what to cherry-pick when it backports the content commit
/// into the dev-line branch afterwards.
///
/// Deliberately confined to the disposable `main`/`{effort}-main` lines:
/// nothing here is ever backported, so it never needs to be merged with
/// anything and never accumulates across branches.
class ReleaseManifest {
  /// Commit A's SHA (mainline/pre-release), safe to cherry-pick into the
  /// dev-line branch. `null` on a patch trigger -- patch doesn't split
  /// commits, so there is no commit here that's safe to backport that way;
  /// Phase 2 uses `changelog_backport.dart` for patch instead, and reads
  /// this field being `null` as the enforced signal not to cherry-pick.
  final String? contentCommit;
  final List<ManifestPackageEntry> packages;

  ReleaseManifest({required this.contentCommit, required this.packages});

  factory ReleaseManifest.fromJson(Map<String, dynamic> json) =>
      ReleaseManifest(
        contentCommit: json['contentCommit'] as String?,
        packages: (json['packages'] as List)
            .map(
              (e) => ManifestPackageEntry.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'contentCommit': contentCommit,
    'packages': packages.map((e) => e.toJson()).toList(),
  };

  String toJsonString() =>
      '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';

  static ReleaseManifest fromJsonString(String contents) =>
      ReleaseManifest.fromJson(jsonDecode(contents) as Map<String, dynamic>);
}

/// Path to the manifest file, relative to [repoRoot].
String manifestPath(String repoRoot) =>
    p.join(repoRoot, '.release', 'manifest.json');

Future<void> writeManifest(String repoRoot, ReleaseManifest manifest) async {
  final file = File(manifestPath(repoRoot));
  await file.parent.create(recursive: true);
  await file.writeAsString(manifest.toJsonString());
}

Future<ReleaseManifest> readManifest(String repoRoot) async {
  final file = File(manifestPath(repoRoot));
  return ReleaseManifest.fromJsonString(await file.readAsString());
}
