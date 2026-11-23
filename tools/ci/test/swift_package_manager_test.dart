// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:ci_helpers/swift_package_manager.dart';
import 'package:test/test.dart';

void main() {
  String configList(String value) =>
      'All Settings:\n'
      '  enable-web: (Not set)\n'
      '  enable-swift-package-manager: $value\n';

  String pubspec(bool value) =>
      'name: app\n'
      'flutter:\n'
      '  config:\n'
      '    enable-swift-package-manager: $value\n';

  final cases = [
    (
      name: 'global true',
      environment: <String, String>{},
      config: configList('true'),
      pubspec: null,
      enabled: true,
    ),
    (
      name: 'global false',
      environment: <String, String>{},
      config: configList('false'),
      pubspec: null,
      enabled: false,
    ),
    (
      name: 'nothing set',
      environment: <String, String>{},
      config: configList('(Not set)'),
      pubspec: null,
      enabled: false,
    ),
    (
      name: 'pubspec true beats global false',
      environment: <String, String>{},
      config: configList('false'),
      pubspec: pubspec(true),
      enabled: true,
    ),
    (
      name: 'pubspec false beats global true',
      environment: <String, String>{},
      config: configList('true'),
      pubspec: pubspec(false),
      enabled: false,
    ),
    (
      name: 'global false beats environment true',
      environment: {'FLUTTER_SWIFT_PACKAGE_MANAGER': 'true'},
      config: configList('false'),
      pubspec: null,
      enabled: false,
    ),
    (
      name: 'environment true applies when config is unset',
      environment: {'FLUTTER_SWIFT_PACKAGE_MANAGER': 'true'},
      config: configList('(Not set)'),
      pubspec: null,
      enabled: true,
    ),
    (
      name: 'environment value is case-insensitive',
      environment: {'FLUTTER_SWIFT_PACKAGE_MANAGER': 'TRUE'},
      config: configList('(Not set)'),
      pubspec: null,
      enabled: true,
    ),
    (
      name: 'environment value other than true disables',
      environment: {'FLUTTER_SWIFT_PACKAGE_MANAGER': 'yes'},
      config: configList('(Not set)'),
      pubspec: null,
      enabled: false,
    ),
    (
      name: 'pubspec without a config section falls through',
      environment: <String, String>{},
      config: configList('true'),
      pubspec: 'name: app\nflutter:\n  uses-material-design: true\n',
      enabled: true,
    ),
  ];

  for (final c in cases) {
    test(c.name, () {
      final problem = swiftPackageManagerProblem(
        environment: c.environment,
        configList: c.config,
        pubspecContent: c.pubspec,
      );
      expect(problem, c.enabled ? isNull : isNotNull);
    });
  }
}
