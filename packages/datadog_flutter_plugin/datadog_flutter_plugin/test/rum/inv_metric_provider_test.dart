// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/src/rum/inv_metric_provider.dart';
import 'package:datadog_flutter_plugin/src/rum/rum.dart';
import 'package:flutter_test/flutter_test.dart';

const defaultFirstBuildTime = Duration(milliseconds: 38);

void main() {
  final baseStartTime = DateTime.now();

  group('inv metric provider', () {
    test('null value for unknown view', () {
      // Given
      final provider = InvMetricProvider();

      // When
      final value = provider.valueForView('unknown');

      // Then
      expect(value, isNull);
    });

    test('null value for view with no previous view', () {
      // Given
      final provider = InvMetricProvider();
      startView(provider, 'view1', baseStartTime);

      // When
      final value = provider.valueForView('view1');

      // Then
      expect(value, isNull);
    });

    test('null value for view with previous view with no actions', () {
      // Given
      final provider = InvMetricProvider();
      startView(provider, 'view1', baseStartTime);
      final secondViewStart = baseStartTime.add(
        const Duration(minutes: 1, seconds: 10),
      );
      startView(provider, 'view2', secondViewStart);

      // When
      final value = provider.valueForView('view2');

      // Then
      expect(value, isNull);
    });

    test('provides value for inv when action on previous view', () {
      // Given
      final provider = InvMetricProvider();
      startView(provider, 'view1', baseStartTime);
      final actionTime = baseStartTime.add(const Duration(seconds: 4));
      final nextViewTime = actionTime.add(const Duration(milliseconds: 10));
      provider.trackAction('view1', actionTime, RumActionType.tap);
      startView(provider, 'view2', nextViewTime);

      // When
      final value = provider.valueForView('view2');

      // Then
      final expectedValue = Duration(
        milliseconds: 10 + defaultFirstBuildTime.inMilliseconds,
      ).inNanoseconds;
      expect(value, expectedValue);
    });

    test('null value when lacking FBC', () {
      // Given
      final provider = InvMetricProvider();
      startView(provider, 'view1', baseStartTime);
      final actionTime = baseStartTime.add(Duration(seconds: 4));
      final nextViewTime = actionTime.add(Duration(milliseconds: 10));
      provider.trackAction('view1', actionTime, RumActionType.tap);
      provider.trackViewStart('view2', nextViewTime);

      // When
      final value = provider.valueForView('view2');

      // Then
      expect(value, isNull);
    });

    test('provides value for last action on previous view', () {
      // Given
      final provider = InvMetricProvider();
      startView(provider, 'view1', baseStartTime);
      final actionTime = baseStartTime.add(const Duration(seconds: 4));
      final stopTime = actionTime.add(const Duration(milliseconds: 10));
      final nextViewTime = stopTime.add(const Duration(milliseconds: 10));
      provider.trackAction('view1', actionTime, RumActionType.tap);
      provider.trackViewStop('view1', stopTime);
      startView(provider, 'view2', nextViewTime);

      // When
      final value = provider.valueForView('view2');

      // Then
      final expectedValue = Duration(
        milliseconds: 20 + defaultFirstBuildTime.inMilliseconds,
      ).inNanoseconds;
      expect(value, expectedValue);
    });

    test('null value when action is older than tolerance', () {
      // Given
      final provider = InvMetricProvider();
      startView(provider, 'view1', baseStartTime);
      final actionTime = baseStartTime.add(const Duration(seconds: 5));
      final nextViewTime = actionTime.add(
        Duration(seconds: (defaultMaxTimeToNextView + 1).toInt()),
      );
      provider.trackAction('view1', actionTime, RumActionType.tap);
      startView(provider, 'view2', nextViewTime);

      // When
      final value = provider.valueForView('view2');

      // Then
      expect(value, isNull);
    });

    test('provides value when previous view manually stopped', () {
      // Given
      final provider = InvMetricProvider();
      startView(provider, 'view1', baseStartTime);
      final actionTime = baseStartTime.add(const Duration(seconds: 5));
      final nextViewTime = actionTime.add(
        Duration(seconds: (defaultMaxTimeToNextView + 1).toInt()),
      );
      provider.trackAction('view1', actionTime, RumActionType.tap);
      startView(provider, 'view2', nextViewTime);

      // When
      final value = provider.valueForView('view2');

      // Then
      expect(value, isNull);
    });

    test(
      'null value when previous view has no actions {older view exists}',
      () {
        // Given
        final provider = InvMetricProvider();
        startView(provider, 'view1', baseStartTime);
        final actionTime = baseStartTime.add(Duration(seconds: 5));
        final secondViewTime = actionTime.add(
          Duration(seconds: (defaultMaxTimeToNextView + 1).toInt()),
        );
        provider.trackAction('view1', actionTime, RumActionType.tap);
        startView(provider, 'view2', secondViewTime);
        final thirdViewTime = secondViewTime.add(const Duration(seconds: 1));
        startView(provider, 'view3', thirdViewTime);

        // When
        final value = provider.valueForView('view3');

        // Then
        expect(value, isNull);
      },
    );
  });
}

// Helper methods
void startView(
  InvMetricProvider provider,
  String viewKey,
  DateTime startTime, {
  Duration firstBuildCompleteTime = defaultFirstBuildTime,
}) {
  provider.trackViewStart(viewKey, startTime);
  final firstBuildComplete = startTime.add(firstBuildCompleteTime);
  provider.trackViewFirstBuildComplete(viewKey, firstBuildComplete);
}
