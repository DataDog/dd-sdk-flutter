// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flag_key_obfuscation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FlagKeyObfuscation _$FlagKeyObfuscationFromJson(Map<String, dynamic> json) =>
    FlagKeyObfuscation._(
      _schemeFromJson(json['scheme']),
      _saltFromJson(json['salt']),
    );

Map<String, dynamic> _$FlagKeyObfuscationToJson(FlagKeyObfuscation instance) =>
    <String, dynamic>{'scheme': instance.scheme, 'salt': instance.salt};
