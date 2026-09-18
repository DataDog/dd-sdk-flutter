// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

import '../datadog_flutter_plugin.dart';

String siteStringForSite(DatadogSite? site) {
  switch (site) {
    case DatadogSite.us1:
      return 'datadoghq.com';
    case DatadogSite.us3:
      return 'us3.datadoghq.com';
    case DatadogSite.us5:
      return 'us5.datadoghq.com';
    case DatadogSite.eu1:
      return 'datadoghq.eu';
    case DatadogSite.us1Fed:
      return 'ddog-gov.com';
    case DatadogSite.ap1:
      return 'ap1.datadoghq.com';
    case DatadogSite.ap2:
      return 'ap2.datadoghq.com';
    default:
      return 'datadoghq.com';
  }
}

dynamic attributesToJs(Map<String, Object?> attributes, String parameterName) {
  return valueToJs(attributes, parameterName);
}

JSAny? valueToJs(Object? value, String parameterName) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.toJS;
  }

  if (value is bool) {
    return value.toJS;
  }

  if (value is String) {
    return value.toJS;
  }

  if (value is Map) {
    final jsMap = JSObject();
    for (final item in value.entries) {
      String key = item.key is String ? item.key : item.key.toString();
      jsMap.setProperty(
        key.toJS,
        valueToJs(item.value, '$parameterName.${item.key}'),
      );
    }
    return jsMap;
  }

  if (value is List) {
    final jsArray = JSArray<JSAny?>();
    for (int i = 0; i < value.length; ++i) {
      // Indexing operations on JSArray in js_interop weren't added until Dart 3.6
      // and a properly supported `add` method wasn't added until Dart 3.10, so
      // call `push` directly to create the array.
      jsArray.callMethod(
        'push'.toJS,
        valueToJs(value[i], '$parameterName[$i]'),
      );
    }
    return jsArray;
  }

  throw ArgumentError(
    'Could not convert ${value.runtimeType} to javascript.',
    parameterName,
  );
}

// Regex specifying the format of a frame in a Dart stack trace.
final _dartLineRegex = RegExp(
  r'(?<file>.+) (?<location>\d+:\d+)\s*(?<function>.+)',
);

@JS('RegExp')
extension type JSRegExp._(JSObject _) implements JSObject {
  external factory JSRegExp([String? pattern, String? flags]);
}

String? convertWebStackTrace(StackTrace? stackTrace) {
  if (stackTrace == null) return null;

  var stackTraceString = stackTrace.toString();
  if (kDebugMode) {
    // Datadog Browser SDK parses the stack trace looking for specific
    // formats. When deployed, the Dart's StackTrace.toString will
    // correctly output a JS compatible stack trace. When not deployed,
    // we reformat so that it puts something in Datadog logging.
    var sb = StringBuffer();
    for (var line in stackTraceString.split('\n')) {
      var match = _dartLineRegex.firstMatch(line);
      if (match != null) {
        final file = match.namedGroup('file');
        final location = match.namedGroup('location');
        final function = match.namedGroup('function');
        sb.writeln('  at $function (file://$file:$location) ');
      }
    }
    stackTraceString = sb.toString();
  }

  return stackTraceString;
}

extension TrackingConsentWebValue on TrackingConsent {
  String webValue() {
    switch (this) {
      case TrackingConsent.granted:
        return 'granted';
      case TrackingConsent.notGranted:
      case TrackingConsent.pending:
        return 'not-granted';
    }
  }
}

extension SessionPersistenceWebValue on WebSessionPersistence {
  String webValue() {
    switch (this) {
      case WebSessionPersistence.cookie:
        return 'cookie';
      case WebSessionPersistence.localStorage:
        return 'local-storage';
    }
  }
}
