// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/src/rum/rum_long_task_observer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDdRum extends Mock implements DdRum {}

// These tests need to use testWidgets because the RumLongTaskObserver
// automatically registers itself to the WidgetsBindingInterface during init
void main() {
  Future<void> shutdownObserver(
      WidgetTester tester, RumLongTaskObserver observer) async {
    // Prevent timer pending exception
    await tester.runAsync(() async {
      unawaited(observer.stopLongTaskDetection());
    });
    await tester.pump(const Duration(milliseconds: 100));
    observer.dispose();
  }

  testWidgets('long task observer reports stall to rum instance',
      (tester) async {
    final mockRum = MockDdRum();
    final observer = RumLongTaskObserver(rumInstance: mockRum);
    observer.init();

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 200));

    verify(() => mockRum.reportLongTask(any()));

    await shutdownObserver(tester, observer);
  });

  testWidgets('long task observer does not report short delays',
      (tester) async {
    final mockRum = MockDdRum();
    final observer = RumLongTaskObserver(rumInstance: mockRum);
    observer.init();

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    });
    await tester.pump(const Duration(milliseconds: 50));

    verifyNever(() => mockRum.reportLongTask(any()));

    await shutdownObserver(tester, observer);
  });

  testWidgets('long task observer reports length of long task', (tester) async {
    final mockRum = MockDdRum();
    final observer = RumLongTaskObserver(rumInstance: mockRum);
    observer.init();

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 200));

    var captured = verify(() => mockRum.reportLongTask(captureAny()));
    expect(captured.captured[0], closeTo(100, 50));

    await shutdownObserver(tester, observer);
  });

  testWidgets('long task observer reports tasks longer than configured time',
      (tester) async {
    final mockRum = MockDdRum();
    final observer = RumLongTaskObserver(
      longTaskThreshold: 0.03,
      rumInstance: mockRum,
    );
    observer.init();

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 100));

    var captured = verify(() => mockRum.reportLongTask(captureAny()));
    expect(captured.captured[0], closeTo(50, 10));

    await shutdownObserver(tester, observer);
  });

  testWidgets(
      'long task observer does not report tasks shorter than configured time',
      (tester) async {
    final mockRum = MockDdRum();
    final observer = RumLongTaskObserver(
      longTaskThreshold: 0.2,
      rumInstance: mockRum,
    );
    observer.init();

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 250));

    verifyNever(() => mockRum.reportLongTask(any()));

    await shutdownObserver(tester, observer);
  });

  testWidgets('long task observer stops observing on app inactive',
      (tester) async {
    final mockRum = MockDdRum();
    final observer = RumLongTaskObserver(rumInstance: mockRum);
    observer.init();

    await tester.runAsync(() async {
      observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 200));

    verifyNever(() => mockRum.reportLongTask(any()));

    await shutdownObserver(tester, observer);
  });

  testWidgets('long task observer starts observing on app resumed',
      (tester) async {
    final mockRum = MockDdRum();
    final observer = RumLongTaskObserver(rumInstance: mockRum);
    observer.init();

    observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 200));

    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 200));

    verify(() => mockRum.reportLongTask(any())).called(1);

    await shutdownObserver(tester, observer);
  });
}
