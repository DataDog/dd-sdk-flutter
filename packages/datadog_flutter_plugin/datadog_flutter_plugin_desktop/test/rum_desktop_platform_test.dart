// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:async';
import 'dart:ffi' as ffi;

import 'package:datadog_flutter_plugin_desktop/src/ffi_bindings.dart';
import 'package:datadog_flutter_plugin_desktop/src/rum_desktop_platform.dart';
import 'package:datadog_flutter_plugin_platform_interface/datadog_flutter_plugin_platform_interface.dart';
import 'package:datadog_flutter_plugin_platform_interface/datadog_internal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSdkFfi extends Mock implements DdSdkFfi {}

void main() {
  late MockSdkFfi sdk;
  late DdRumDesktopPlatform platform;
  late Completer<void> firstFrame;
  final rum = ffi.Pointer<dd_rum>.fromAddress(1);

  setUpAll(() {
    registerFallbackValue(ffi.nullptr.cast<dd_rum_t>());
  });

  setUp(() {
    sdk = MockSdkFfi();
    firstFrame = Completer<void>();
    platform = DdRumDesktopPlatform(
      sdk,
      rum,
      waitForFirstFrame: () => firstFrame.future,
    );
  });

  Future<void> enable() => platform.enable(
    InternalLogger(),
    DatadogRumConfiguration(applicationId: 'application-id'),
  );

  test(
    'enable reports app display initialized after the first frame',
    () async {
      await enable();
      verifyNever(() => sdk.dd_rum_report_app_display_initialized(any()));

      firstFrame.complete();
      await pumpEventQueue();

      verify(() => sdk.dd_rum_report_app_display_initialized(rum)).called(1);
    },
  );

  test(
    'enable does not report app display initialized after deinitialize',
    () async {
      await enable();
      await platform.deinitialize();

      firstFrame.complete();
      await pumpEventQueue();

      verifyNever(() => sdk.dd_rum_report_app_display_initialized(any()));
    },
  );

  test('reportAppFullyDisplayed reports to native rum', () async {
    await platform.reportAppFullyDisplayed();

    verify(() => sdk.dd_rum_report_app_fully_displayed(rum)).called(1);
  });

  test('reportAppFullyDisplayed does nothing after deinitialize', () async {
    await platform.deinitialize();

    await platform.reportAppFullyDisplayed();

    verifyNever(() => sdk.dd_rum_report_app_fully_displayed(any()));
  });
}
