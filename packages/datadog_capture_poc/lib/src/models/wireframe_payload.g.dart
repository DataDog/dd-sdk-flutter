// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wireframe_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WireframeTextOptions _$WireframeTextOptionsFromJson(
        Map<String, dynamic> json) =>
    WireframeTextOptions(
      text: json['text'] as String?,
      textColor: json['textColor'] as String?,
      fontName: json['fontName'] as String?,
      fontFamilyName: json['fontFamilyName'] as String?,
      fontSize: json['fontSize'] as num?,
    );

Map<String, dynamic> _$WireframeTextOptionsToJson(
        WireframeTextOptions instance) =>
    <String, dynamic>{
      'text': instance.text,
      'textColor': instance.textColor,
      'fontName': instance.fontName,
      'fontFamilyName': instance.fontFamilyName,
      'fontSize': instance.fontSize,
    };

WireframeImageOptions _$WireframeImageOptionsFromJson(
        Map<String, dynamic> json) =>
    WireframeImageOptions(
      imageName: json['imageName'] as String?,
    );

Map<String, dynamic> _$WireframeImageOptionsToJson(
        WireframeImageOptions instance) =>
    <String, dynamic>{
      'imageName': instance.imageName,
    };

Wireframe _$WireframeFromJson(Map<String, dynamic> json) => Wireframe(
      x: json['x'] as num,
      y: json['y'] as num,
      w: json['w'] as num,
      h: json['h'] as num,
      kind: $enumDecode(_$WireframeKindEnumMap, json['kind']),
      backgroundColor: json['backgroundColor'] as String?,
      textOptions: json['textOptions'] == null
          ? null
          : WireframeTextOptions.fromJson(
              json['textOptions'] as Map<String, dynamic>),
      imageOptions: json['imageOptions'] == null
          ? null
          : WireframeImageOptions.fromJson(
              json['imageOptions'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$WireframeToJson(Wireframe instance) => <String, dynamic>{
      'x': instance.x,
      'y': instance.y,
      'w': instance.w,
      'h': instance.h,
      'kind': _$WireframeKindEnumMap[instance.kind],
      'backgroundColor': instance.backgroundColor,
      'textOptions': instance.textOptions,
      'imageOptions': instance.imageOptions,
    };

const _$WireframeKindEnumMap = {
  WireframeKind.label: 'label',
  WireframeKind.textField: 'textfield',
  WireframeKind.image: 'image',
  WireframeKind.button: 'button',
  WireframeKind.utility: 'utility',
  WireframeKind.unknown: 'unknown',
};
