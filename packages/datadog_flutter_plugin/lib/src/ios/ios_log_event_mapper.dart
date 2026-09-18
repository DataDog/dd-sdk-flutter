// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:flutter/services.dart';

import '../../datadog_flutter_plugin.dart';
import '../internal_logger.dart';
import '../logs/log_mapper_proxy.dart';

/// iOS Still uses Method Channel communication over FFI. This is because iOS
/// does not allow callback blocks to return values, and instead requires you
/// use completion blocks, even with "blocking" implementations. That means that
/// we would have to do the same async dance we're already doing with method
/// channels, with FFI adding an unnecessary layer of complexity.
///
/// We can revisit this when Objective-C ffi supports callbacks syncronously
/// returning data.
class IosLogEventMapper extends LogMapperProxy {
  final InternalLogger _internalLogger;
  final MethodChannel _methodChannel = MethodChannel(
    'datadog_sdk_flutter.logs',
  );

  IosLogEventMapper(DatadogLoggingConfiguration config, InternalLogger logger)
      : _internalLogger = logger,
        super(logEventMapper: config.eventMapper) {
    _methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'mapLogEvent':
        return _mapLogEvent(call);
    }
  }

  Map<Object?, Object?>? _mapLogEvent(MethodCall call) {
    try {
      final logEventJson = (call.arguments['event'] as Map)
          .map<String, dynamic>((k, v) => MapEntry(k as String, v));
      final mappedLogEvent = mapLogEvent(logEventJson);
      if (mappedLogEvent == null) {
        return null;
      }
      return mappedLogEvent;
    } catch (e, st) {
      _internalLogger.sendToDatadog(
        'Error mapping log event: ${e.toString()}',
        st,
        e.runtimeType.toString(),
      );
    }

    // Return a special map which will indicate to native code something went wrong, and
    // we should send the unmodified event.
    return {'_dd.mapper_error': 'mapper error'};
  }
}
