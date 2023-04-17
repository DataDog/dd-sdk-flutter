// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2022-Present Datadog, Inc.

import 'package:json_annotation/json_annotation.dart';

import '../json_helpers.dart';

part 'ddlog_event.g.dart';

enum LogStatus {
  debug,
  info,
  notice,
  warn,
  error,
  critical,
  emergency,
}

@commonJsonOptions
class LogDevice {
  final String architecture;

  LogDevice({
    required this.architecture,
  });

  factory LogDevice.fromJson(Map<String, dynamic> json) =>
      _$LogDeviceFromJson(json);
  Map<String, dynamic> toJson() => _$LogDeviceToJson(this);
}

@commonJsonOptions
class LogEventDd {
  final LogDevice device;

  LogEventDd({required this.device});

  factory LogEventDd.fromJson(Map<String, dynamic> json) =>
      _$LogEventDdFromJson(json);
  Map<String, dynamic> toJson() => _$LogEventDdToJson(this);
}

@commonJsonOptions
class LogEventUserInfo {
  final String? id;
  final String? name;
  final String? email;

  @JsonKey(
    name: 'extraInfo',
    fromJson: attributesFromJson,
  )
  final Map<String, Object?> extraInfo;

  LogEventUserInfo({
    this.id,
    this.name,
    this.email,
    required this.extraInfo,
  });

  factory LogEventUserInfo.fromJson(Map<dynamic, dynamic> json) =>
      _$LogEventUserInfoFromJson(json);
  Map<String, dynamic> toJson() => _$LogEventUserInfoToJson(this);
}

@commonJsonOptions
class LogEventError {
  final String? kind;
  final String? message;
  final String? stack;

  LogEventError({
    this.kind,
    this.message,
    this.stack,
  });

  factory LogEventError.fromJson(Map<dynamic, dynamic> json) =>
      _$LogEventErrorFromJson(json);
  Map<String, dynamic> toJson() => _$LogEventErrorToJson(this);
}

@commonJsonOptions
class LogEventLoggerInfo {
  String name;
  String? threadName;
  String version;

  LogEventLoggerInfo({
    required this.name,
    this.threadName,
    required this.version,
  });

  factory LogEventLoggerInfo.fromJson(Map<dynamic, dynamic> json) =>
      _$LogEventLoggerInfoFromJson(json);
  Map<String, dynamic> toJson() => _$LogEventLoggerInfoToJson(this);
}

@commonJsonOptions
class LogEvent {
  final String date;
  LogStatus status;
  String message;
  final LogEventError? error;
  final String service;
  final LogEventUserInfo? usr;
  final LogEventLoggerInfo logger;

  @JsonKey(name: '_dd')
  final LogEventDd dd;

  @JsonKey(includeFromJson: false, includeToJson: false)
  Map<String, Object?> attributes = {};

  String ddtags;

  LogEvent({
    required this.date,
    required this.status,
    required this.message,
    this.error,
    required this.service,
    this.usr,
    required this.logger,
    required this.dd,
    required this.ddtags,
  });

  factory LogEvent.fromJson(Map<dynamic, dynamic> json) =>
      _$LogEventFromJson(json);
  Map<String, dynamic> toJson() => _$LogEventToJson(this);
}
