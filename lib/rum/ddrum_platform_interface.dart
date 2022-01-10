// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ddrum.dart';
import 'ddrum_method_channel.dart';

abstract class DdRumPlatform extends PlatformInterface {
  DdRumPlatform() : super(token: _token);

  static final Object _token = Object();

  static DdRumPlatform _instance = DdRumMethodChannel();

  static DdRumPlatform get instance => _instance;

  static set instance(DdRumPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> startView(
      String key, String name, Map<String, dynamic> attributes);
  Future<void> stopView(String key, Map<String, dynamic> attributes);
  Future<void> addTiming(String name);

  Future<void> startResourceLoading(String key, RumHttpMethod httpMethod,
      String url, Map<String, dynamic> attributes);
  Future<void> stopResourceLoading(String key, int? statusCode,
      RumResourceType kind, int? size, Map<String, dynamic> attributes);
  Future<void> stopResourceLoadingWithError(
      String key, Exception error, Map<String, dynamic> attributes);
  Future<void> stopResourceLoadingWithErrorInfo(
      String key, String message, Map<String, dynamic> attributes);

  Future<void> addError(
      Exception error, RumErrorSource source, Map<String, dynamic> attributes);
  Future<void> addErrorInfo(String message, RumErrorSource source,
      StackTrace? stack, Map<String, dynamic> attributes);

  Future<void> addUserAction(
      RumUserActionType type, String? name, Map<String, dynamic> attributes);
}
