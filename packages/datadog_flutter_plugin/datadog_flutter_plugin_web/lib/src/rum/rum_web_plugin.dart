// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:js_interop';

import 'package:web/web.dart';

import 'raw_events.dart';

/// Mirrors the `RumPlugin` interface from the Datadog Browser SDK:
/// https://github.com/DataDog/browser-sdk/blob/bd6074ff1f33cb0b94acf7b6b7eae95180271475/packages/rum-core/src/domain/plugins.ts#L30
///
/// Keep this class updated to match the original interface.
@JSExport()
abstract interface class RumWebPlugin {
  String get name;

  /// Get configuration information about how the SDK is set up to
  /// send to telemetry.
  ///
  /// This should return a typescript Record%lt;String, JSAny%gt;
  JSObject getConfigurationTelemetry() {
    return JSObject();
  }

  // Sent when RUM is started. Replaces onInit from previous versions.
  void onRumStart(OnRumStartOptions options) {}
}

@JSExport()
class RumWebPluginImpl extends RumWebPlugin {
  @override
  String get name => 'DatadogFlutterWeb';

  JSFunction? _addEvent;
  int? _navigationStart;

  @override
  void onRumStart(OnRumStartOptions options) {
    _addEvent = options.addEvent;
  }

  void addEvent(
      JSNumber time, RumWebRawEvent event, RumWebEventDomainContext context) {
    _addEvent?.callAsFunction(null, time, event, context, null);
  }

  JSNumber getEventRelativeTime(DateTime time) {
    _navigationStart ??= window.performance.timing.navigationStart;
    if (_navigationStart == null) {
      return time.millisecondsSinceEpoch.toJS;
    }

    return (time.millisecondsSinceEpoch - _navigationStart!).toJS;
  }
}

@anonymous
extension type OnRumStartOptions._(JSObject _) implements JSObject {
  external JSFunction addEvent;
}
