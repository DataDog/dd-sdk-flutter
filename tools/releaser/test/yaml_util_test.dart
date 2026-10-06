// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:git/git.dart';
import 'package:logging/logging.dart';
import 'package:releaser/command.dart';
import 'package:releaser/yaml_util.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late Directory root;
  late File manifest;
  late File example;
  late CommandArguments args;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('flags-release-test-');
    final init = await Process.run('git', ['init', '--quiet', root.path]);
    expect(init.exitCode, 0);
    final package = Directory('${root.path}/packages/datadog_flags');
    await Directory('${package.path}/example').create(recursive: true);
    manifest = File('${package.path}/pubspec.yaml');
    await manifest.writeAsString(_manifest);
    example = File('${package.path}/example/pubspec.yaml');
    await example.writeAsString(_manifest.replaceFirst(
        'name: datadog_flags', 'name: datadog_flags_example'));
    args = CommandArguments(
      packages: [PackageRelease(name: 'datadog_flags', version: '1.2.0')],
      gitDir: await GitDir.fromExisting(root.path),
      skipGitChecks: true,
      skipChangelogCheck: true,
      iOSRelease: null,
      androidRelease: null,
      dryRun: false,
    );
  });

  tearDown(() async => root.delete(recursive: true));

  test('keeps the exact hosted contract SDK but removes local overrides',
      () async {
    expect(await RemoveDependencyOverridesCommand().run(args, Logger('test')),
        isTrue);
    final released = loadYaml(await manifest.readAsString()) as YamlMap;
    expect(released['dependency_overrides'],
        {'openfeature_dart_client_sdk': '0.0.1'});
    expect(released['flutter'], {'uses-material-design': true});
    expect(released['dependencies'], contains('openfeature_dart_client_sdk'));
    final releasedExample = loadYaml(await example.readAsString()) as YamlMap;
    expect(releasedExample.containsKey('dependency_overrides'), isFalse);
  });

  for (final replacement in [
    '0.0.1-beta.2',
    '0.0.2',
    '\n    path: ../sdk',
    '\n    git: https://example.org/sdk',
  ]) {
    test('does not preserve an unsafe or mismatched override: $replacement',
        () async {
      await manifest.writeAsString(_manifest.replaceFirst(
          'openfeature_dart_client_sdk: 0.0.1',
          'openfeature_dart_client_sdk: $replacement'));
      await RemoveDependencyOverridesCommand().run(args, Logger('test'));
      final released = loadYaml(await manifest.readAsString()) as YamlMap;
      expect(released.containsKey('dependency_overrides'), isFalse);
    });
  }

  test('does not keep overrides when the harness is absent', () async {
    await manifest.writeAsString(_manifest.replaceFirst(
        'openfeature_client_provider_contract:', 'other_test_dependency:'));
    await RemoveDependencyOverridesCommand().run(args, Logger('test'));
    final released = loadYaml(await manifest.readAsString()) as YamlMap;
    expect(released.containsKey('dependency_overrides'), isFalse);
  });
}

const _manifest = '''
name: datadog_flags
dependencies:
  openfeature_dart_client_sdk: ^0.0.1
dev_dependencies:
  openfeature_client_provider_contract:
    git: https://github.com/open-feature/dart-sdk.git
dependency_overrides:
  openfeature_dart_client_sdk: 0.0.1
  datadog_flutter_plugin:
    path: ../datadog_flutter_plugin
flutter:
  uses-material-design: true
''';
