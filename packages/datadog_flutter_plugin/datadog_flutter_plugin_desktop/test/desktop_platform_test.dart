// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:datadog_flutter_plugin_desktop/src/desktop_platform.dart';
import 'package:datadog_flutter_plugin_desktop/src/ffi_bindings.dart';
import 'package:datadog_flutter_plugin_desktop/src/logs_desktop_platform.dart';
import 'package:datadog_flutter_plugin_desktop/src/rum_desktop_platform.dart';
import 'package:datadog_flutter_plugin_platform_interface/datadog_flutter_plugin_platform_interface.dart';
import 'package:datadog_flutter_plugin_platform_interface/datadog_internal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import 'ffi_test_helpers.dart';

class MockSdkFfi extends Mock implements DdSdkFfi {}

DatadogConfiguration _config({
  bool logging = true,
  bool rum = true,
  String? desktopDataDirectory,
}) => DatadogConfiguration(
  clientToken: 'token',
  env: 'env',
  site: DatadogSite.us1,
  service: 'service',
  desktopDataDirectory: desktopDataDirectory,
  loggingConfiguration: logging ? DatadogLoggingConfiguration() : null,
  rumConfiguration: rum
      ? DatadogRumConfiguration(applicationId: 'app-id')
      : null,
);

void main() {
  final core = ffi.Pointer<dd_core_t>.fromAddress(0x1000);
  final logging = ffi.Pointer<dd_logging_t>.fromAddress(0x2000);
  final rum = ffi.Pointer<dd_rum_t>.fromAddress(0x3000);

  late MockSdkFfi sdk;
  late DatadogDesktopPlatform platform;
  late DdLogsPlatform originalLogsPlatform;
  late DdRumPlatform originalRumPlatform;

  Future<PlatformInitializationResult> initialize([
    DatadogConfiguration? configuration,
  ]) => platform.initialize(
    configuration ?? _config(),
    TrackingConsent.granted,
    internalLogger: InternalLogger(),
  );

  setUpAll(() {
    registerFallbackValue(ffi.nullptr.cast<dd_core_config_t>());
    registerFallbackValue(ffi.nullptr.cast<dd_core_t>());
    registerFallbackValue(ffi.nullptr.cast<dd_rum_config_t>());
    registerFallbackValue(ffi.nullptr.cast<dd_attribute_t>());
    registerFallbackValue(ffi.nullptr.cast<ffi.Char>());
  });

  setUp(() {
    originalLogsPlatform = DdLogsPlatform.instance;
    originalRumPlatform = DdRumPlatform.instance;
    sdk = MockSdkFfi();
    platform = DatadogDesktopPlatform(sdk);
    when(() => sdk.dd_core_create(any(), any())).thenReturn(core);
    when(() => sdk.dd_logging_init(any())).thenReturn(logging);
    when(() => sdk.dd_rum_init(any(), any())).thenReturn(rum);
    when(() => sdk.dd_core_start(any())).thenReturn(true);
  });

  tearDown(() async {
    await platform.flushAndDeinitialize();
    DdLogsPlatform.instance = originalLogsPlatform;
    DdRumPlatform.instance = originalRumPlatform;
  });

  group('failed initialization', () {
    test('failed dd_core_start destroys features and core', () async {
      when(() => sdk.dd_core_start(any())).thenReturn(false);

      final result = await initialize();

      expect(result.logs, isFalse);
      expect(result.rum, isFalse);
      verifyInOrder([
        () => sdk.dd_core_start(core),
        () => sdk.dd_logging_destroy(logging),
        () => sdk.dd_rum_destroy(rum),
        () => sdk.dd_core_destroy(core),
      ]);
      verifyNever(() => sdk.dd_core_stop(any()));
    });

    test('failed dd_core_start leaves no core for later calls', () async {
      when(() => sdk.dd_core_start(any())).thenReturn(false);
      await initialize();
      clearInteractions(sdk);

      await platform.setTrackingConsent(TrackingConsent.pending);
      await platform.flushAndDeinitialize();

      verifyNoMoreInteractions(sdk);
    });

    test('failed dd_core_create creates no native handles', () async {
      when(() => sdk.dd_core_create(any(), any())).thenReturn(ffi.nullptr);

      final result = await initialize();

      expect(result.logs, isFalse);
      expect(result.rum, isFalse);
      verifyNever(() => sdk.dd_logging_init(any()));
      verifyNever(() => sdk.dd_rum_init(any(), any()));
      verifyNever(() => sdk.dd_core_start(any()));

      await platform.setTrackingConsent(TrackingConsent.pending);
      verifyNever(() => sdk.dd_core_set_tracking_consent(any(), any()));
    });

    test('initialize succeeds after a failed dd_core_start', () async {
      when(() => sdk.dd_core_start(any())).thenReturn(false);
      await initialize();
      when(() => sdk.dd_core_start(any())).thenReturn(true);
      clearInteractions(sdk);

      final result = await initialize();

      expect(result.logs, isTrue);
      expect(result.rum, isTrue);
      verifyInOrder([
        () => sdk.dd_core_create(any(), any()),
        () => sdk.dd_logging_init(core),
        () => sdk.dd_rum_init(core, any()),
        () => sdk.dd_core_start(core),
      ]);

      await platform.flushAndDeinitialize();
      verifyInOrder([
        () => sdk.dd_core_stop(core),
        () => sdk.dd_core_destroy(core),
      ]);
    });
  });

  group('initialization result', () {
    test('enables both features when both are configured', () async {
      final result = await initialize();

      expect(result.logs, isTrue);
      expect(result.rum, isTrue);
    });

    test('enables only logging when only logging is configured', () async {
      final result = await initialize(_config(rum: false));

      expect(result.logs, isTrue);
      expect(result.rum, isFalse);
      verifyNever(() => sdk.dd_rum_init(any(), any()));
    });

    test('enables only RUM when only RUM is configured', () async {
      final result = await initialize(_config(logging: false));

      expect(result.logs, isFalse);
      expect(result.rum, isTrue);
      verifyNever(() => sdk.dd_logging_init(any()));
    });

    test('starts the core with no features configured', () async {
      final result = await initialize(_config(logging: false, rum: false));

      expect(result.logs, isFalse);
      expect(result.rum, isFalse);
      verify(() => sdk.dd_core_start(core)).called(1);
    });

    test('does not enable a feature whose native init returns null', () async {
      when(() => sdk.dd_logging_init(any())).thenReturn(ffi.nullptr);

      final result = await initialize();

      expect(result.logs, isFalse);
      expect(result.rum, isTrue);
    });

    test('registers the desktop logs and RUM platforms', () async {
      await initialize();

      expect(DdLogsPlatform.instance, isA<DdLogsDesktopPlatform>());
      expect(DdRumPlatform.instance, isA<DdRumDesktopPlatform>());
    });

    test('leaves platforms unregistered for unconfigured features', () async {
      await initialize(_config(logging: false, rum: false));

      expect(DdLogsPlatform.instance, same(originalLogsPlatform));
      expect(DdRumPlatform.instance, same(originalRumPlatform));
    });
  });

  group('desktopDataDirectory', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dd_desktop_platform_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('passes a valid directory to the C SDK as the storage path', () async {
      final path = p.join(tempDir.path, 'data');
      String? storagePath;
      when(
        () => sdk.dd_core_config_set_application_storage_path(any(), any()),
      ).thenAnswer((invocation) {
        storagePath = nativeString(invocation.positionalArguments[1]);
      });

      await initialize(_config(desktopDataDirectory: path));

      expect(storagePath, p.normalize(path));
      expect(Directory(path).existsSync(), isTrue);
    });

    test('does not set a storage path when none is configured', () async {
      await initialize();

      verifyNever(
        () => sdk.dd_core_config_set_application_storage_path(any(), any()),
      );
    });

    test('rejects an invalid directory without creating a core', () async {
      final result = await initialize(
        _config(desktopDataDirectory: 'relative/path'),
      );

      expect(result.logs, isFalse);
      expect(result.rum, isFalse);
      verifyNever(() => sdk.dd_core_create(any(), any()));
    });

    test('rejects a directory that cannot be created', () async {
      final file = File(p.join(tempDir.path, 'file'))..writeAsStringSync('');

      final result = await initialize(
        _config(desktopDataDirectory: p.join(file.path, 'data')),
      );

      expect(result.logs, isFalse);
      expect(result.rum, isFalse);
      verifyNever(() => sdk.dd_core_create(any(), any()));
    });
  });

  group('after initialization', () {
    setUp(() async {
      await initialize();
      clearInteractions(sdk);
    });

    const consents = {
      TrackingConsent.granted:
          dd_tracking_consent_t.DD_TRACKING_CONSENT_GRANTED,
      TrackingConsent.notGranted:
          dd_tracking_consent_t.DD_TRACKING_CONSENT_NOT_GRANTED,
      TrackingConsent.pending:
          dd_tracking_consent_t.DD_TRACKING_CONSENT_PENDING,
    };
    for (final MapEntry(key: consent, value: native) in consents.entries) {
      test('setTrackingConsent maps $consent to the native consent', () async {
        await platform.setTrackingConsent(consent);

        verify(() => sdk.dd_core_set_tracking_consent(core, native)).called(1);
      });
    }

    test('setUserInfo passes the user details to the C SDK', () async {
      String? id;
      String? name;
      String? email;
      var hasExtraInfo = false;
      when(
        () => sdk.dd_core_set_user_info(any(), any(), any(), any(), any()),
      ).thenAnswer((invocation) {
        final args = invocation.positionalArguments;
        id = nativeString(args[1]);
        name = nativeString(args[2]);
        email = nativeString(args[3]);
        hasExtraInfo = (args[4] as ffi.Pointer).address != 0;
      });

      await platform.setUserInfo('user-1', 'Name', 'me@example.com', {
        'plan': 'pro',
      });

      verify(
        () => sdk.dd_core_set_user_info(core, any(), any(), any(), any()),
      ).called(1);
      expect(id, 'user-1');
      expect(name, 'Name');
      expect(email, 'me@example.com');
      expect(hasExtraInfo, isTrue);
    });

    test('setUserInfo passes null name and email as null', () async {
      var nameIsNull = false;
      var emailIsNull = false;
      var hasExtraInfo = true;
      when(
        () => sdk.dd_core_set_user_info(any(), any(), any(), any(), any()),
      ).thenAnswer((invocation) {
        final args = invocation.positionalArguments;
        nameIsNull = nativeString(args[2]) == null;
        emailIsNull = nativeString(args[3]) == null;
        hasExtraInfo = (args[4] as ffi.Pointer).address != 0;
      });

      await platform.setUserInfo('user-1', null, null, {});

      expect(nameIsNull, isTrue);
      expect(emailIsNull, isTrue);
      expect(hasExtraInfo, isFalse);
    });

    test('clearUserInfo clears the native user info', () async {
      await platform.clearUserInfo();

      verify(() => sdk.dd_core_clear_user_info(core)).called(1);
    });

    test('addUserExtraInfo passes the attributes to the C SDK', () async {
      final keys = <String?>[];
      when(
        () => sdk.dd_attribute_object_property_set(any(), any(), any()),
      ).thenAnswer((invocation) {
        keys.add(nativeString(invocation.positionalArguments[1]));
      });

      await platform.addUserExtraInfo({'plan': 'pro'});

      verify(() => sdk.dd_core_add_user_extra_info(core, any())).called(1);
      expect(keys, ['plan']);
    });

    test('addUserExtraInfo ignores empty attributes', () async {
      await platform.addUserExtraInfo({});

      verifyNever(() => sdk.dd_core_add_user_extra_info(any(), any()));
    });

    test('setAccountInfo passes the account details to the C SDK', () async {
      String? id;
      String? name;
      var hasExtraInfo = false;
      when(
        () => sdk.dd_core_set_account_info(any(), any(), any(), any()),
      ).thenAnswer((invocation) {
        final args = invocation.positionalArguments;
        id = nativeString(args[1]);
        name = nativeString(args[2]);
        hasExtraInfo = (args[3] as ffi.Pointer).address != 0;
      });

      await platform.setAccountInfo('account-1', 'Account', {'tier': 'gold'});

      verify(
        () => sdk.dd_core_set_account_info(core, any(), any(), any()),
      ).called(1);
      expect(id, 'account-1');
      expect(name, 'Account');
      expect(hasExtraInfo, isTrue);
    });

    test('clearAccountInfo clears the native account info', () async {
      await platform.clearAccountInfo();

      verify(() => sdk.dd_core_clear_account_info(core)).called(1);
    });

    test('addAccountExtraInfo passes the attributes to the C SDK', () async {
      await platform.addAccountExtraInfo({'tier': 'gold'});

      verify(() => sdk.dd_core_add_account_extra_info(core, any())).called(1);
    });

    test('addAccountExtraInfo ignores empty attributes', () async {
      await platform.addAccountExtraInfo({});

      verifyNever(() => sdk.dd_core_add_account_extra_info(any(), any()));
    });

    test('flushAndDeinitialize stops, then destroys the core', () async {
      await platform.flushAndDeinitialize();

      verifyInOrder([
        () => sdk.dd_core_stop(core),
        () => sdk.dd_core_destroy(core),
      ]);
    });

    test('flushAndDeinitialize is safe to call twice', () async {
      await platform.flushAndDeinitialize();
      clearInteractions(sdk);

      await platform.flushAndDeinitialize();

      verifyNoMoreInteractions(sdk);
    });

    test('calls after flushAndDeinitialize do not reach the C SDK', () async {
      await platform.flushAndDeinitialize();
      clearInteractions(sdk);

      await platform.setTrackingConsent(TrackingConsent.pending);
      await platform.setUserInfo('user-1', null, null, {});
      await platform.clearUserInfo();
      await platform.addUserExtraInfo({'plan': 'pro'});
      await platform.setAccountInfo('account-1', null, {});
      await platform.clearAccountInfo();
      await platform.addAccountExtraInfo({'tier': 'gold'});

      verifyNoMoreInteractions(sdk);
    });
  });

  group('before initialization', () {
    test('calls do not reach the C SDK', () async {
      await platform.setTrackingConsent(TrackingConsent.pending);
      await platform.setUserInfo('user-1', null, null, {});
      await platform.clearUserInfo();
      await platform.addUserExtraInfo({'plan': 'pro'});
      await platform.setAccountInfo('account-1', null, {});
      await platform.clearAccountInfo();
      await platform.addAccountExtraInfo({'tier': 'gold'});
      await platform.flushAndDeinitialize();

      verifyNoMoreInteractions(sdk);
    });
  });
}
