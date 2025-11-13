// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/services.dart';

import '../../datadog_flutter_plugin.dart';
import '../../datadog_internal.dart';
import '../rum/rum_mapper_proxy.dart';

/// iOS Still uses Method Channel communication over FFI. This is because iOS
/// does not allow callback blocks to return values, and instead requires you
/// use completion blocks, even with "blocking" implementations. That means that
/// we would have to do the same async dance we're already doing with method
/// channels, with FFI adding an unnecessary layer of complexity.
///
/// We can revisit this when Objective-C ffi supports callbacks syncronously
/// returning data.
class IosRumEventMapper extends RumMethodChannelMapperProxy {
  static const mapperError = {'_dd.mapper_error': 'mapper error'};

  final InternalLogger _internalLogger;

  IosRumEventMapper(DatadogRumConfiguration config, InternalLogger logger)
    : _internalLogger = logger,
      super(
        viewEventMapper: config.viewEventMapper,
        actionEventMapper: config.actionEventMapper,
        resourceEventMapper: config.resourceEventMapper,
        errorEventMapper: config.errorEventMapper,
        longTaskEventMapper: config.longTaskEventMapper,
      );

  @override
  Future<dynamic> handleMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'mapViewEvent':
          return _mapViewEvent(call);
        case 'mapActionEvent':
          return _mapActionEvent(call);
        case 'mapResourceEvent':
          return _mapResourceEvent(call);
        case 'mapErrorEvent':
          return _mapErrorEvent(call);
        case 'mapLongTaskEvent':
          return _mapLongTaskEvent(call);
      }
      throw MissingPluginException(
        'Could not find a method to call for ${call.method}',
      );
    } catch (e, st) {
      _internalLogger.sendToDatadog(
        '${call.method} threw an exception: ${e.toString()}.',
        st,
        e.runtimeType.toString(),
      );
      _internalLogger.error(
        '${call.method} threw an exception: ${e.toString()}.\nReturning mapper error.',
      );
      return mapperError;
    }
  }

  Map<Object, Object?>? _mapViewEvent(MethodCall call) {
    final viewEventJson = (call.arguments['event'] as Map).toJsonMap();
    return mapViewEvent(viewEventJson);
  }

  Map<Object, Object?>? _mapActionEvent(MethodCall call) {
    final eventJson = (call.arguments['event'] as Map).toJsonMap();
    return mapActionEvent(eventJson);
  }

  Map<Object, Object?>? _mapResourceEvent(MethodCall call) {
    final eventJson = (call.arguments['event'] as Map).toJsonMap();
    return mapResourceEvent(eventJson);
  }

  Map<Object, Object?>? _mapErrorEvent(MethodCall call) {
    final eventJson = (call.arguments['event'] as Map).toJsonMap();
    return mapErrorEvent(eventJson);
  }

  Map<Object, Object?>? _mapLongTaskEvent(MethodCall call) {
    final eventJson = (call.arguments['event'] as Map).toJsonMap();
    return mapLongTaskEvent(eventJson);
  }
}

// ignore: strict_raw_type
extension on Map {
  Map<String, dynamic> toJsonMap() {
    return map((k, v) => MapEntry(k as String, v));
  }
}
