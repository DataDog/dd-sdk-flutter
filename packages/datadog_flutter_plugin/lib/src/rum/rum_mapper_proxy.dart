// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../datadog_internal.dart';
import '../android/android_rum_event_mapper.dart';
import '../ios/ios_rum_event_mapper.dart';
import 'rum.dart';

abstract class RumMapperProxy {
  final RumViewEventMapper? _viewEventMapper;
  final RumActionEventMapper? _actionEventMapper;
  final RumResourceEventMapper? _resourceEventMapper;
  final RumErrorEventMapper? _errorEventMapper;
  final RumLongTaskEventMapper? _longTaskEventMapper;

  RumMapperProxy({
    required RumViewEventMapper? viewEventMapper,
    required RumActionEventMapper? actionEventMapper,
    required RumResourceEventMapper? resourceEventMapper,
    required RumErrorEventMapper? errorEventMapper,
    required RumLongTaskEventMapper? longTaskEventMapper,
  }) : _viewEventMapper = viewEventMapper,
       _actionEventMapper = actionEventMapper,
       _resourceEventMapper = resourceEventMapper,
       _errorEventMapper = errorEventMapper,
       _longTaskEventMapper = longTaskEventMapper;

  Map<String, dynamic> mapViewEvent(Map<String, dynamic> viewEventJson) {
    if (_viewEventMapper case final mapper?) {
      final viewEvent = RumViewEvent.fromJson(viewEventJson);
      final mappedEvent = mapper(viewEvent);
      return mappedEvent.toJson();
    }

    return viewEventJson;
  }

  Map<String, dynamic>? mapActionEvent(Map<String, dynamic> actionEventJson) {
    if (_actionEventMapper case final mapper?) {
      final actionEvent = RumActionEvent.fromJson(actionEventJson);
      final mappedEvent = mapper(actionEvent);
      return mappedEvent?.toJson();
    }

    return actionEventJson;
  }

  Map<String, dynamic>? mapResourceEvent(
    Map<String, dynamic> resourceEventJson,
  ) {
    if (_resourceEventMapper case final mapper?) {
      final resourceEvent = RumResourceEvent.fromJson(resourceEventJson);
      final mappedEvent = mapper(resourceEvent);
      return mappedEvent?.toJson();
    }

    return resourceEventJson;
  }

  Map<String, dynamic>? mapErrorEvent(Map<String, dynamic> errorEventJson) {
    if (_errorEventMapper case final mapper?) {
      final errorEvent = RumErrorEvent.fromJson(errorEventJson);
      final mappedEvent = mapper(errorEvent);
      return mappedEvent?.toJson();
    }

    return errorEventJson;
  }

  Map<String, dynamic>? mapLongTaskEvent(
    Map<String, dynamic> longTaskEventJson,
  ) {
    if (_longTaskEventMapper case final mapper?) {
      final longTaskEvent = RumLongTaskEvent.fromJson(longTaskEventJson);
      final mappedEvent = mapper(longTaskEvent);
      return mappedEvent?.toJson();
    }

    return longTaskEventJson;
  }

  static RumMapperProxy? fromConfiguration(
    DatadogRumConfiguration config,
    InternalLogger logger,
  ) {
    if (kIsWeb) {
      logger.sendToDatadog(
        'Attempting to make RumMapperProxy on Web!',
        StackTrace.current,
        'InvalidOperation',
      );
    } else {
      if (Platform.isAndroid) {
        return AndroidRumEventMapper(config, logger);
      } else if (Platform.isIOS) {
        return IosRumEventMapper(config, logger);
      }
    }
    return null;
  }
}

abstract class RumMethodChannelMapperProxy extends RumMapperProxy {
  RumMethodChannelMapperProxy({
    super.viewEventMapper,
    super.actionEventMapper,
    super.resourceEventMapper,
    super.errorEventMapper,
    super.longTaskEventMapper,
  }) : super();

  Future<dynamic> handleMethodCall(MethodCall methodCall);
}
