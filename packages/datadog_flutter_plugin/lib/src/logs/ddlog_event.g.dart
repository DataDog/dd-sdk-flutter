// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ddlog_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LogDevice _$LogDeviceFromJson(Map json) => LogDevice(
      architecture: json['architecture'] as String,
    );

Map<String, dynamic> _$LogDeviceToJson(LogDevice instance) => <String, dynamic>{
      'architecture': instance.architecture,
    };

LogEventDd _$LogEventDdFromJson(Map json) => LogEventDd(
      device:
          LogDevice.fromJson(Map<String, dynamic>.from(json['device'] as Map)),
    );

Map<String, dynamic> _$LogEventDdToJson(LogEventDd instance) =>
    <String, dynamic>{
      'device': instance.device.toJson(),
    };

LogEventUserInfo _$LogEventUserInfoFromJson(Map json) => LogEventUserInfo(
      id: json['id'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      extraInfo: attributesFromJson(json['extraInfo'] as Map?),
    );

Map<String, dynamic> _$LogEventUserInfoToJson(LogEventUserInfo instance) =>
    <String, dynamic>{
      if (instance.id case final value?) 'id': value,
      if (instance.name case final value?) 'name': value,
      if (instance.email case final value?) 'email': value,
      'extraInfo': instance.extraInfo,
    };

LogEventError _$LogEventErrorFromJson(Map json) => LogEventError(
      kind: json['kind'] as String?,
      message: json['message'] as String?,
      stack: json['stack'] as String?,
      fingerprint: json['fingerprint'] as String?,
    );

Map<String, dynamic> _$LogEventErrorToJson(LogEventError instance) =>
    <String, dynamic>{
      if (instance.kind case final value?) 'kind': value,
      if (instance.message case final value?) 'message': value,
      if (instance.stack case final value?) 'stack': value,
      if (instance.fingerprint case final value?) 'fingerprint': value,
    };

LogEventLoggerInfo _$LogEventLoggerInfoFromJson(Map json) => LogEventLoggerInfo(
      name: json['name'] as String,
      threadName: json['thread_name'] as String?,
      version: json['version'] as String,
    );

Map<String, dynamic> _$LogEventLoggerInfoToJson(LogEventLoggerInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      if (instance.threadName case final value?) 'thread_name': value,
      'version': instance.version,
    };

LogEvent _$LogEventFromJson(Map json) => LogEvent(
      date: json['date'] as String,
      status: $enumDecode(_$LogStatusEnumMap, json['status']),
      message: json['message'] as String,
      error: json['error'] == null
          ? null
          : LogEventError.fromJson(json['error'] as Map),
      service: json['service'] as String,
      usr: json['usr'] == null
          ? null
          : LogEventUserInfo.fromJson(json['usr'] as Map),
      logger: LogEventLoggerInfo.fromJson(json['logger'] as Map),
      dd: LogEventDd.fromJson(Map<String, dynamic>.from(json['_dd'] as Map)),
      ddtags: json['ddtags'] as String,
    );

Map<String, dynamic> _$LogEventToJson(LogEvent instance) => <String, dynamic>{
      'date': instance.date,
      'status': _$LogStatusEnumMap[instance.status]!,
      'message': instance.message,
      if (instance.error?.toJson() case final value?) 'error': value,
      'service': instance.service,
      if (instance.usr?.toJson() case final value?) 'usr': value,
      'logger': instance.logger.toJson(),
      '_dd': instance.dd.toJson(),
      'ddtags': instance.ddtags,
    };

const _$LogStatusEnumMap = {
  LogStatus.debug: 'debug',
  LogStatus.info: 'info',
  LogStatus.notice: 'notice',
  LogStatus.warn: 'warn',
  LogStatus.error: 'error',
  LogStatus.critical: 'critical',
  LogStatus.emergency: 'emergency',
};
