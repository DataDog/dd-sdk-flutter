// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:js_interop';

import 'package:uuid/uuid.dart';

import '../../../datadog_internal.dart';
import '../../web_helpers.dart';
import '../rum.dart';
import 'raw_events.dart';
import 'rum_web_plugin.dart';

/// This class is used to track resources until they finish and are sent to the
/// Browser SDK. This class will be replaced by tracking done in a bridge plugin
/// hosted in the Browser SDK in future versions.
///
/// See RUM-
class ResourceTracker {
  final Uuid _uuid = Uuid();
  final RumWebPluginImpl _webPlugin;
  final Map<String, _ResourceInfo> _resources = {};

  ResourceTracker(this._webPlugin);

  void startResource(
    DateTime timestamp,
    String key,
    RumHttpMethod httpMethod,
    String url,
    Map<String, dynamic> attributes,
  ) {
    if (_resources.containsKey(key)) {
      return;
    }

    final resouceInfo = _ResourceInfo(
      timestamp: timestamp,
      key: key,
      method: httpMethod,
      url: url,
      attributes: attributes,
    );
    _resources[key] = resouceInfo;
  }

  void stopResource(
    DateTime timestamp,
    String key,
    int? statusCode,
    RumResourceType kind,
    int? size,
    Map<String, dynamic> attributes,
  ) {
    final resource = _resources[key];
    if (resource == null) return;

    final epochTime = timestamp.millisecondsSinceEpoch;
    final duration = timestamp.difference(resource.timestamp).inNanoseconds;
    final eventTime = _webPlugin.getEventRelativeTime(timestamp);
    final finalAttributes = resource.attributes.mergedWith(attributes);

    final ddData = _extractDdData(finalAttributes);

    var id = _uuid.v4().toString();

    _webPlugin.addEvent(
      eventTime,
      RumWebRawResourceEvent(
        date: epochTime.toJS,
        resource: RumWebRawResourceData(
          id: id,
          type: kind.name,
          url: resource.url,
          duration: duration.toJS,
          method: resource.method.name.toUpperCase(),
          status_code: statusCode?.toJS,
          transfer_size: size?.toJS,
        ),
        dd: ddData,
        context: finalAttributes,
      ),
      RumWebResourceEventDomainContext(performanceEntry: null),
    );
  }

  void stopResourceWithError(
    DateTime timestamp,
    String key,
    Exception error,
    Map<String, dynamic> attributes,
  ) {
    stopResourceWithErrorInfo(
      timestamp,
      key,
      error.toString(),
      error.runtimeType.toString(),
      attributes,
    );
  }

  void stopResourceWithErrorInfo(
    DateTime timestamp,
    String key,
    String message,
    String type,
    Map<String, dynamic> attributes,
  ) {
    final resource = _resources[key];
    if (resource == null) return;

    final epochTime = timestamp.millisecondsSinceEpoch;
    final eventTime = _webPlugin.getEventRelativeTime(timestamp);
    final finalAttributes = resource.attributes.mergedWith(attributes);

    final id = _uuid.v4();

    _webPlugin.addEvent(
      eventTime,
      RumWebRawErrorEvent(
        date: epochTime.toJS,
        context: attributesToJs(finalAttributes, 'attributes'),
        error: RumWebRawErrorData(
          id: id.toString(),
          message: message,
          source: 'network',
          type: type,
          resource: RumWebRawErrorResource(
            method: resource.method.name.toUpperCase(),
            status_code: 0,
            url: resource.url,
          ),
        ),
      ),
      RumWebErrorEventDomainContext(),
    );
  }

  RumWebRawResourceDdData _extractDdData(Map<String, dynamic> attributes) {
    final traceId =
        attributes.remove(DatadogRumPlatformAttributeKey.traceID) as String?;
    final spanId =
        attributes.remove(DatadogRumPlatformAttributeKey.spanID) as String?;
    final rulePsr =
        attributes.remove(DatadogRumPlatformAttributeKey.rulePsr) as num?;

    return RumWebRawResourceDdData(
      trace_id: traceId,
      span_id: spanId,
      rule_psr: rulePsr?.toJS,
      discarded: false,
    );
  }
}

class _ResourceInfo {
  final DateTime timestamp;
  final String key;
  final RumHttpMethod method;
  final String url;
  final Map<String, dynamic> attributes;

  _ResourceInfo({
    required this.timestamp,
    required this.key,
    required this.method,
    required this.url,
    required this.attributes,
  });
}

extension MapMerge<K, V> on Map<K, V> {
  // Merge the current dictionary with the new dictionary,
  // overwriting any duplicate keys. This does not do any
  // 'recursive' merging, so maps will be overwritten.
  Map<K, V> mergedWith(Map<K, V> other) {
    final result = Map<K, V>.from(this);
    for (final entry in other.entries) {
      result[entry.key] = entry.value;
    }

    return result;
  }
}
