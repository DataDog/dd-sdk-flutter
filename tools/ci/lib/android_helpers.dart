// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;

// Assume tag and abi for now
const avdTag = 'google_apis';
const avdAbi = 'arm64-v8a';

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
    await _run(adbCommand, ['-s', device.key, 'emu', 'kill'],
        writeStdOut: true);
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
    emulatorName = 'ci_emu_api_$apiLevel';
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
      await _run(sdkManager, ["--verbose", "emulator"],
          writeStdOut: true,
          stdIn: Stream.fromIterable(yesList).transform(
            utf8.encoder,
          ));
    }

    print("Updating system-image packages");
    await _run(
      sdkManager,
      ["--verbose", package],
      writeStdOut: true,
      stdIn: Stream.fromIterable(yesList).transform(utf8.encoder),
    );

    print("Creating device");
    await _run(
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
  final result = await _run(avdManager, ['list', 'avd', '--compact']);
  final emulators = result.split('\n');
  print('Found emulaors: $emulators');

  return emulators.contains(emulatorName);
}

Future<Map<String, String>> _getRunningDevices() async {
  final emulatorRegex = RegExp(r'^(?<emulator>emulator-\d*)[\s+](?<state>.*)');

  final result = <String, String>{};
  final devicesLog = await _run(adbCommand, ['devices']);
  for (var line in devicesLog.split('\n')) {
    final match = emulatorRegex.firstMatch(line);
    if (match != null) {
      result[match.namedGroup('emulator')!] = match.namedGroup('state')!;
    }
  }

  return result;
}

Future<bool> _startEmulator(String emulatorName) async {
  print("Starting device");

  var process = await Process.start(
      emulatorCmd,
      [
        "@$emulatorName",
        '-verbose',
        '-show-kernel',
        '-no-audio',
        '-netdelay',
        'none',
        '-no-snapshot',
        '-wipe-data'
      ],
      mode: ProcessStartMode.detached);

  var launched = false;
  final timeoutTime = DateTime.now().add(Duration(minutes: 5));
  while (DateTime.now().isBefore(timeoutTime)) {
    await Future.delayed(Duration(seconds: 5));
    print('Checking if emulator is running... ');
    final devices = await _getRunningDevices();
    if (devices.entries.firstOrNull?.value == 'device') {
      print('${devices.entries.first.value} running.');
      launched = true;
      break;
    }
  }

  // Delay another 10 seconds, make sure the emulator has some extra
  // time to boot.
  if (launched) {
    await Future.delayed(Duration(seconds: 10));
  }

  return launched;
}

Future<String> _run(
  String command,
  List<String> args, {
  bool writeStdOut = false,
  Stream<List<int>>? stdIn,
}) async {
  print("Running \$ $command ${args.join(' ')}");

  var process = await Process.start(command, args);
  var output = StringBuffer();
  process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((event) {
    if (writeStdOut) {
      print(event);
    }
    output.writeln(event);
  });
  process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((event) {
    print(event);
  });
  if (stdIn != null) {
    process.stdin.addStream(stdIn);
  }

  var exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw Exception('shell command exited with non-zero exit code: $exitCode.');
  }

  return output.toString();
}
