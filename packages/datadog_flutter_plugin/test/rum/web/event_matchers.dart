// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:datadog_flutter_plugin/src/rum/web/raw_events.dart';
import 'package:flutter_test/flutter_test.dart';

/// Custom Equality matchers
Matcher equalsResourceEvent(Object object) {
  return _ResourceEventMatcher(object);
}

class _ResourceEventMatcher extends Matcher {
  final Object? _expected;

  _ResourceEventMatcher(this._expected);

  @override
  Description describe(Description description) {
    return description.addDescriptionOf(_expected);
  }

  @override
  bool matches(Object? actual, Map<dynamic, dynamic> matchState) {
    // ignore: invalid_runtime_check_with_js_interop_types
    if (_expected is! JSObject || actual is! JSObject) return false;

    final expectedResource = _expected as RumWebRawResourceEvent;
    final actualResource = actual as RumWebRawResourceEvent;

    StringBuffer mismatch = StringBuffer();

    _compareProperties(
      'date',
      expectedResource.date,
      actualResource.date,
      mismatch,
    );
    _compareProperties(
      'type',
      expectedResource.type,
      actualResource.type,
      mismatch,
    );
    _compareProperties(
      'resource.type',
      expectedResource.resource.type,
      actualResource.resource.type,
      mismatch,
    );
    _compareProperties(
      'resource.duration',
      expectedResource.resource.duration,
      actualResource.resource.duration,
      mismatch,
    );
    _compareProperties(
      'resource.url',
      expectedResource.resource.url,
      actualResource.resource.url,
      mismatch,
    );
    _compareProperties(
      'resource.method',
      expectedResource.resource.method,
      actualResource.resource.method,
      mismatch,
    );
    _compareProperties(
      'resource.statusCode',
      expectedResource.resource.statusCode,
      actualResource.resource.statusCode,
      mismatch,
    );
    _compareProperties(
      'resource.size',
      expectedResource.resource.size,
      actualResource.resource.size,
      mismatch,
    );
    _compareProperties(
      'resource.encodedBodySize',
      expectedResource.resource.encodedBodySize,
      actualResource.resource.encodedBodySize,
      mismatch,
    );
    _compareProperties(
      'resource.decodedBodySize',
      expectedResource.resource.decodedBodySize,
      actualResource.resource.decodedBodySize,
      mismatch,
    );
    _compareProperties(
      'resource.transferSize',
      expectedResource.resource.transferSize,
      actualResource.resource.transferSize,
      mismatch,
    );
    _compareProperties(
      'resource.renderBlockingStatus',
      expectedResource.resource.renderBlockingStatus,
      actualResource.resource.renderBlockingStatus,
      mismatch,
    );
    _compareProperties(
      'resource.protocol',
      expectedResource.resource.protocol,
      actualResource.resource.protocol,
      mismatch,
    );
    _compareContext(
      'context',
      expectedResource.context,
      actualResource.context,
      mismatch,
    );
    _compareProperties(
      'dd.discarded',
      expectedResource.dd.discarded,
      actualResource.dd.discarded,
      mismatch,
    );
    _compareProperties(
      'dd.traceId',
      expectedResource.dd.traceId,
      actualResource.dd.traceId,
      mismatch,
    );
    _compareProperties(
      'dd.spanId',
      expectedResource.dd.spanId,
      actualResource.dd.spanId,
      mismatch,
    );
    _compareProperties(
      'dd.rulePsr',
      expectedResource.dd.rulePsr,
      actualResource.dd.rulePsr,
      mismatch,
    );

    if (mismatch.isNotEmpty) {
      matchState['mismatch'] = mismatch.toString();
    }

    return mismatch.isEmpty;
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    Object? mismatch = matchState['mismatch'];
    if (mismatch is String) {
      mismatchDescription.add(mismatch);
    }
    return mismatchDescription;
  }
}

Matcher equalsContext(Object context) {
  return _ContextMatcher(context);
}

class _ContextMatcher extends Matcher {
  final Object? _expected;

  _ContextMatcher(this._expected);

  @override
  Description describe(Description description) {
    return description.addDescriptionOf(_expected);
  }

  @override
  bool matches(Object? actual, Map<dynamic, dynamic> matchState) {
    // ignore: invalid_runtime_check_with_js_interop_types
    if (_expected is! JSObject || actual is! JSObject) return false;

    StringBuffer mismatch = StringBuffer();

    _compareContext('context', _expected, actual, mismatch);

    return mismatch.isEmpty;
  }
}

void _compareProperties(
  String propertyName,
  Object? expected,
  Object? actual,
  StringBuffer mismatch,
) {
  if (expected != actual) {
    mismatch.writeln('$propertyName is $actual instead of $expected');
  }
}

void _compareContext(
  String propertyName,
  Object? expected,
  Object? actual,
  StringBuffer mismatch,
) {
  // ignore: invalid_runtime_check_with_js_interop_types
  if (expected is! JSObject) {
    mismatch.write('expected $propertyName is not a JSObject');
    return;
  }
  // ignore: invalid_runtime_check_with_js_interop_types
  if (actual is! JSObject) {
    mismatch.write('actual $propertyName is not a JSObject');
    return;
  }

  final expectedKeys = JSObjectUtil.keys(expected);
  final actualKeys = JSObjectUtil.keys(actual);

  if (expectedKeys.length != actualKeys.length) {
    mismatch.writeln(
      'expected $propertyName length is ${actualKeys.length} instead of ${expectedKeys.length}',
    );
  }

  for (int i = 0; i < expectedKeys.length; ++i) {
    final key = expectedKeys[i]!;
    final expectedValue = expected.getProperty(key);
    final actualValue = actual.getProperty(key);
    if (actualValue == null) {
      mismatch.writeln('expected $propertyName.$key is missing.');
      continue;
    }
    if (expectedValue != actualValue) {
      mismatch.writeln(
        '$propertyName.$key is $actualValue instead of $expectedValue.',
      );
    }
  }
}

@JS('Object')
extension type JSObjectUtil._(JSObject _jsObject) implements JSAny {
  external static JSArray keys(JSObject object);
}
