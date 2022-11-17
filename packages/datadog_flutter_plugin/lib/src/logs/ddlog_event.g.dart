// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ddlog_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LogEventAttributes _$LogEventAttributesFromJson(Map<String, dynamic> json) =>
    LogEventAttributes(
      userAttributes: json['userAttributes'] as Map<String, dynamic>,
      internalAttributes: json['internalAttributes'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$LogEventAttributesToJson(LogEventAttributes instance) =>
    <String, dynamic>{
      'userAttributes': instance.userAttributes,
      'internalAttributes': instance.internalAttributes,
    };

LogEventUserInfo _$LogEventUserInfoFromJson(Map<String, dynamic> json) =>
    LogEventUserInfo(
      id: json['id'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      extraInfo: json['extraInfo'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$LogEventUserInfoToJson(LogEventUserInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'email': instance.email,
      'extraInfo': instance.extraInfo,
    };

LogEventError _$LogEventErrorFromJson(Map<String, dynamic> json) =>
    LogEventError(
      kind: json['kind'] as String?,
      message: json['message'] as String?,
      stack: json['stack'] as String?,
    );

Map<String, dynamic> _$LogEventErrorToJson(LogEventError instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'message': instance.message,
      'stack': instance.stack,
    };

LogEvent _$LogEventFromJson(Map<String, dynamic> json) => LogEvent(
      date: json['date'] as int,
      status: $enumDecode(_$LogStatusEnumMap, json['status']),
      message: json['message'] as String,
      error: json['error'] == null
          ? null
          : LogEventError.fromJson(json['error'] as Map<String, dynamic>),
      serviceName: json['serviceName'] as String,
      environment: json['environment'] as String,
      loggerName: json['loggerName'] as String,
      loggerVersion: json['loggerVersion'] as String,
      threadName: json['threadName'] as String?,
      applicationVersion: json['applicationVersion'] as String,
      userInfo:
          LogEventUserInfo.fromJson(json['userInfo'] as Map<String, dynamic>),
      attributes: LogEventAttributes.fromJson(
          json['attributes'] as Map<String, dynamic>),
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );

Map<String, dynamic> _$LogEventToJson(LogEvent instance) => <String, dynamic>{
      'date': instance.date,
      'status': _$LogStatusEnumMap[instance.status]!,
      'message': instance.message,
      'error': instance.error,
      'serviceName': instance.serviceName,
      'environment': instance.environment,
      'loggerName': instance.loggerName,
      'loggerVersion': instance.loggerVersion,
      'threadName': instance.threadName,
      'applicationVersion': instance.applicationVersion,
      'userInfo': instance.userInfo,
      'attributes': instance.attributes,
      'tags': instance.tags,
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
