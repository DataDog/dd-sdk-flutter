// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// ignore_for_file: deprecated_member_use_from_same_package

import 'package:datadog_flutter_plugin/src/internal_logger.dart';
import 'package:datadog_flutter_plugin/src/traces/ddtraces.dart';
import 'package:datadog_flutter_plugin/src/traces/ddtraces_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakeDdSpan extends Fake implements DdSpan {}

class MockTracesPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DdTracesPlatform {}

void main() {
  late MockTracesPlatform mockPlatform;

  setUpAll(() {
    registerFallbackValue(FakeDdSpan());
  });

  setUp(() {
    mockPlatform = MockTracesPlatform();
    DdTracesPlatform.instance = mockPlatform;
    when(() => mockPlatform.startSpan(any(), any(), any(), any(), any(), any()))
        .thenAnswer((invocation) => Future.value(true));
    when(() => mockPlatform.spanSetError(any(), any(), any(), any()))
        .thenAnswer((invocation) => Future.value());
    when(() => mockPlatform.spanCancel(any()))
        .thenAnswer((invocation) => Future.value());
  });

  test('setError passes null stack trace by default', () async {
    final traces = DdTraces(InternalLogger());

    final span = traces.startSpan('span operation');
    final exception = Exception('my message');
    span.setError(exception);

    verify(() => mockPlatform.spanSetError(
        span, exception.runtimeType.toString(), exception.toString(), null));
  });

  test('setError passes stack trace string to platform', () async {
    final traces = DdTraces(InternalLogger());

    final span = traces.startSpan('span operation');
    final exception = Exception('my message');
    final st = StackTrace.current;
    span.setError(exception, st);

    verify(() => mockPlatform.spanSetError(
        span,
        exception.runtimeType.toString(),
        exception.toString(),
        any<String>(that: isNotNull)));
  });

  test('setErrorInfo passes null stack trace by default', () async {
    final traces = DdTraces(InternalLogger());

    final span = traces.startSpan('span operation');
    span.setErrorInfo('kind', 'my message');

    verify(() => mockPlatform.spanSetError(span, 'kind', 'my message', null));
  });

  test('setErrorInfo passes stack trace string to platform', () async {
    final traces = DdTraces(InternalLogger());

    final span = traces.startSpan('span operation');
    final st = StackTrace.current;
    span.setErrorInfo('kind', 'my message', st);

    verify(() => mockPlatform.spanSetError(
        span, 'kind', 'my message', any<String>(that: isNotNull)));
  });

  test('cancel calls through to platform', () async {
    final traces = DdTraces(InternalLogger());

    final span = traces.startSpan('span operation');
    final spanHandle = span.handle;
    span.cancel();

    verify(() => mockPlatform.spanCancel(spanHandle));
  });
}
