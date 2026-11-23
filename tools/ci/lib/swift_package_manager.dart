// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:io';

const _configSetting = 'enable-swift-package-manager';
const _environmentOverride = 'FLUTTER_SWIFT_PACKAGE_MANAGER';

/// Exits the process with an error unless Flutter's Swift Package Manager
/// support is explicitly enabled.
///
/// The Datadog plugins only ship Swift packages, so iOS and macOS builds fail
/// to link them when Flutter falls back to CocoaPods. An unset config value
/// is rejected because its default depends on the Flutter version.
Future<void> requireSwiftPackageManager() async {
  if (Platform.environment[_environmentOverride] case final value?) {
    if (value == 'true') return;
    _fail('$_environmentOverride is set to "$value".');
  }

  final result = await Process.run('flutter', ['config', '--list']);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    _fail('`flutter config --list` exited with ${result.exitCode}.');
  }
  final enabled = (result.stdout as String)
      .split('\n')
      .any((line) => line.trim() == '$_configSetting: true');
  if (!enabled) _fail('`$_configSetting` is not set to true.');
}

Never _fail(String reason) {
  stderr.writeln(
    '❌ Swift Package Manager must be enabled for iOS and macOS builds. '
    '$reason\n'
    'Run `flutter config --enable-swift-package-manager`.',
  );
  exit(1);
}
