// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';

/// Suffix a federated package's platform-interface uses. Within a group,
/// this one always releases first.
const platformInterfaceSuffix = '_platform_interface';

/// Suffixes of federated per-platform implementation packages. Within a
/// group these are independent of each other -- any relative order among
/// them is fine.
const implementationSuffixes = ['_android', '_ios', '_web', '_desktop'];

enum PackageRole {
  platformInterface(publishOrder: 0),
  implementation(publishOrder: 1),
  // The terminal node in a group's publish order -- the package everything
  // else in its group (if any) is a dependency of. A standalone package is
  // trivially its own terminal node, so this covers both a federated
  // group's app-facing package and any singleton.
  appFacing(publishOrder: 2);

  /// Where this role publishes relative to its siblings within the same
  /// group (lower publishes first). Platform interface before
  /// implementations before the app-facing package, since each depends on
  /// the one(s) before it.
  final int publishOrder;

  const PackageRole({required this.publishOrder});
}

class DiscoveredPackage {
  final String name;
  final String version;

  /// Path to the package's directory, relative to the repo root -- e.g.
  /// `packages/datadog_flutter_plugin/datadog_flutter_plugin_ios`. Resolved
  /// from where its pubspec.yaml actually lives, not assumed from its name.
  final String relativePath;
  final PackageRole role;

  DiscoveredPackage({
    required this.name,
    required this.version,
    required this.relativePath,
    required this.role,
  });

  String absolutePath(String repoRoot) => p.join(repoRoot, relativePath);

  @override
  String toString() => '$name@$version ($relativePath, $role)';
}

/// A set of packages that release together. Federated groups (platform
/// interface + per-platform impls + app-facing package) have more than one
/// member, listed in topological order (interface, then impls, then
/// app-facing). Everything else is a singleton group of exactly one.
class PackageGroup {
  final String key;
  final List<DiscoveredPackage> members;

  PackageGroup({required this.key, required this.members});

  bool get isFederated => members.length > 1;
}

/// Discovers every releasable package under `[repoRoot]/packages`, grouping
/// federated siblings together in topological order. Resolves each
/// package's actual directory by walking the tree, since federated
/// sub-packages don't live at a flat `packages/{name}` path.
///
/// Packages with `publish_to: none` (example apps, integration/e2e test
/// harnesses, and deliberately-unpublished support packages like
/// `datadog_common_test`) are excluded; they're never part of a release.
Future<List<PackageGroup>> discoverPackages(String repoRoot) async {
  final pubspecGlob = Glob('packages/**/pubspec.yaml');
  final packages = <DiscoveredPackage>[];

  for (final entity in pubspecGlob.listSync(
    root: repoRoot,
    followLinks: false,
  )) {
    if (entity is! File) continue;
    final pubspecFile = entity as File;

    final pubspec = Pubspec.parse(
      await pubspecFile.readAsString(),
      sourceUrl: pubspecFile.uri,
    );

    if (pubspec.publishTo == 'none') continue;

    if (pubspec.version == null) {
      throw StateError(
        'Package "${pubspec.name}" (${pubspecFile.path}) has no version in '
        'its pubspec.yaml -- every releasable package must declare one.',
      );
    }

    final relativePath = p.dirname(
      p.relative(pubspecFile.path, from: repoRoot),
    );
    packages.add(
      DiscoveredPackage(
        name: pubspec.name,
        version: pubspec.version.toString(),
        relativePath: relativePath,
        // Corrected below once every package's group is known.
        role: PackageRole.appFacing,
      ),
    );
  }

  return _groupPackages(packages);
}

/// Groups packages by their shared parent directory -- packages nested
/// under a common container dir (e.g. everything under
/// `packages/datadog_flutter_plugin/`) are a federated group; packages
/// sitting directly under `packages/` are standalone.
List<PackageGroup> _groupPackages(List<DiscoveredPackage> packages) {
  final byContainerDir = <String, List<DiscoveredPackage>>{};
  for (final pkg in packages) {
    final containerDir = p.dirname(pkg.relativePath);
    // Two packages both living directly under packages/ aren't siblings
    // just because they share that top-level directory -- key each of
    // them by their own path so they don't get grouped together.
    final key = containerDir == 'packages' ? pkg.relativePath : containerDir;
    byContainerDir.putIfAbsent(key, () => []).add(pkg);
  }

  final groups = <PackageGroup>[];
  byContainerDir.forEach((containerDir, members) {
    if (members.length == 1) {
      // Deliberately not run through `_roleFor` -- a standalone package's
      // name might coincidentally end in a federation suffix (see
      // `lonely_ios` in the tests), but with no siblings it's still just
      // the terminal node of its own one-package group.
      final pkg = members.single;
      groups.add(
        PackageGroup(
          key: pkg.name,
          members: [_withRole(pkg, PackageRole.appFacing)],
        ),
      );
      return;
    }

    final roled =
        members.map((pkg) => _withRole(pkg, _roleFor(pkg.name))).toList()
          ..sort((a, b) {
            final byOrder = a.role.publishOrder.compareTo(b.role.publishOrder);
            return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
          });

    groups.add(PackageGroup(key: p.basename(containerDir), members: roled));
  });

  return groups;
}

/// Classifies a package's role *within* a group already formed by shared
/// directory -- this is ordering info only, not what decides grouping.
PackageRole _roleFor(String name) {
  if (name.endsWith(platformInterfaceSuffix)) {
    return PackageRole.platformInterface;
  }
  if (implementationSuffixes.any(name.endsWith)) {
    return PackageRole.implementation;
  }
  return PackageRole.appFacing;
}

DiscoveredPackage _withRole(DiscoveredPackage pkg, PackageRole role) =>
    DiscoveredPackage(
      name: pkg.name,
      version: pkg.version,
      relativePath: pkg.relativePath,
      role: role,
    );
