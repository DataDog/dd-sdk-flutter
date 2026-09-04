// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:releaser/package_discovery.dart';
import 'support/fixture_repo.dart';

void main() {
  late FixtureRepo fixture;

  setUp(() async {
    fixture = await FixtureRepo.create();
  });

  tearDown(() => fixture.delete());

  test('excludes packages with publish_to: none', () async {
    final groups = await discoverPackages(fixture.root.path);
    final names = groups.expand((g) => g.members).map((pkg) => pkg.name);

    expect(names, isNot(contains('datadog_dio_example')));
    expect(names, isNot(contains('datadog_common_test')));
    expect(names, isNot(contains('datadog_flutter_plugin_ios_example')));
  });

  test('groups federated siblings in topological order', () async {
    final groups = await discoverPackages(fixture.root.path);
    final group = groups.firstWhere((g) => g.key == 'datadog_flutter_plugin');

    expect(group.isFederated, isTrue);
    expect(group.members.map((pkg) => pkg.name), [
      'datadog_flutter_plugin_platform_interface',
      'datadog_flutter_plugin_android',
      'datadog_flutter_plugin_desktop',
      'datadog_flutter_plugin_ios',
      'datadog_flutter_plugin_web',
      'datadog_flutter_plugin',
    ]);
    expect(group.members.map((pkg) => pkg.role), [
      PackageRole.platformInterface,
      PackageRole.implementation,
      PackageRole.implementation,
      PackageRole.implementation,
      PackageRole.implementation,
      PackageRole.appFacing,
    ]);
  });

  test('treats non-federated packages as singleton groups', () async {
    final groups = await discoverPackages(fixture.root.path);
    final group = groups.firstWhere((g) => g.key == 'datadog_dio');

    expect(group.isFederated, isFalse);
    expect(group.members.single.role, PackageRole.appFacing);
  });

  test(
    'every member carries its own group\'s key, even after flattening',
    () async {
      final groups = await discoverPackages(fixture.root.path);
      final byName = {
        for (final pkg in groups.expand((g) => g.members)) pkg.name: pkg,
      };

      expect(
        byName['datadog_flutter_plugin_ios']?.groupKey,
        'datadog_flutter_plugin',
      );
      expect(byName['datadog_dio']?.groupKey, 'datadog_dio');
    },
  );

  test(
    'a lone package with a federation-looking suffix is not misclassified as an implementation',
    () async {
      final groups = await discoverPackages(fixture.root.path);
      final group = groups.firstWhere((g) => g.key == 'lonely_ios');

      expect(group.isFederated, isFalse);
      expect(group.members.single.name, 'lonely_ios');
      expect(group.members.single.role, PackageRole.appFacing);
    },
  );

  test(
    'resolves each package to its real directory, not an assumed flat path',
    () async {
      final groups = await discoverPackages(fixture.root.path);
      final ios = groups
          .expand((g) => g.members)
          .firstWhere((pkg) => pkg.name == 'datadog_flutter_plugin_ios');

      expect(
        ios.relativePath,
        'packages/datadog_flutter_plugin/datadog_flutter_plugin_ios',
      );
    },
  );

  test(
    'a publishable package with no version in its pubspec is an error, not a silent 0.0.0',
    () async {
      final root = await Directory.systemTemp.createTemp('releaser_test_');
      addTearDown(() => root.delete(recursive: true));

      final packageDir = Directory(p.join(root.path, 'packages', 'no_version'))
        ..createSync(recursive: true);
      File(
        p.join(packageDir.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: no_version\nenvironment:\n  sdk: ^3.0.0\n');

      await expectLater(discoverPackages(root.path), throwsStateError);
    },
  );
}
