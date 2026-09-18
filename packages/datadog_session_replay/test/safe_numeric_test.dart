// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/extensions.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SafeDouble.safeRound', () {
    test('rounds finite values like double.round', () {
      expect((3.4).safeRound(), 3);
      expect((3.6).safeRound(), 4);
      expect((-3.6).safeRound(), -4);
      expect((0.0).safeRound(), 0);
    });

    test('returns the default fallback of 0 for non-finite values', () {
      expect(double.nan.safeRound(), 0);
      expect(double.infinity.safeRound(), 0);
      expect(double.negativeInfinity.safeRound(), 0);
    });

    test('returns the provided fallback for non-finite values', () {
      expect(double.nan.safeRound(10), 10);
      expect(double.infinity.safeRound(10), 10);
      expect(double.negativeInfinity.safeRound(-1), -1);
    });

    test('ignores the fallback for finite values', () {
      expect((42.2).safeRound(10), 42);
    });
  });

  group('CapturedViewAttributes bounds', () {
    test('rounds finite paint bounds', () {
      const attributes = CapturedViewAttributes(
        paintBounds: Rect.fromLTWH(10.4, 20.6, 30.5, 40.4),
        scaleX: 1.0,
        scaleY: 1.0,
      );

      expect(attributes.x, 10);
      expect(attributes.y, 21);
      expect(attributes.width, 31);
      expect(attributes.height, 40);
    });

    test('collapses NaN paint bounds to zero instead of throwing', () {
      const attributes = CapturedViewAttributes(
        paintBounds: Rect.fromLTRB(
          double.nan,
          double.nan,
          double.nan,
          double.nan,
        ),
        scaleX: 1.0,
        scaleY: 1.0,
      );

      expect(attributes.x, 0);
      expect(attributes.y, 0);
      expect(attributes.width, 0);
      expect(attributes.height, 0);
    });

    test('collapses infinite paint bounds to zero instead of throwing', () {
      const attributes = CapturedViewAttributes(
        paintBounds: Rect.fromLTWH(0, 0, double.infinity, double.infinity),
        scaleX: 1.0,
        scaleY: 1.0,
      );

      expect(attributes.width, 0);
      expect(attributes.height, 0);
    });
  });

  group('finiteLayoutScale', () {
    test('returns the ratio for finite, non-zero inputs', () {
      expect(finiteLayoutScale(10, 5), 2.0);
      expect(finiteLayoutScale(5, 10), 0.5);
    });

    test('returns 1.0 when the denominator is zero', () {
      expect(finiteLayoutScale(10, 0), 1.0);
    });

    test('returns 1.0 when the numerator is non-finite', () {
      expect(finiteLayoutScale(double.nan, 5), 1.0);
      expect(finiteLayoutScale(double.infinity, 5), 1.0);
      expect(finiteLayoutScale(double.nan, double.nan), 1.0);
    });

    test('returns 0.0 when only the denominator is non-finite', () {
      expect(finiteLayoutScale(10, double.infinity), 0.0);
    });

    test('returns 0.0 when the ratio overflows to non-finite', () {
      expect(finiteLayoutScale(1e308, 1e-300), 0.0);
    });
  });

  group('SRShapeStyle cornerRadius', () {
    test('keeps finite corner radii', () {
      expect(SRShapeStyle(cornerRadius: 4.0).cornerRadius, 4.0);
      expect(SRShapeStyle().cornerRadius, 0.0);
    });

    test('clamps non-finite corner radii to zero', () {
      expect(SRShapeStyle(cornerRadius: double.nan).cornerRadius, 0.0);
      expect(SRShapeStyle(cornerRadius: double.infinity).cornerRadius, 0.0);
      expect(
        SRShapeStyle(cornerRadius: double.negativeInfinity).cornerRadius,
        0.0,
      );
    });
  });
}
