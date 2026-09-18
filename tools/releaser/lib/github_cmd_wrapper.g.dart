// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'github_cmd_wrapper.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GHRelease _$GHReleaseFromJson(Map<String, dynamic> json) => GHRelease(
      isLatest: json['isLatest'] as bool,
      name: json['name'] as String,
      tagName: json['tagName'] as String,
    );

Map<String, dynamic> _$GHReleaseToJson(GHRelease instance) => <String, dynamic>{
      'isLatest': instance.isLatest,
      'name': instance.name,
      'tagName': instance.tagName,
    };
