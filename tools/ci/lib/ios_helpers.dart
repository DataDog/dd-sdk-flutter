// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:convert';

import 'package:ci_helpers/shell_helpers.dart';
import 'package:collection/collection.dart';

class IosSimulator {
  final String name;
  final String udid;
  final String deviceTypeIdentifier;
  final String state;

  IosSimulator({
    required this.name,
    required this.udid,
    required this.deviceTypeIdentifier,
    required this.state,
  });

  static IosSimulator? fromJson(Map<String, dynamic> json) {
    IosSimulator? value;
    try {
      value = IosSimulator(
        name: json['name'],
        udid: json['udid'],
        deviceTypeIdentifier: json['deviceTypeIdentifier'],
        state: json['state'],
      );
    } catch (e) {
      print('Error parsing $e');
    }

    return value;
  }
}

const _simulatorTimeout = Duration(minutes: 5);

Future<bool> launchIosSimulator(String sdk, String? deviceName) async {
  final simulatorList = await getIosSimulators();

  // "Fuzzy" SDK match
  final sdkDevices = simulatorList.entries
      .firstWhereOrNull((element) => element.key.contains(sdk))
      ?.value;
  if (sdkDevices != null) {
    IosSimulator? device;
    if (deviceName != null) {
      device = sdkDevices
          .firstWhereOrNull((element) => element.name.contains(deviceName));
    } else {
      device = sdkDevices.firstOrNull;
    }

    if (device != null) {
      if (device.state == 'Booted') {
        print('Device ${device.name} is already booted.');
        return true;
      }

      print('Launching $deviceName');
      await _xcrun('simctl boot ${device.udid}', timeout: _simulatorTimeout);
      await _xcrun(
        'simctl bootstatus ${device.udid} -b',
        timeout: _simulatorTimeout,
      );
      return true;
    } else {
      print('Found no devices matching $deviceName');
      print(sdkDevices);
    }
  } else {
    print('Found no runtimes matching $sdk');
  }

  return false;
}

/// Shuts down and re-boots every booted simulator, waiting until each is
/// ready for use.
Future<void> rebootBootedIosSimulators() async {
  final booted = [
    for (final devices in (await getIosSimulators()).values)
      ...devices.where((device) => device.state == 'Booted'),
  ];
  for (final device in booted) {
    print('Rebooting ${device.name} (${device.udid})');
    await _xcrun('simctl shutdown ${device.udid}', timeout: _simulatorTimeout);
    await _xcrun('simctl boot ${device.udid}', timeout: _simulatorTimeout);
    await _xcrun(
      'simctl bootstatus ${device.udid} -b',
      timeout: _simulatorTimeout,
    );
  }
}

Future<Map<String, List<IosSimulator>>> getIosSimulators() async {
  final commandJson =
      jsonDecode(await _xcrun('simctl list --json devices available'));

  final devicesJson = commandJson['devices'] as Map<String, dynamic>;

  return devicesJson.map((key, value) {
    final devices = (value as List)
        .map((e) {
          return IosSimulator.fromJson(e);
        })
        .whereType<IosSimulator>()
        .toList();

    return MapEntry(key, devices);
  });
}

Future<String> _xcrun(String command, {Duration? timeout}) =>
    shellRun('xcrun', command.split(' '), timeout: timeout);
