// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ci_helpers/shell_helpers.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;

const avdTag = 'google_apis';

/// The system image ABI that matches the host, so the emulator can use
/// hardware acceleration.
final avdAbi = switch (Abi.current()) {
  Abi.macosArm64 || Abi.linuxArm64 || Abi.windowsArm64 => 'arm64-v8a',
  _ => 'x86_64',
};

final yesList = List.filled(10, 'yes\n');
final noList = List.filled(10, 'no\n');

String get androidHome {
  final androidHome = Platform.environment['ANDROID_HOME'];
  if (androidHome == null) {
    throw Exception(
        'ANDROID_HOME is not set when trying to launch Android emulator.');
  }
  return androidHome;
}

String get avdManager {
  final androidCmdToolsPath =
      path.join(androidHome, 'cmdline-tools/latest/bin');
  return path.join(androidCmdToolsPath, 'avdmanager');
}

String get sdkManager {
  final androidCmdToolsPath =
      path.join(androidHome, 'cmdline-tools/latest/bin');
  return path.join(androidCmdToolsPath, 'sdkmanager');
}

String get emulatorCmd {
  return path.join(androidHome, 'emulator', 'emulator');
}

String get adbCommand {
  return path.join(androidHome, 'platform-tools', 'adb');
}

Future<void> killAllEmulators() async {
  final runningDevices = await _getRunningDevices();

  for (final device in runningDevices.entries) {
    await shellRun(adbCommand, ['-s', device.key, 'emu', 'kill'],
        writeStdOut: true);
  }
}

const _emulatorBootTimeout = Duration(minutes: 5);
const _emulatorPollInterval = Duration(seconds: 5);

String _ciEmulatorName(String apiLevel) => 'ci_emu_api_$apiLevel';

/// Restores a booted emulator after a failed integration test launch.
Future<void> recoverAndroidEmulators() async {
  final devices = await _getRunningDevices();
  if (devices.isEmpty) {
    final apiLevel = Platform.environment['ANDROID_EMULATOR_SDK'];
    if (apiLevel == null || apiLevel.isEmpty) {
      throw StateError(
        'No Android emulator is connected. Set ANDROID_EMULATOR_SDK to relaunch the CI emulator.',
      );
    }
    final emulatorName = _ciEmulatorName(apiLevel);
    print('No Android emulator is connected. Relaunching $emulatorName.');
    if (!await _startEmulator(emulatorName)) {
      throw StateError('Failed to relaunch $emulatorName.');
    }
    return;
  }

  for (final id in devices.keys) {
    print('Rebooting $id');
    final deadline = DateTime.now().add(_emulatorBootTimeout);
    await shellRun(adbCommand, [
      '-s',
      id,
      'reboot',
    ], timeout: deadline.difference(DateTime.now()));

    await shellRun(adbCommand, [
      '-s',
      id,
      'wait-for-device',
    ], timeout: deadline.difference(DateTime.now()));

    var booted = false;
    while (!booted && DateTime.now().isBefore(deadline)) {
      booted = await _hasBooted(id, deadline);
      if (!booted) await Future.delayed(_emulatorPollInterval);
    }
    if (!booted) throw Exception('Timed out waiting for $id to finish booting');
  }
}

Future<bool> launchAndroidEmulator({
  String? apiLevel,
  String? emulatorName,
  bool shouldUpdate = true,
}) async {
  if (apiLevel == null && emulatorName == null) {
    print(
        'Error in script -- must specify either Android API level or an emulator name');
  }

  // Check to see if we've created one already
  bool needEmulatorCreate = true;
  if (emulatorName != null) {
    if (await _emulatorExists(emulatorName)) {
      needEmulatorCreate = false;
    }
  } else if (apiLevel != null) {
    emulatorName = _ciEmulatorName(apiLevel);
    needEmulatorCreate = !(await _emulatorExists(emulatorName));
  }

  if (emulatorName == null) {
    print("Failed to figure out what our emulator name should be!");
    return false;
  }

  if (needEmulatorCreate) {
    final package = 'system-images;android-$apiLevel;$avdTag;$avdAbi';
    if (shouldUpdate) {
      print("Updating emulators with sdkmanager");
      await shellRun(sdkManager, ["--verbose", "emulator"],
          writeStdOut: true,
          stdIn: Stream.fromIterable(yesList).transform(
            utf8.encoder,
          ));
    }

    print("Updating system-image packages");
    await shellRun(
      sdkManager,
      ["--verbose", package],
      writeStdOut: true,
      stdIn: Stream.fromIterable(yesList).transform(utf8.encoder),
    );

    print("Creating device");
    await shellRun(
      avdManager,
      ['create', 'avd', '-n', emulatorName, '--package', package],
      writeStdOut: true,
      stdIn: Stream<String>.value('no\n').transform(utf8.encoder),
    );
  }

  final devices = await _getRunningDevices();
  if (devices.isNotEmpty) {
    print('$emulatorName already started. Returning.');
    return true;
  }

  if (await _startEmulator(emulatorName)) {
    print('Force exiting now that emulator is started.');
    exit(0);
  }

  return false;
}

Future<bool> _emulatorExists(String emulatorName) async {
  print("Checking for existing Android emulator named $emulatorName...");
  final result = await shellRun(avdManager, ['list', 'avd', '--compact']);
  final emulators = result.split('\n');
  print('Found emulaors: $emulators');

  return emulators.contains(emulatorName);
}

Future<Map<String, String>> _getRunningDevices({
  Duration timeout = _emulatorBootTimeout,
}) async {
  final emulatorRegex = RegExp(r'^(?<emulator>emulator-\d*)[\s+](?<state>.*)');

  final result = <String, String>{};
  final devicesLog = await shellRun(adbCommand, ['devices'], timeout: timeout);
  for (var line in devicesLog.split('\n')) {
    final match = emulatorRegex.firstMatch(line);
    if (match != null) {
      result[match.namedGroup('emulator')!] = match.namedGroup('state')!;
    }
  }

  return result;
}

Future<bool> _hasBooted(String id, DateTime deadline) async {
  try {
    final result = await shellRun(adbCommand, [
      '-s',
      id,
      'shell',
      'getprop',
      'sys.boot_completed',
    ], timeout: deadline.difference(DateTime.now()));
    return result.trim() == '1';
  } on Exception {
    // ADB can lose the transport briefly during boot.
    return false;
  }
}

/// The name of the file that collects output from all emulator launches.
const emulatorLogFile = 'emulator.log';

Future<bool> _startEmulator(String emulatorName) async {
  final accelCheck = await Process.run(emulatorCmd, ['-accel-check']);
  print('Emulator acceleration check (exit code ${accelCheck.exitCode}):');
  print(accelCheck.stdout);
  print(accelCheck.stderr);
  if (accelCheck.exitCode != 0) {
    final kvmInfo = await Process.run('sh', ['-c', 'id; ls -ln /dev/kvm']);
    print(kvmInfo.stdout);
    print(kvmInfo.stderr);
  }

  final ciProjectDir = Platform.environment['CI_PROJECT_DIR'];
  // `tools/ci/.tmp` is git ignored. Without CI_PROJECT_DIR the path is relative
  // to the working directory, which is `tools/ci`.
  final ciDir = ciProjectDir == null
      ? ''
      : path.join(ciProjectDir, 'tools', 'ci');
  final logPath = path.join(ciDir, '.tmp', emulatorLogFile);
  await Directory(path.dirname(logPath)).create(recursive: true);
  print('Starting $emulatorName, logging to $logPath');

  // The detached shell collects output and records the emulator's exit status.
  await Process.start('sh', [
    '-c',
    r'''
log_file=$1
shift
{
  printf '\n[%s] Starting Android emulator %s\n' "$(date -u +%FT%TZ)" "$2"
  "$@"
  status=$?
  printf '\n[%s] Android emulator exited with status %s\n' "$(date -u +%FT%TZ)" "$status"
  exit "$status"
} >> "$log_file" 2>&1
''',
    'android-emulator',
    logPath,
    emulatorCmd,
    "@$emulatorName",
    '-verbose',
    '-show-kernel',
    '-no-audio',
    '-no-window',
    // Use software GLES rendering on headless GitLab runners.
    if (ciProjectDir != null) ...['-gpu', 'swiftshader', '-feature', '-Vulkan'],
    '-netdelay',
    'none',
    '-no-snapshot',
    '-wipe-data',
  ], mode: ProcessStartMode.detached);

  final deadline = DateTime.now().add(_emulatorBootTimeout);
  while (DateTime.now().isBefore(deadline)) {
    final devices = await _getRunningDevices(
      timeout: deadline.difference(DateTime.now()),
    );
    final device = devices.entries.firstWhereOrNull(
      (device) => device.value == 'device',
    );
    if (device != null && await _hasBooted(device.key, deadline)) {
      print('${device.key} finished booting.');
      return true;
    }
    await Future.delayed(_emulatorPollInterval);
  }

  print('Emulator failed to boot. See $logPath for output.');
  return false;
}
