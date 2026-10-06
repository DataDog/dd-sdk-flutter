// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'command.dart';
import 'helpers.dart';

class RemoveDependencyOverridesCommand extends Command {
  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    for (final package in args.packages) {
      final packageRoot = getPackageRoot(args, package);
      final pubspecFile = File(path.join(packageRoot, 'pubspec.yaml'));
      if (!pubspecFile.existsSync()) {
        logger.shout('⁉️ Could not find pubspec.yaml at ${pubspecFile.path}');
        return false;
      }

      await _removeDependencyOverrides(logger, pubspecFile, args.dryRun);
      final examplePubspec =
          File(path.join(packageRoot, 'example', 'pubspec.yaml'));
      if (await examplePubspec.exists()) {
        await _removeDependencyOverrides(logger, examplePubspec, args.dryRun);
      }
    }

    return true;
  }

  Future<void> _removeDependencyOverrides(
    Logger logger,
    File pubspecFile,
    bool dryRun,
  ) async {
    logger.info('🔀 Removing dependency_overrides from ${pubspecFile.path}');

    // The upstream contract harness depends on its SDK checkout. Keep only the
    // exact hosted version already required by datadog_flags so release tests
    // continue to exercise the published SDK. Consumers never inherit overrides.
    final manifest = loadYaml(await pubspecFile.readAsString()) as YamlMap;
    const sdk = 'openfeature_dart_client_sdk';
    final dependencies = manifest['dependencies'];
    final devDependencies = manifest['dev_dependencies'];
    final overrides = manifest['dependency_overrides'];
    final version = overrides is YamlMap ? overrides[sdk] : null;
    final preserveContractSdk = manifest['name'] == 'datadog_flags' &&
        devDependencies is YamlMap &&
        devDependencies.containsKey('openfeature_client_provider_contract') &&
        dependencies is YamlMap &&
        version is String &&
        RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) &&
        dependencies[sdk] == '^$version';

    var inDependencyOverrides = false;
    await transformFile(pubspecFile, logger, dryRun, (element) {
      if (inDependencyOverrides) {
        // If the line isn't empty and starts with characters, we're in a new section
        if (element.isNotEmpty && element.startsWith(RegExp(r'\S+'))) {
          logger.fine('Turning off dependency_overrides on line:\n$element');
          inDependencyOverrides = false;
        }
      } else if (element == 'dependency_overrides:') {
        inDependencyOverrides = true;
        if (preserveContractSdk) {
          return 'dependency_overrides:\n  $sdk: $version';
        }
      }

      return inDependencyOverrides ? null : element;
    });
  }
}
