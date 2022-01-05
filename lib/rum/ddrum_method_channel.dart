// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import 'ddrum_platform_interface.dart';

class DdRumMethodChannel extends DdRumPlatform {
  @visibleForTesting
  final MethodChannel methodChannel =
      const MethodChannel('datadog_sdk_flutter.rum');

  @override
  Future<void> addTiming(String name) {
    return methodChannel.invokeMethod(
      'addTiming',
      {'name': name},
    );
  }

  @override
  Future<void> startView(
      String key, String name, Map<String, dynamic> attributes) async {
    try {
      await methodChannel.invokeMethod(
        'startView',
        {'key': key, 'name': name, 'attributes': attributes},
      );
    } on ArgumentError {
      // TODO: RUMM-1849 Determine error loging approach
    }
  }

  @override
  Future<void> stopView(String key, Map<String, dynamic> attributes) async {
    try {
      await methodChannel.invokeMethod(
        'stopView',
        {'key': key, 'attributes': attributes},
      );
    } on ArgumentError {
      // TODO: RUMM-1849 Determine error loging approach
    }
  }
}
