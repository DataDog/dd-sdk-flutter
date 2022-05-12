// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:io';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/src/internal_logger.dart';
import 'package:datadog_flutter_plugin/src/rum/ddrum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const numSamples = 500;

  test('RumResourceType parses simple mimeTypes from ContentType', () {
    final image = ContentType.parse('image/png');
    expect(resourceTypeFromContentType(image), RumResourceType.image);

    final video = ContentType.parse('video/mp4');
    expect(resourceTypeFromContentType(video), RumResourceType.media);

    final audio = ContentType.parse('audio/ogg');
    expect(resourceTypeFromContentType(audio), RumResourceType.media);

    final appJavascript = ContentType.parse('application/javascript');
    expect(resourceTypeFromContentType(appJavascript), RumResourceType.js);

    final textJavascript = ContentType.parse('text/javascript');
    expect(resourceTypeFromContentType(textJavascript), RumResourceType.js);

    final font = ContentType.parse('font/collection');
    expect(resourceTypeFromContentType(font), RumResourceType.font);

    final css = ContentType.parse('text/css');
    expect(resourceTypeFromContentType(css), RumResourceType.css);

    final other = ContentType.parse('application/octet-stream');
    expect(resourceTypeFromContentType(other), RumResourceType.native);
  });

  test('Session sampling rate is clamped to 0..100', () {
    final lowConfiguration = RumConfiguration(
      applicationId: 'applicationId',
      sessionSamplingRate: -12.3,
    );

    final highConfiguration = RumConfiguration(
      applicationId: 'applicationId',
      sessionSamplingRate: 137.2,
    );

    expect(lowConfiguration.sessionSamplingRate, equals(0.0));
    expect(highConfiguration.sessionSamplingRate, equals(100.0));
  });

  test('Tracing sampling rate is clamped to 0..100', () {
    final lowConfiguration = RumConfiguration(
      applicationId: 'applicationId',
      tracingSamplingRate: -12.3,
    );

    final highConfiguration = RumConfiguration(
      applicationId: 'applicationId',
      tracingSamplingRate: 137.2,
    );

    expect(lowConfiguration.tracingSamplingRate, equals(0.0));
    expect(highConfiguration.tracingSamplingRate, equals(100.0));
  });

  test('Setting trace sample rate to 100 should always sample', () {
    final rumConfiguration = RumConfiguration(
      applicationId: 'applicationId',
      tracingSamplingRate: 100,
    );
    final internalLogger = InternalLogger();
    final rum = DdRum(rumConfiguration, internalLogger);

    for (int i = 0; i < 10; ++i) {
      expect(rum.shouldSampleTrace(), isTrue);
    }
  });

  test('Setting trace sample rate to 0 should never sample', () {
    final rumConfiguration = RumConfiguration(
      applicationId: 'applicationId',
      tracingSamplingRate: 0,
    );
    final internalLogger = InternalLogger();
    final rum = DdRum(rumConfiguration, internalLogger);

    for (int i = 0; i < 10; ++i) {
      expect(rum.shouldSampleTrace(), isFalse);
    }
  });

  test('Low sampling rate returns samples less often', () {
    final rumConfiguration = RumConfiguration(
      applicationId: 'applicationId',
      tracingSamplingRate: 23,
    );
    final internalLogger = InternalLogger();
    final rum = DdRum(rumConfiguration, internalLogger);

    var sampleCount = 0;
    var noSampleCount = 0;
    for (int i = 0; i < numSamples; ++i) {
      if (rum.shouldSampleTrace()) {
        sampleCount++;
      } else {
        noSampleCount++;
      }
    }

    expect(noSampleCount, greaterThanOrEqualTo(sampleCount));
    expect(sampleCount, greaterThanOrEqualTo(1));
  });

  test('High sampling rate returns samples more often', () {
    final rumConfiguration = RumConfiguration(
      applicationId: 'applicationId',
      tracingSamplingRate: 85,
    );
    final internalLogger = InternalLogger();
    final rum = DdRum(rumConfiguration, internalLogger);

    var sampleCount = 0;
    var noSampleCount = 0;
    for (int i = 0; i < numSamples; ++i) {
      if (rum.shouldSampleTrace()) {
        sampleCount++;
      } else {
        noSampleCount++;
      }
    }

    expect(sampleCount, greaterThanOrEqualTo(noSampleCount));
    expect(noSampleCount, greaterThanOrEqualTo(1));
  });
}
