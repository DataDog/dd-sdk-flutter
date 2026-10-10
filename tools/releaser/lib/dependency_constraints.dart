// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:pub_semver/pub_semver.dart' as semver;
import 'package:yaml/yaml.dart';

import 'helpers.dart';
import 'package_discovery.dart';

/// Matches one dependency line naming [name] with a simple version
/// constraint value -- `name: ^1.0.0`, `name: ">=1.0.0 <2.0.0"`, or
/// `name: '1.0.0'`. Doesn't match a nested-map dependency (`name:` with
/// `path:`/`sdk:` on following lines), which this tooling never rewrites.
RegExp _dependencyLinePattern(String name) => RegExp(
  '^(?<indent>\\s+)${RegExp.escape(name)}:\\s*'
  '(?<quote>["\']?)(?<constraint>[^"\'\\s][^"\']*?)(?<endquote>["\']?)\\s*\$',
);

/// Matches an unindented top-level YAML key (`dependencies:`,
/// `dev_dependencies:`, `dependency_overrides:`, `environment:`, ...),
/// tracked while scanning so a dependency of the same name under a
/// different section (a `dev_dependencies` entry, say) is never mistaken
/// for the real one in `dependencies:`.
final _topLevelKeyPattern = RegExp(r'^(?<key>[A-Za-z_][A-Za-z0-9_]*):');

/// Rewrites [pubspecFile]'s dependency line for [dependencyName] to a
/// caret constraint on [newVersion] -- used to raise a federated
/// app-facing package's lower bound on a sibling (platform interface or
/// implementation) that's releasing this cycle. Leaves the line alone if
/// [dependencyName] isn't a simple version-constraint dependency under
/// `dependencies:` there (e.g. a `path:`-based one, which this repo
/// doesn't use for a federated sibling, one only present under
/// `dev_dependencies:`/`dependency_overrides:`, or simply absent).
Future<void> bumpDependentConstraint(
  File pubspecFile,
  String dependencyName,
  String newVersion,
  Logger logger,
  bool dryRun,
) async {
  final pattern = _dependencyLinePattern(dependencyName);
  var found = false;
  String? currentTopLevelKey;

  await transformFile(pubspecFile, logger, dryRun, (line) {
    final topLevelMatch = _topLevelKeyPattern.firstMatch(line);
    if (topLevelMatch != null) {
      currentTopLevelKey = topLevelMatch.namedGroup('key');
      return line;
    }
    if (currentTopLevelKey != 'dependencies') return line;

    final match = pattern.firstMatch(line);
    if (match == null) return line;
    found = true;
    logger.info(
      'ℹ️ Raising $dependencyName lower bound to ^$newVersion in '
      '${pubspecFile.path}',
    );
    return '${match.namedGroup('indent')}$dependencyName: ^$newVersion';
  });

  if (!found) {
    logger.fine(
      'No simple version-constraint dependency on $dependencyName found '
      'under dependencies: in ${pubspecFile.path} -- nothing to bump.',
    );
  }
}

/// A non-federated package's stale constraint on a package that's
/// releasing this cycle -- reported so a human can decide whether that
/// consumer also needs a release. Never bumped automatically.
class StaleConsumerWarning {
  final String consumerPackage;
  final String dependencyName;
  final String constraint;
  final String newVersion;

  StaleConsumerWarning({
    required this.consumerPackage,
    required this.dependencyName,
    required this.constraint,
    required this.newVersion,
  });

  @override
  String toString() =>
      '$consumerPackage depends on $dependencyName $constraint, which does '
      'not allow the new $newVersion -- consider releasing $consumerPackage '
      'too.';
}

/// Every package outside [releasingPackage]'s own federated group whose
/// pubspec.yaml constrains it in a way [newVersion] doesn't satisfy.
/// Federated siblings are excluded here -- their lower bound is raised
/// directly by [bumpDependentConstraint], not merely flagged.
Future<List<StaleConsumerWarning>> findStaleConsumerWarnings({
  required List<PackageGroup> allGroups,
  required String repoRoot,
  required DiscoveredPackage releasingPackage,
  required String newVersion,
}) async {
  final target = semver.Version.parse(newVersion);
  final warnings = <StaleConsumerWarning>[];

  for (final group in allGroups) {
    if (group.key == releasingPackage.groupKey) continue;

    for (final consumer in group.members) {
      final pubspecFile = File(
        '${consumer.absolutePath(repoRoot)}/pubspec.yaml',
      );
      if (!pubspecFile.existsSync()) continue;

      final pubspec = loadYaml(await pubspecFile.readAsString());
      if (pubspec is! YamlMap) continue;
      final dependencies = pubspec['dependencies'];
      if (dependencies is! YamlMap) continue;

      final value = dependencies[releasingPackage.name];
      // Not a simple constraint: absent, or a nested `path:`/`sdk:` map.
      if (value is! String) continue;

      final rawConstraint = value.trim();
      semver.VersionConstraint constraint;
      try {
        constraint = semver.VersionConstraint.parse(rawConstraint);
      } on FormatException {
        continue; // Not a constraint this tooling knows how to parse.
      }

      if (!constraint.allows(target)) {
        warnings.add(
          StaleConsumerWarning(
            consumerPackage: consumer.name,
            dependencyName: releasingPackage.name,
            constraint: rawConstraint,
            newVersion: newVersion,
          ),
        );
      }
    }
  }

  return warnings;
}
