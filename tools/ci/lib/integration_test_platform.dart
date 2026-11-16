// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:ci_helpers/android_helpers.dart';
import 'package:ci_helpers/ios_helpers.dart';

/// A platform that integration tests run on with `flutter test -d <device>`.
enum TestPlatform {
  ios(device: 'iPhone', recoverDevice: rebootBootedIosSimulators),
  android(device: 'emulator', recoverDevice: rebootAndroidEmulators),
  macos(device: 'macos', beforeEachFile: _deleteStaleDatadogData),
  linux(device: 'linux', beforeEachFile: _deleteStaleDatadogData),
  windows(device: 'windows', beforeEachFile: _deleteStaleDatadogData);

  const TestPlatform({
    required this.device,
    this.recoverDevice,
    this.beforeEachFile,
  });

  /// The `flutter test -d` device id.
  final String device;

  /// Restores the device after a failed app launch. Platforms without one are
  /// not retried.
  final Future<void> Function()? recoverDevice;

  /// Runs before each test file.
  final void Function()? beforeEachFile;

  /// `flutter build` arguments that compile the app for this platform, or
  /// `null` when no separate build is needed before the first test.
  List<String>? get warmUpBuildArgs => switch (this) {
    ios => const ['build', 'ios', '--simulator', '--debug'],
    android => const ['build', 'apk', '--debug'],
    macos || linux || windows => null,
  };

  /// Test files that don't run on this platform.
  List<String> get excludedFiles => switch (this) {
    macos || linux || windows => const ['configuration_telemetry_test.dart'],
    ios => const [],
    // Registers no tests on Android (flutter_inappwebview bug #1973), which
    // makes `flutter test` exit non-zero when it runs alone.
    android => const ['inappbrowser_integration_test.dart'],
  };

  /// The desktop platform of the host machine.
  static TestPlatform get host {
    if (Platform.isMacOS) return macos;
    if (Platform.isLinux) return linux;
    if (Platform.isWindows) return windows;
    throw UnsupportedError(
      'Unsupported desktop platform: ${Platform.operatingSystem}',
    );
  }
}

// Must match the application name the integration app passes to
// DatadogConfiguration.getSuggestedDesktopDataDirectory.
const _dataStorageApplicationName = 'com.datadoghq.flutter.integration';

// Mirrors DatadogConfiguration.getSuggestedDesktopDataDirectory in
// datadog_flutter_plugin.
Directory _dataStorageDirectory() {
  if (Platform.isWindows) {
    final base = Platform.environment['LOCALAPPDATA'] ?? '.';
    return Directory('$base\\$_dataStorageApplicationName');
  }
  final xdgDataHome = Platform.environment['XDG_DATA_HOME'];
  if (xdgDataHome != null && xdgDataHome.isNotEmpty) {
    return Directory('$xdgDataHome/$_dataStorageApplicationName');
  }
  final home = Platform.environment['HOME'] ?? '.';
  return Directory('$home/.local/share/$_dataStorageApplicationName');
}

// The C SDK's on-disk storage persists across app runs so it can recover
// from an abandoned process. That means a previous test file's session/batch
// data can otherwise leak into the next test file's run.
//
// Apps that set an explicit data directory store data in
// `_dataStorageDirectory()`; apps that don't fall back to `.datadog/` in the
// current working directory (the package's example directory).
void _deleteStaleDatadogData() {
  for (final dir in [_dataStorageDirectory(), Directory('.datadog')]) {
    if (!dir.existsSync()) continue;
    try {
      dir.deleteSync(recursive: true);
    } catch (e) {
      // A previous test's process may not have released its file handles yet,
      // which could mean it outlived `flutter test`. Fail loudly.
      print('WARNING: failed to delete $dir: $e');
      rethrow;
    }
  }
}
