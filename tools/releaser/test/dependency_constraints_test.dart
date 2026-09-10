// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:releaser/dependency_constraints.dart';
import 'package:releaser/package_discovery.dart';

void main() {
  late Directory root;
  final logger = Logger('dependency_constraints_test');

  setUp(() async {
    root = await Directory.systemTemp.createTemp(
      'dependency_constraints_test_',
    );
  });

  tearDown(() => root.delete(recursive: true));

  group('bumpDependentConstraint', () {
    test('raises a simple caret constraint', () async {
      final file = File(p.join(root.path, 'pubspec.yaml'))
        ..writeAsStringSync(
          'name: datadog_flutter_plugin\n'
          'dependencies:\n'
          '  datadog_flutter_plugin_android: ^1.0.0\n'
          '  datadog_flutter_plugin_ios: ^1.0.0\n',
        );

      await bumpDependentConstraint(
        file,
        'datadog_flutter_plugin_android',
        '1.1.0',
        logger,
        false,
      );

      final contents = file.readAsStringSync();
      expect(contents, contains('datadog_flutter_plugin_android: ^1.1.0'));
      // Unrelated sibling constraint left alone.
      expect(contents, contains('datadog_flutter_plugin_ios: ^1.0.0'));
    });

    test('is a no-op when the dependency is not a simple constraint', () async {
      final original =
          'name: datadog_dio\n'
          'dependencies:\n'
          '  datadog_flutter_plugin:\n'
          '    path: ../datadog_flutter_plugin\n';
      final file = File(p.join(root.path, 'pubspec.yaml'))
        ..writeAsStringSync(original);

      await bumpDependentConstraint(
        file,
        'datadog_flutter_plugin',
        '5.0.0',
        logger,
        false,
      );

      expect(file.readAsStringSync(), original);
    });
  });

  group('findStaleConsumerWarnings', () {
    DiscoveredPackage pkg(
      String name, {
      required String relativePath,
      required String groupKey,
      PackageRole role = PackageRole.appFacing,
    }) => DiscoveredPackage(
      name: name,
      version: '1.0.0',
      relativePath: relativePath,
      role: role,
      groupKey: groupKey,
    );

    test('flags a consumer whose constraint excludes the new major', () async {
      final flutterPlugin = pkg(
        'datadog_flutter_plugin',
        relativePath: 'packages/datadog_flutter_plugin/datadog_flutter_plugin',
        groupKey: 'datadog_flutter_plugin',
      );
      final webview = pkg(
        'datadog_webview_tracking',
        relativePath: 'packages/datadog_webview_tracking',
        groupKey: 'datadog_webview_tracking',
      );

      Directory(
        p.join(root.path, webview.relativePath),
      ).createSync(recursive: true);
      File(
        p.join(root.path, webview.relativePath, 'pubspec.yaml'),
      ).writeAsStringSync(
        'name: datadog_webview_tracking\n'
        'dependencies:\n'
        '  datadog_flutter_plugin: ">=3.0.0 <5.0.0"\n',
      );

      final warnings = await findStaleConsumerWarnings(
        allGroups: [
          PackageGroup(key: flutterPlugin.groupKey, members: [flutterPlugin]),
          PackageGroup(key: webview.groupKey, members: [webview]),
        ],
        repoRoot: root.path,
        releasingPackage: flutterPlugin,
        newVersion: '5.0.0',
      );

      expect(warnings, hasLength(1));
      expect(warnings.single.consumerPackage, 'datadog_webview_tracking');
      expect(warnings.single.constraint, '>=3.0.0 <5.0.0');
    });

    test('does not flag a consumer whose constraint still allows it', () async {
      final flutterPlugin = pkg(
        'datadog_flutter_plugin',
        relativePath: 'packages/datadog_flutter_plugin/datadog_flutter_plugin',
        groupKey: 'datadog_flutter_plugin',
      );
      final webview = pkg(
        'datadog_webview_tracking',
        relativePath: 'packages/datadog_webview_tracking',
        groupKey: 'datadog_webview_tracking',
      );

      Directory(
        p.join(root.path, webview.relativePath),
      ).createSync(recursive: true);
      File(
        p.join(root.path, webview.relativePath, 'pubspec.yaml'),
      ).writeAsStringSync(
        'name: datadog_webview_tracking\n'
        'dependencies:\n'
        '  datadog_flutter_plugin: ">=3.0.0 <5.0.0"\n',
      );

      final warnings = await findStaleConsumerWarnings(
        allGroups: [
          PackageGroup(key: flutterPlugin.groupKey, members: [flutterPlugin]),
          PackageGroup(key: webview.groupKey, members: [webview]),
        ],
        repoRoot: root.path,
        releasingPackage: flutterPlugin,
        newVersion: '4.2.0',
      );

      expect(warnings, isEmpty);
    });

    test('never flags a member of the releasing package\'s own group', () async {
      final platformInterface = pkg(
        'datadog_flutter_plugin_platform_interface',
        relativePath:
            'packages/datadog_flutter_plugin/datadog_flutter_plugin_platform_interface',
        groupKey: 'datadog_flutter_plugin',
        role: PackageRole.platformInterface,
      );
      final appFacing = pkg(
        'datadog_flutter_plugin',
        relativePath: 'packages/datadog_flutter_plugin/datadog_flutter_plugin',
        groupKey: 'datadog_flutter_plugin',
      );

      Directory(
        p.join(root.path, appFacing.relativePath),
      ).createSync(recursive: true);
      File(
        p.join(root.path, appFacing.relativePath, 'pubspec.yaml'),
      ).writeAsStringSync(
        'name: datadog_flutter_plugin\n'
        'dependencies:\n'
        '  datadog_flutter_plugin_platform_interface: ^1.0.0\n',
      );

      final warnings = await findStaleConsumerWarnings(
        allGroups: [
          PackageGroup(
            key: 'datadog_flutter_plugin',
            members: [platformInterface, appFacing],
          ),
        ],
        repoRoot: root.path,
        releasingPackage: platformInterface,
        newVersion: '2.0.0',
      );

      expect(warnings, isEmpty);
    });
  });
}
