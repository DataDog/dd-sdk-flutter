// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

const _configSetting = 'enable-swift-package-manager';
const _environmentOverride = 'FLUTTER_SWIFT_PACKAGE_MANAGER';

/// Why Flutter's Swift Package Manager support is not enabled for an app, or
/// null when it is.
///
/// Resolves the setting in the same order as the Flutter tool: the app's
/// `pubspec.yaml` (`flutter: config:`), then the global config
/// ([configList] is the output of `flutter config --list`), then the
/// `FLUTTER_SWIFT_PACKAGE_MANAGER` environment variable. A setting left unset
/// everywhere is a problem, because its default depends on the Flutter
/// version.
String? swiftPackageManagerProblem({
  required Map<String, String> environment,
  required String configList,
  String? pubspecContent,
}) {
  final pubspec = _pubspecSetting(pubspecContent);
  final global = _globalSetting(configList);
  final env = environment[_environmentOverride];
  final (bool? enabled, String? source) = pubspec != null
      ? (pubspec, 'the app pubspec.yaml')
      : global != null
      ? (global, 'the global Flutter config')
      : env != null
      ? (env.toLowerCase() == 'true', _environmentOverride)
      : (null, null);
  return switch (enabled) {
    true => null,
    false => '`$_configSetting` is disabled by $source.',
    null => '`$_configSetting` is not set.',
  };
}

bool? _pubspecSetting(String? pubspecContent) {
  if (pubspecContent == null) return null;
  if (loadYaml(pubspecContent) case {
    'flutter': {'config': {_configSetting: final bool value}},
  }) {
    return value;
  }
  return null;
}

bool? _globalSetting(String configList) {
  for (final line in configList.split('\n')) {
    if (line.trim().split(': ') case [_configSetting, final value]) {
      return bool.tryParse(value);
    }
  }
  return null;
}

/// Exits the process with an error unless Swift Package Manager is enabled
/// for every app in [appDirectories], or globally when none are given.
///
/// The Datadog plugins only ship Swift packages, so iOS and macOS builds fail
/// to link them when Flutter falls back to CocoaPods.
Future<void> requireSwiftPackageManager([
  Iterable<String> appDirectories = const [],
]) async {
  final result = await Process.run('flutter', ['config', '--list']);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    _fail('`flutter config --list` exited with ${result.exitCode}.');
  }
  final configList = result.stdout as String;

  final List<String?> apps = appDirectories.isEmpty
      ? [null]
      : [...appDirectories];
  final problems = [
    for (final app in apps)
      if (swiftPackageManagerProblem(
            environment: Platform.environment,
            configList: configList,
            pubspecContent: switch (app) {
              final String dir => _readPubspec(dir),
              null => null,
            },
          )
          case final problem?)
        app == null ? problem : '$app: $problem',
  ];
  if (problems.isNotEmpty) _fail(problems.join('\n'));
}

String? _readPubspec(String appDirectory) {
  final file = File(path.join(appDirectory, 'pubspec.yaml'));
  return file.existsSync() ? file.readAsStringSync() : null;
}

Never _fail(String reason) {
  stderr.writeln(
    '❌ Swift Package Manager must be enabled for iOS and macOS builds.\n'
    '$reason\n'
    'Run `flutter config --enable-swift-package-manager`.',
  );
  exit(1);
}
