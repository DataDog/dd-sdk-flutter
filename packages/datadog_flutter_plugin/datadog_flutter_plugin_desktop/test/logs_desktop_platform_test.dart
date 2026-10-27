// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:ffi' as ffi;

import 'package:datadog_flutter_plugin_desktop/src/ffi_bindings.dart';
import 'package:datadog_flutter_plugin_desktop/src/logs_desktop_platform.dart';
import 'package:datadog_flutter_plugin_platform_interface/datadog_flutter_plugin_platform_interface.dart';
import 'package:datadog_flutter_plugin_platform_interface/datadog_internal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'ffi_test_helpers.dart';

class MockSdkFfi extends Mock implements DdSdkFfi {}

/// What the plugin passed to `dd_logger_log`.
class _LoggedCall {
  final int level;
  final String? message;
  final ({String? message, String? kind, String? stack})? error;
  final bool hasAttributes;

  _LoggedCall(this.level, this.message, this.error, this.hasAttributes);
}

const nativeLevels = {
  LogLevel.debug: dd_log_level_t.DD_LOG_LEVEL_DEBUG,
  LogLevel.info: dd_log_level_t.DD_LOG_LEVEL_INFO,
  LogLevel.notice: dd_log_level_t.DD_LOG_LEVEL_NOTICE,
  LogLevel.warning: dd_log_level_t.DD_LOG_LEVEL_WARN,
  LogLevel.error: dd_log_level_t.DD_LOG_LEVEL_ERROR,
  LogLevel.critical: dd_log_level_t.DD_LOG_LEVEL_CRITICAL,
  LogLevel.alert: dd_log_level_t.DD_LOG_LEVEL_CRITICAL,
  LogLevel.emergency: dd_log_level_t.DD_LOG_LEVEL_CRITICAL,
};

void main() {
  late MockSdkFfi sdk;
  late DdLogsDesktopPlatform platform;
  final logging = ffi.Pointer<dd_logging>.fromAddress(1);
  var nextLoggerAddress = 100;

  setUpAll(() {
    registerFallbackValue(ffi.nullptr.cast<dd_logger_config_t>());
    registerFallbackValue(ffi.nullptr.cast<dd_logging_t>());
    registerFallbackValue(ffi.nullptr.cast<dd_logger_t>());
    registerFallbackValue(ffi.nullptr.cast<dd_attribute_t>());
    registerFallbackValue(ffi.nullptr.cast<dd_log_error_t>());
    registerFallbackValue(ffi.nullptr.cast<ffi.Char>());
  });

  setUp(() {
    sdk = MockSdkFfi();
    platform = DdLogsDesktopPlatform(sdk, logging);
    when(() => sdk.dd_logger_create(any(), any())).thenAnswer(
      (_) => ffi.Pointer<dd_logger_t>.fromAddress(nextLoggerAddress++),
    );
  });

  /// Creates a logger under [handle] and returns the native logger it maps to.
  Future<ffi.Pointer<dd_logger_t>> createLogger([
    String handle = 'logger',
  ]) async {
    final logger = ffi.Pointer<dd_logger_t>.fromAddress(nextLoggerAddress);
    await platform.createLogger(handle, DatadogLoggerConfiguration());
    return logger;
  }

  group('createLogger', () {
    for (final rate in [0.0, 25.0, 50.0, 100.0]) {
      test(
        'passes 100.0 to the native logger for remoteSampleRate $rate',
        () async {
          await platform.createLogger(
            'handle',
            DatadogLoggerConfiguration(remoteSampleRate: rate),
          );

          verify(
            () => sdk.dd_logger_config_set_remote_sample_rate(any(), 100.0),
          ).called(1);
        },
      );
    }

    test('creates the native logger on the logging feature', () async {
      await platform.createLogger('handle', DatadogLoggerConfiguration());

      verify(() => sdk.dd_logger_config_init(any())).called(1);
      verify(() => sdk.dd_logger_create(logging, any())).called(1);
    });

    test('passes service and name to the native logger', () async {
      final received = <String>[];
      when(() => sdk.dd_logger_config_set_service(any(), any())).thenAnswer(
        (invocation) => received.add(
          'service=${nativeString(invocation.positionalArguments[1])}',
        ),
      );
      when(() => sdk.dd_logger_config_set_name(any(), any())).thenAnswer(
        (invocation) => received.add(
          'name=${nativeString(invocation.positionalArguments[1])}',
        ),
      );

      await platform.createLogger(
        'handle',
        DatadogLoggerConfiguration(service: 'my-service', name: 'my-logger'),
      );

      expect(received, ['service=my-service', 'name=my-logger']);
    });

    test('does not set service or name when unset', () async {
      await platform.createLogger('handle', DatadogLoggerConfiguration());

      verifyNever(() => sdk.dd_logger_config_set_service(any(), any()));
      verifyNever(() => sdk.dd_logger_config_set_name(any(), any()));
    });

    for (final MapEntry(key: level, value: native) in nativeLevels.entries) {
      test('maps remoteLogThreshold $level to the native level', () async {
        await platform.createLogger(
          'handle',
          DatadogLoggerConfiguration(remoteLogThreshold: level),
        );

        verify(
          () => sdk.dd_logger_config_set_remote_log_threshold(any(), native),
        ).called(1);
      });
    }

    for (final enabled in [true, false]) {
      test('forwards bundleWithRumEnabled = $enabled', () async {
        await platform.createLogger(
          'handle',
          DatadogLoggerConfiguration(bundleWithRumEnabled: enabled),
        );

        verify(
          () =>
              sdk.dd_logger_config_set_enrich_with_rum_context(any(), enabled),
        ).called(1);
      });
    }

    test('does nothing after deinitialize', () async {
      await platform.deinitialize();

      await platform.createLogger('handle', DatadogLoggerConfiguration());

      verifyNever(() => sdk.dd_logger_create(any(), any()));
    });
  });

  group('destroyLogger', () {
    test('destroys the native logger for the handle', () async {
      final logger = await createLogger('a');

      await platform.destroyLogger('a');

      verify(() => sdk.dd_logger_destroy(logger)).called(1);
    });

    test('ignores unknown handles', () async {
      await platform.destroyLogger('missing');

      verifyNever(() => sdk.dd_logger_destroy(any()));
    });

    test('destroys a logger only once', () async {
      await createLogger('a');

      await platform.destroyLogger('a');
      await platform.destroyLogger('a');

      verify(() => sdk.dd_logger_destroy(any())).called(1);
    });
  });

  group('deinitialize', () {
    test('destroys every logger, then the logging feature', () async {
      final a = await createLogger('a');
      final b = await createLogger('b');

      await platform.deinitialize();

      verifyInOrder([
        () => sdk.dd_logger_destroy(a),
        () => sdk.dd_logger_destroy(b),
        () => sdk.dd_logging_destroy(logging),
      ]);
    });

    test('is safe to call twice', () async {
      await platform.deinitialize();
      await platform.deinitialize();

      verify(() => sdk.dd_logging_destroy(logging)).called(1);
    });

    test('stops loggers from being used', () async {
      await createLogger('a');
      await platform.deinitialize();

      await platform.addTag('a', 'tag');
      await platform.log('a', LogLevel.info, 'message', null, null, null, {});

      verifyNever(() => sdk.dd_logger_add_tag(any(), any()));
      verifyNever(() => sdk.dd_logger_log(any(), any(), any(), any(), any()));
    });
  });

  group('log', () {
    late List<_LoggedCall> calls;
    late List<String?> attributeKeys;
    late List<String?> attributeStrings;

    setUp(() {
      calls = [];
      attributeKeys = [];
      attributeStrings = [];
      when(
        () => sdk.dd_logger_log(any(), any(), any(), any(), any()),
      ).thenAnswer((invocation) {
        final args = invocation.positionalArguments;
        final err = args[3] as ffi.Pointer<dd_log_error_t>;
        calls.add(
          _LoggedCall(
            args[1] as int,
            nativeString(args[2]),
            err.address == 0
                ? null
                : (
                    message: nativeString(err.ref.message),
                    kind: nativeString(err.ref.kind),
                    stack: nativeString(err.ref.stack),
                  ),
            (args[4] as ffi.Pointer).address != 0,
          ),
        );
      });
      when(
        () => sdk.dd_attribute_object_property_set(any(), any(), any()),
      ).thenAnswer((invocation) {
        attributeKeys.add(nativeString(invocation.positionalArguments[1]));
      });
      when(() => sdk.dd_attribute_set_string(any(), any())).thenAnswer((
        invocation,
      ) {
        attributeStrings.add(nativeString(invocation.positionalArguments[1]));
      });
    });

    for (final MapEntry(key: level, value: native) in nativeLevels.entries) {
      test('maps $level to the native level', () async {
        await createLogger();

        await platform.log('logger', level, 'message', null, null, null, {});

        expect(calls.single.level, native);
      });
    }

    test('sends to the native logger for the handle', () async {
      final logger = await createLogger('a');

      await platform.log('a', LogLevel.info, 'hello', null, null, null, {});

      verify(
        () => sdk.dd_logger_log(logger, any(), any(), any(), any()),
      ).called(1);
      expect(calls.single.message, 'hello');
    });

    test('ignores unknown handles', () async {
      await platform.log('missing', LogLevel.info, 'hi', null, null, null, {});

      expect(calls, isEmpty);
    });

    test('passes no error or attributes when there are none', () async {
      await createLogger();

      await platform.log('logger', LogLevel.info, 'hi', null, null, null, {});

      expect(calls.single.error, isNull);
      expect(calls.single.hasAttributes, isFalse);
    });

    test('passes error details', () async {
      await createLogger();
      final stack = StackTrace.fromString('the stack');

      await platform.log(
        'logger',
        LogLevel.error,
        'hi',
        'bad thing',
        'BadError',
        stack,
        {},
      );

      expect(calls.single.error, (
        message: 'bad thing',
        kind: 'BadError',
        stack: 'the stack',
      ));
    });

    test('passes an error that has only a message', () async {
      await createLogger();

      await platform.log(
        'logger',
        LogLevel.error,
        'hi',
        'bad thing',
        null,
        null,
        {},
      );

      expect(calls.single.error, (
        message: 'bad thing',
        kind: null,
        stack: null,
      ));
    });

    test('passes attributes', () async {
      await createLogger();

      await platform.log('logger', LogLevel.info, 'hi', null, null, null, {
        'first': 'one',
        'second': 2,
      });

      expect(calls.single.hasAttributes, isTrue);
      expect(attributeKeys, ['first', 'second']);
      verify(() => sdk.dd_attribute_set_int(any(), 2)).called(1);
      expect(attributeStrings, ['one']);
    });

    test(
      'tags the error source as flutter when there is a stack trace',
      () async {
        await createLogger();

        await platform.log(
          'logger',
          LogLevel.error,
          'hi',
          'bad thing',
          null,
          StackTrace.fromString('the stack'),
          {'custom': 'value'},
        );

        expect(attributeKeys, [
          DatadogPlatformAttributeKey.errorSourceType,
          'custom',
        ]);
        expect(attributeStrings, ['flutter', 'value']);
      },
    );

    test('does not tag the error source without a stack trace', () async {
      await createLogger();

      await platform.log(
        'logger',
        LogLevel.error,
        'hi',
        'bad thing',
        null,
        null,
        {},
      );

      expect(calls.single.hasAttributes, isFalse);
    });
  });

  group('attributes', () {
    test('adds a global attribute to the logging feature', () async {
      String? name;
      when(() => sdk.dd_logging_add_attribute(any(), any(), any())).thenAnswer((
        invocation,
      ) {
        name = nativeString(invocation.positionalArguments[1]);
      });

      await platform.addGlobalAttribute('key', 'value');

      expect(name, 'key');
      verify(() => sdk.dd_attribute_set_string(any(), any())).called(1);
    });

    test('removes a global attribute from the logging feature', () async {
      String? name;
      when(() => sdk.dd_logging_remove_attribute(any(), any())).thenAnswer((
        invocation,
      ) {
        name = nativeString(invocation.positionalArguments[1]);
      });

      await platform.removeGlobalAttribute('key');

      expect(name, 'key');
      verify(() => sdk.dd_logging_remove_attribute(logging, any())).called(1);
    });

    test('global attributes are ignored after deinitialize', () async {
      await platform.deinitialize();

      await platform.addGlobalAttribute('key', 'value');
      await platform.removeGlobalAttribute('key');

      verifyNever(() => sdk.dd_logging_add_attribute(any(), any(), any()));
      verifyNever(() => sdk.dd_logging_remove_attribute(any(), any()));
    });

    test('adds a logger attribute to the logger for the handle', () async {
      final logger = await createLogger('a');
      String? name;
      when(() => sdk.dd_logger_add_attribute(any(), any(), any())).thenAnswer((
        invocation,
      ) {
        name = nativeString(invocation.positionalArguments[1]);
      });

      await platform.addAttribute('a', 'key', 42);

      expect(name, 'key');
      verify(() => sdk.dd_logger_add_attribute(logger, any(), any())).called(1);
      verify(() => sdk.dd_attribute_set_int(any(), 42)).called(1);
    });

    test('removes a logger attribute from the logger for the handle', () async {
      final logger = await createLogger('a');
      String? name;
      when(() => sdk.dd_logger_remove_attribute(any(), any())).thenAnswer((
        invocation,
      ) {
        name = nativeString(invocation.positionalArguments[1]);
      });

      await platform.removeAttribute('a', 'key');

      expect(name, 'key');
      verify(() => sdk.dd_logger_remove_attribute(logger, any())).called(1);
    });

    test('logger attributes are ignored for unknown handles', () async {
      await platform.addAttribute('missing', 'key', 1);
      await platform.removeAttribute('missing', 'key');

      verifyNever(() => sdk.dd_logger_add_attribute(any(), any(), any()));
      verifyNever(() => sdk.dd_logger_remove_attribute(any(), any()));
    });
  });

  group('tags', () {
    test('adds a tag without a value', () async {
      final logger = await createLogger('a');
      String? tag;
      when(() => sdk.dd_logger_add_tag(any(), any())).thenAnswer((invocation) {
        tag = nativeString(invocation.positionalArguments[1]);
      });

      await platform.addTag('a', 'env');

      expect(tag, 'env');
      verify(() => sdk.dd_logger_add_tag(logger, any())).called(1);
      verifyNever(() => sdk.dd_logger_add_tag_kv(any(), any(), any()));
    });

    test('adds a tag with a value as a key and value', () async {
      final logger = await createLogger('a');
      final received = <String?>[];
      when(() => sdk.dd_logger_add_tag_kv(any(), any(), any())).thenAnswer((
        invocation,
      ) {
        received.addAll([
          nativeString(invocation.positionalArguments[1]),
          nativeString(invocation.positionalArguments[2]),
        ]);
      });

      await platform.addTag('a', 'env', 'prod');

      expect(received, ['env', 'prod']);
      verify(() => sdk.dd_logger_add_tag_kv(logger, any(), any())).called(1);
      verifyNever(() => sdk.dd_logger_add_tag(any(), any()));
    });

    test('removes a tag', () async {
      final logger = await createLogger('a');
      String? tag;
      when(() => sdk.dd_logger_remove_tag(any(), any())).thenAnswer((
        invocation,
      ) {
        tag = nativeString(invocation.positionalArguments[1]);
      });

      await platform.removeTag('a', 'env:prod');

      expect(tag, 'env:prod');
      verify(() => sdk.dd_logger_remove_tag(logger, any())).called(1);
    });

    test('removes tags by key', () async {
      final logger = await createLogger('a');
      String? key;
      when(() => sdk.dd_logger_remove_tags_with_key(any(), any())).thenAnswer((
        invocation,
      ) {
        key = nativeString(invocation.positionalArguments[1]);
      });

      await platform.removeTagWithKey('a', 'env');

      expect(key, 'env');
      verify(() => sdk.dd_logger_remove_tags_with_key(logger, any())).called(1);
    });

    test('tag operations are ignored for unknown handles', () async {
      await platform.addTag('missing', 'env');
      await platform.addTag('missing', 'env', 'prod');
      await platform.removeTag('missing', 'env');
      await platform.removeTagWithKey('missing', 'env');

      verifyNever(() => sdk.dd_logger_add_tag(any(), any()));
      verifyNever(() => sdk.dd_logger_add_tag_kv(any(), any(), any()));
      verifyNever(() => sdk.dd_logger_remove_tag(any(), any()));
      verifyNever(() => sdk.dd_logger_remove_tags_with_key(any(), any()));
    });
  });
}
