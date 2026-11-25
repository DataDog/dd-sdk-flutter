// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:releaser/cocoapod_util.dart';
import 'package:releaser/native_sdk.dart';
import 'package:test/test.dart';

import 'support/test_temp.dart';

class _MockClient extends Mock implements HttpClient {}

class _MockRequest extends Mock implements HttpClientRequest {}

class _MockResponse extends Mock implements HttpClientResponse {}

class _MockLookup extends Mock {
  Future<bool> call(String pod, String version);
}

void main() {
  group('CocoaPods registry', () {
    for (final (status, available) in [
      (200, true),
      (404, false),
      (503, null),
    ]) {
      test('handles HTTP $status', () async {
        final client = _MockClient();
        final request = _MockRequest();
        final response = _MockResponse();
        final uri = Uri.https(
          'trunk.cocoapods.org',
          '/api/v1/pods/DatadogCore/specs/3.20.0',
        );
        when(() => client.getUrl(uri)).thenAnswer((_) async => request);
        when(() => request.close()).thenAnswer((_) async => response);
        when(() => response.statusCode).thenReturn(status);
        when(() => response.drain<void>()).thenAnswer((_) async {});

        final result = cocoaPodVersionExists(
          'DatadogCore',
          '3.20.0',
          client: client,
        );
        if (available == null) {
          await expectLater(result, throwsStateError);
        } else {
          expect(await result, available);
        }
      });
    }
  });

  group('native pod availability', () {
    late Directory root;
    late File podspec;
    late _MockLookup lookup;

    setUp(() async {
      root = await createTestTempDir('cocoapods_');
      podspec = File('${root.path}/plugin.podspec')
        ..writeAsStringSync('''
  s.dependency 'DatadogCore', '~> 3'
  s.dependency 'DatadogLogs', '~> 3'
  s.dependency 'DictionaryCoder', '1.2.0'
''');
      lookup = _MockLookup();
      when(() => lookup(any(), any())).thenAnswer((_) async => true);
    });

    tearDown(() => root.delete(recursive: true));

    test('checks every rewritten pod once across packages', () async {
      final delta = NativeSdkDelta(
        sdk: NativeSdk.ios,
        targetVersion: '3.20.0',
        files: [podspec],
      );
      await validateIosPodAvailability([delta, delta], lookup: lookup.call);
      verify(() => lookup('DatadogCore', '3.20.0')).called(1);
      verify(() => lookup('DatadogLogs', '3.20.0')).called(1);
      verifyNoMoreInteractions(lookup);
    });

    test('rejects a partially published native release', () async {
      when(
        () => lookup('DatadogLogs', '3.21.0'),
      ).thenAnswer((_) async => false);
      await expectLater(
        validateIosPodAvailability([
          NativeSdkDelta(
            sdk: NativeSdk.ios,
            targetVersion: '3.21.0',
            files: [podspec],
          ),
        ], lookup: lookup.call),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('DatadogLogs 3.21.0'),
          ),
        ),
      );
    });

    test('propagates registry failures', () async {
      when(
        () => lookup(any(), any()),
      ).thenThrow(const SocketException('offline'));
      await expectLater(
        validateIosPodAvailability([
          NativeSdkDelta(
            sdk: NativeSdk.ios,
            targetVersion: '3.20.0',
            files: [podspec],
          ),
        ], lookup: lookup.call),
        throwsA(isA<SocketException>()),
      );
    });

    test('skips SPM-only dependencies and unchanged pins', () async {
      await validateIosPodAvailability([
        NativeSdkDelta(
          sdk: NativeSdk.ios,
          targetVersion: null,
          files: [podspec],
        ),
        NativeSdkDelta(
          sdk: NativeSdk.ios,
          targetVersion: '3.20.0',
          files: [File('${root.path}/Package.swift')],
        ),
      ], lookup: lookup.call);
      verifyZeroInteractions(lookup);
    });
  });
}
