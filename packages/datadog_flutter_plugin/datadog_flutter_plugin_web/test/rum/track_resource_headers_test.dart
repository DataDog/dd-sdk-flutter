// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.
// ignore: library_annotations
@TestOn('browser')
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:datadog_flutter_plugin_platform_interface/datadog_flutter_plugin_platform_interface.dart';
import 'package:datadog_flutter_plugin_web/src/rum/ddrum_web.dart';
import 'package:flutter_test/flutter_test.dart';

List<JSObject> _matchers(JSAny? value) {
  return (value as JSArray<JSObject>).toDart;
}

String? _name(JSObject matcher) {
  return (matcher.getProperty<JSString?>('name'.toJS))?.toDart;
}

void main() {
  group('convertTrackResourceHeaders', () {
    test('returns true when only defaults are captured', () {
      final result = convertTrackResourceHeaders(ResourceHeadersExtractor());
      final resultWithForbiddenHeader = convertTrackResourceHeaders(
        ResourceHeadersExtractor(captureHeaders: ['authorization']),
      );

      expect((result as JSBoolean).toDart, isTrue);
      expect((resultWithForbiddenHeader as JSBoolean).toDart, isTrue);
    });

    test('returns a default matcher followed by custom headers', () {
      final result = convertTrackResourceHeaders(
        ResourceHeadersExtractor(captureHeaders: ['X-Custom']),
      );

      final matchers = _matchers(result);
      expect(matchers.map(_name), [null, 'x-custom']);
      expect(
        matchers.any((m) => m.hasProperty('location'.toJS).toDart),
        isFalse,
      );
    });

    test('returns only custom headers when defaults are excluded', () {
      final result = convertTrackResourceHeaders(
        ResourceHeadersExtractor(
          includeDefaults: false,
          captureHeaders: ['x-custom', 'authorization'],
        ),
      );

      expect(_matchers(result).map(_name), ['x-custom']);
    });

    test('returns null when no header can be captured', () {
      expect(convertTrackResourceHeaders(null), isNull);
      expect(
        convertTrackResourceHeaders(
          ResourceHeadersExtractor(
            includeDefaults: false,
            captureHeaders: ['authorization'],
          ),
        ),
        isNull,
      );
    });
  });
}
