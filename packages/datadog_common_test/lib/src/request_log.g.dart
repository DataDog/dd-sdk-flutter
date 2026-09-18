// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestLog _$RequestLogFromJson(Map<String, dynamic> json) => RequestLog(
      requestedUrl: json['requestedUrl'] as String,
      queryParameters: Map<String, String>.from(json['queryParameters'] as Map),
      requestMethod: json['requestMethod'] as String,
      requestHeaders: (json['requestHeaders'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ),
      data: json['data'] as String,
    );

Map<String, dynamic> _$RequestLogToJson(RequestLog instance) =>
    <String, dynamic>{
      'requestedUrl': instance.requestedUrl,
      'queryParameters': instance.queryParameters,
      'requestMethod': instance.requestMethod,
      'requestHeaders': instance.requestHeaders,
      'data': instance.data,
    };
