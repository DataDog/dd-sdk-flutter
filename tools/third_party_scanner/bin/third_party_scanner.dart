// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:pana/pana.dart';
import 'package:pana/src/license.dart';

// From the root of this project
final root = '../..';
final projectList = [
  '$root/packages/datadog_common_test',
  '$root/packages/datadog_flutter_plugin',
  '$root/packages/datadog_flutter_plugin/example',
  '$root/packages/datadog_flutter_plugin/e2e_test_app',
  '$root/packages/datadog_flutter_plugin/integration_test_app',
  '$root/packages/datadog_grpc_interceptor',
  '$root/tools/e2e_generator',
  '$root/tools/releaser',
  '$root/tools/third_party_scanner',
];
// Packages that are safe to ignore and not write to the 3rd party csv
// Usually, only packages that are contained within this repo
final ignorePackages = [
  "datadog_flutter_plugin",
];

enum DependencyType { import, test, build, unknown }

DependencyType _dependencyTypeFromString(String type) {
  return DependencyType.values
      .firstWhere((e) => e.name == type, orElse: () => DependencyType.unknown);
}

class Dependency {
  DependencyType type;
  String name;
  String? license;
  String copyright;

  Dependency({
    this.type = DependencyType.unknown,
    required this.name,
    this.license,
    this.copyright = "unknown",
  });

  @override
  String toString() {
    return '${type.name},$name,$license,$copyright';
  }
}

Future<int> main(List<String> arguments) async {
  final dartDependencies = await _getDartDependencies();
  final existingDependencies = await _getExistingDependencies();

  final dependencies = Map<String, Dependency?>.from(existingDependencies);
  int newDependencyCount = 0;
  for (final dartDependency in dartDependencies.entries) {
    if (!ignorePackages.contains(dartDependency.key) &&
        !existingDependencies.containsKey(dartDependency.key)) {
      dependencies[dartDependency.key] = dartDependency.value;
      newDependencyCount++;
    }
  }

  print('');
  print('✏️ Writing $root/LICENSE-3rdparty.csv');

  final csvFile = File('$root/LICENSE-3rdparty.csv');
  final sink = csvFile.openWrite();
  sink.writeln("Component,Origin,License,Copyright");
  for (var dependency in dependencies.values) {
    sink.writeln(dependency.toString());
  }
  sink.close();
  print('✅ All Done! Wrote $newDependencyCount new dependencies!');

  return newDependencyCount;
}

Future<Map<String, Dependency?>> _getExistingDependencies() async {
  final packageMap = <String, Dependency?>{};

  print('ℹ️ Getting existing dependency list...');
  final csvFile = File('$root/LICENSE-3rdparty.csv');
  if (!csvFile.existsSync()) {
    print('❌ Could not find existing LICENSE-3rdparty.csv!');
    return packageMap;
  }

  var lines = await csvFile.readAsLines();
  bool isFirstLine = true;
  for (var line in lines) {
    if (isFirstLine) {
      // Skip the heading line
      isFirstLine = false;
      continue;
    }
    final items = _parseCsvLine(line);
    final type = _dependencyTypeFromString(items[0]);
    final dependency = Dependency(
        type: type, name: items[1], license: items[2], copyright: items[3]);
    packageMap[dependency.name] = dependency;
  }

  return packageMap;
}

Future<Map<String, Dependency?>> _getDartDependencies() async {
  final packageMap = <String, Dependency?>{};

  print('ℹ️ Getting dart dependencies...');
  for (var project in projectList) {
    print('ℹ️ Checking "$project" ...');

    final pubspecFile = File('$project/pubspec.yaml');

    if (!pubspecFile.existsSync()) {
      print('⚠️ Could not find pubspec.yaml for "$project"');
      continue;
    }

    final packageConfigFile = File('$project/.dart_tool/package_config.json');

    if (!pubspecFile.existsSync()) {
      stderr.writeln(
          '❌ $project/.dart_tool/package_config.json file not found. You may need to run "pub get" on this tool');
      continue;
    }

    final packageConfig = json.decode(packageConfigFile.readAsStringSync())
        as Map<String, Object?>;
    final pubspec = Pubspec.parseYaml(pubspecFile.readAsStringSync());

    print('ℹ️ Getting dependencies for $project');

    for (final package in packageConfig['packages'] as List) {
      final name = package['name'] as String;
      final dependency = await _getDependencyFor(name, pubspec, package);
      if (dependency != null) {
        if (!packageMap.containsKey(name)) {
          packageMap[name] = dependency;
        } else if (dependency.type.index < packageMap[name]!.type.index) {
          packageMap[name] = dependency;
        }
      }
    }
  }

  return packageMap;
}

Future<Dependency?> _getDependencyFor(
    String name, Pubspec pubspec, Map<String, Object?> package) async {
  final dependency = Dependency(name: name);
  if (pubspec.dependencies.containsKey(name)) {
    dependency.type = DependencyType.import;
  } else if (pubspec.devDependencies.containsKey(name)) {
    if (name.contains('_test')) {
      dependency.type = DependencyType.test;
    } else {
      dependency.type = DependencyType.build;
    }
  } else {
    return null;
  }

  var rootUri = package['rootUri'] as String;
  if (rootUri.startsWith('file://')) {
    rootUri = rootUri.substring(7);
  }

  final licenses = await detectLicenseInDir(rootUri);
  if (licenses.isEmpty) {
    print('⚠️ Could not detect license for $name');
  } else {
    if (licenses.length > 1) {
      print(
          '⚠️ Package $name may have more than one license. Using the first.');
    }
    dependency.license = licenses.first.spdxIdentifier;
  }

  return dependency;
}

List<String> _parseCsvLine(String line) {
  final items = <String>[];
  final item = StringBuffer();
  bool inString = false;
  for (var c in line.runes) {
    final strRune = String.fromCharCode(c);
    if (strRune == ',' && !inString) {
      items.add(item.toString());
      item.clear();
    } else {
      if (strRune == '"') {
        inString = !inString;
      }
      item.write(strRune);
    }
  }
  items.add(item.toString());

  return items;
}
