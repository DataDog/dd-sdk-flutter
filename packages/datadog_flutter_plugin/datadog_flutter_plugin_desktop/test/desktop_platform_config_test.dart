// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:ffi' as ffi;

import 'package:datadog_flutter_plugin_desktop/src/desktop_platform.dart';
import 'package:datadog_flutter_plugin_desktop/src/ffi_bindings.dart';
import 'package:datadog_flutter_plugin_platform_interface/datadog_flutter_plugin_platform_interface.dart';
import 'package:datadog_flutter_plugin_platform_interface/datadog_internal.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSdkFfi extends Mock implements DdSdkFfi {}

/// Reads the C string passed as positional argument [index] of [invocation].
/// Must be called while the call is in flight, before the plugin frees it.
String _stringArg(Invocation invocation, int index) =>
    (invocation.positionalArguments[index] as ffi.Pointer<ffi.Char>)
        .cast<Utf8>()
        .toDartString();

void main() {
  late MockSdkFfi sdk;

  setUpAll(() {
    registerFallbackValue(ffi.nullptr.cast<dd_core_config_t>());
    registerFallbackValue(ffi.nullptr.cast<dd_core_t>());
    registerFallbackValue(ffi.nullptr.cast<dd_rum_config_t>());
    registerFallbackValue(ffi.nullptr.cast<ffi.Char>());
  });

  setUp(() {
    sdk = MockSdkFfi();
    when(
      () => sdk.dd_core_create(any(), any()),
    ).thenReturn(ffi.Pointer<dd_core_t>.fromAddress(1));
    when(
      () => sdk.dd_rum_init(any(), any()),
    ).thenReturn(ffi.Pointer<dd_rum_t>.fromAddress(1));
    // A failed start makes initialize() return before it touches isolates.
    when(() => sdk.dd_core_start(any())).thenReturn(false);
  });

  Future<void> initialize(
    DatadogConfiguration configuration, {
    TrackingConsent consent = TrackingConsent.granted,
  }) async {
    await DatadogDesktopPlatform(
      sdk,
    ).initialize(configuration, consent, internalLogger: InternalLogger());
  }

  DatadogConfiguration config({
    DatadogSite site = DatadogSite.us1,
    BatchSize? batchSize,
    UploadFrequency? uploadFrequency,
    BatchProcessingLevel? batchProcessingLevel,
    String? version,
    String? flavor,
    DatadogRumConfiguration? rumConfiguration,
  }) => DatadogConfiguration(
    clientToken: 'token',
    env: 'env',
    site: site,
    service: 'service',
    batchSize: batchSize,
    uploadFrequency: uploadFrequency,
    batchProcessingLevel: batchProcessingLevel,
    version: version,
    flavor: flavor,
    rumConfiguration: rumConfiguration,
  );

  group('core configuration', () {
    test('passes client token, service and env to the C SDK', () async {
      final received = <String>[];
      when(
        () => sdk.dd_core_config_init(any(), any(), any(), any()),
      ).thenAnswer((invocation) {
        received.addAll([
          _stringArg(invocation, 1),
          _stringArg(invocation, 2),
          _stringArg(invocation, 3),
        ]);
      });

      await initialize(config());

      expect(received, ['token', 'service', 'env']);
    });

    const sites = {
      DatadogSite.us1: dd_site_t.DD_SITE_US1,
      DatadogSite.us3: dd_site_t.DD_SITE_US3,
      DatadogSite.us5: dd_site_t.DD_SITE_US5,
      DatadogSite.eu1: dd_site_t.DD_SITE_EU1,
      DatadogSite.us1Fed: dd_site_t.DD_SITE_US1_FED,
      DatadogSite.ap1: dd_site_t.DD_SITE_AP1,
      DatadogSite.ap2: dd_site_t.DD_SITE_AP2,
    };
    for (final MapEntry(key: site, value: native) in sites.entries) {
      test('maps $site to the native site', () async {
        await initialize(config(site: site));

        verify(() => sdk.dd_core_config_set_site(any(), native)).called(1);
      });
    }

    const consents = {
      TrackingConsent.granted:
          dd_tracking_consent_t.DD_TRACKING_CONSENT_GRANTED,
      TrackingConsent.notGranted:
          dd_tracking_consent_t.DD_TRACKING_CONSENT_NOT_GRANTED,
      TrackingConsent.pending:
          dd_tracking_consent_t.DD_TRACKING_CONSENT_PENDING,
    };
    for (final MapEntry(key: consent, value: native) in consents.entries) {
      test('maps $consent to the native tracking consent', () async {
        await initialize(config(), consent: consent);

        verify(() => sdk.dd_core_create(any(), native)).called(1);
      });
    }

    const batchSizes = {
      BatchSize.small: dd_batch_size_t.DD_BATCH_SIZE_SMALL,
      BatchSize.medium: dd_batch_size_t.DD_BATCH_SIZE_MEDIUM,
      BatchSize.large: dd_batch_size_t.DD_BATCH_SIZE_LARGE,
    };
    for (final MapEntry(key: size, value: native) in batchSizes.entries) {
      test('maps $size to the native batch size', () async {
        await initialize(config(batchSize: size));

        verify(
          () => sdk.dd_core_config_set_batch_size(any(), native),
        ).called(1);
      });
    }

    const frequencies = {
      UploadFrequency.frequent:
          dd_upload_frequency_t.DD_UPLOAD_FREQUENCY_FREQUENT,
      UploadFrequency.average:
          dd_upload_frequency_t.DD_UPLOAD_FREQUENCY_AVERAGE,
      UploadFrequency.rare: dd_upload_frequency_t.DD_UPLOAD_FREQUENCY_RARE,
    };
    for (final MapEntry(key: frequency, value: native) in frequencies.entries) {
      test('maps $frequency to the native upload frequency', () async {
        await initialize(config(uploadFrequency: frequency));

        verify(
          () => sdk.dd_core_config_set_upload_frequency(any(), native),
        ).called(1);
      });
    }

    const levels = {
      BatchProcessingLevel.low:
          dd_batch_processing_level_t.DD_BATCH_PROCESSING_LEVEL_LOW,
      BatchProcessingLevel.medium:
          dd_batch_processing_level_t.DD_BATCH_PROCESSING_LEVEL_MEDIUM,
      BatchProcessingLevel.high:
          dd_batch_processing_level_t.DD_BATCH_PROCESSING_LEVEL_HIGH,
    };
    for (final MapEntry(key: level, value: native) in levels.entries) {
      test('maps $level to the native batch processing level', () async {
        await initialize(config(batchProcessingLevel: level));

        verify(
          () => sdk.dd_core_config_set_batch_processing_level(any(), native),
        ).called(1);
      });
    }

    test('leaves batch settings at the native defaults when unset', () async {
      await initialize(config());

      verifyNever(() => sdk.dd_core_config_set_batch_size(any(), any()));
      verifyNever(() => sdk.dd_core_config_set_upload_frequency(any(), any()));
      verifyNever(
        () => sdk.dd_core_config_set_batch_processing_level(any(), any()),
      );
    });

    test('passes version and flavor to the C SDK', () async {
      String? version;
      String? variant;
      when(() => sdk.dd_core_config_set_version(any(), any())).thenAnswer((
        invocation,
      ) {
        version = _stringArg(invocation, 1);
      });
      when(() => sdk.dd_core_config_set_variant(any(), any())).thenAnswer((
        invocation,
      ) {
        variant = _stringArg(invocation, 1);
      });

      await initialize(config(version: '1.2.3', flavor: 'staging'));

      expect(version, '1.2.3');
      expect(variant, 'staging');
    });

    test('does not set version or flavor when unset', () async {
      await initialize(config());

      verifyNever(() => sdk.dd_core_config_set_version(any(), any()));
      verifyNever(() => sdk.dd_core_config_set_variant(any(), any()));
    });
  });

  group('custom endpoint', () {
    Future<String?> endpointFor(String? endpoint) async {
      String? received;
      when(
        () => sdk.dd_core_config_internal_set_custom_endpoint_url(any(), any()),
      ).thenAnswer((invocation) {
        received = _stringArg(invocation, 1);
      });

      await initialize(
        config(
          rumConfiguration: DatadogRumConfiguration(
            applicationId: 'app-id',
            customEndpoint: endpoint,
          ),
        ),
      );
      return received;
    }

    test('is not set when none is configured', () async {
      expect(await endpointFor(null), isNull);
    });

    test('has trailing slashes stripped', () async {
      expect(await endpointFor('https://example.com//'), 'https://example.com');
    });

    test('rewrites a localhost host to 127.0.0.1', () async {
      expect(
        await endpointFor('http://localhost:8080/'),
        'http://127.0.0.1:8080',
      );
    });
  });

  group('RUM configuration', () {
    test('passes the application id to the C SDK', () async {
      String? applicationId;
      when(() => sdk.dd_rum_config_init(any(), any())).thenAnswer((invocation) {
        applicationId = _stringArg(invocation, 1);
      });

      await initialize(
        config(
          rumConfiguration: DatadogRumConfiguration(applicationId: 'app-id'),
        ),
      );

      expect(applicationId, 'app-id');
    });

    test('does not initialize RUM without a RUM configuration', () async {
      await initialize(config());

      verifyNever(() => sdk.dd_rum_init(any(), any()));
    });

    test('forwards a non-default session sampling rate', () async {
      await initialize(
        config(
          rumConfiguration: DatadogRumConfiguration(
            applicationId: 'app-id',
            sessionSamplingRate: 50.0,
          ),
        ),
      );

      verify(
        () => sdk.dd_rum_config_set_session_sample_rate(any(), 50.0),
      ).called(1);
    });

    test('leaves the native default sampling rate at 100%', () async {
      await initialize(
        config(
          rumConfiguration: DatadogRumConfiguration(applicationId: 'app-id'),
        ),
      );

      verifyNever(
        () => sdk.dd_rum_config_set_session_sample_rate(any(), any()),
      );
    });

    for (final value in [true, false]) {
      test('forwards trackAnonymousUser = $value to the C SDK', () async {
        await initialize(
          config(
            rumConfiguration: DatadogRumConfiguration(
              applicationId: 'app-id',
              trackAnonymousUser: value,
            ),
          ),
        );

        verify(
          () => sdk.dd_rum_config_set_track_anonymous_user(any(), value),
        ).called(1);
      });
    }
  });
}
