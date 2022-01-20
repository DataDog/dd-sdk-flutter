// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ddlogs_method_channel.dart';

abstract class DdLogsPlatform extends PlatformInterface {
  DdLogsPlatform() : super(token: _token);

  static final Object _token = Object();

  static DdLogsPlatform _instance = DdLogsMethodChannel();

  static DdLogsPlatform get instance => _instance;

  static set instance(DdLogsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> debug(String message, [Map<String, Object?> context = const {}]);
  Future<void> info(String message, [Map<String, Object?> context = const {}]);
  Future<void> warn(String message, [Map<String, Object?> context = const {}]);
  Future<void> error(String message, [Map<String, Object?> context = const {}]);

  Future<void> addAttribute(String key, Object value);
  Future<void> removeAttribute(String key);
  Future<void> addTag(String tag, [String? value]);
  Future<void> removeTag(String tag);
  Future<void> removeTagWithKey(String key);
}
