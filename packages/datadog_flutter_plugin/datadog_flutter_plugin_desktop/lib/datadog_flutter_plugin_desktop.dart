// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:datadog_flutter_plugin_platform_interface/datadog_internal.dart';

import 'src/desktop_platform.dart';
import 'src/ffi_bindings.dart';

export 'src/desktop_platform.dart';
export 'src/ffi_bindings.dart';
export 'src/logs_desktop_platform.dart';
export 'src/rum_desktop_platform.dart';

class DatadogFlutterPluginDesktop {
  static void registerWith() {
    final lib = Platform.isWindows
        ? ffi.DynamicLibrary.open('ddsdkcpp.dll')
        : ffi.DynamicLibrary.open('libddsdkcpp.so');
    DatadogSdkPlatform.instance = DatadogDesktopPlatform(DdSdkFfi(lib));
  }
}
