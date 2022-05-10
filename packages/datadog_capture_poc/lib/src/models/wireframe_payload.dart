// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:ui' as ui show Image;

import 'package:json_annotation/json_annotation.dart';

part 'wireframe_payload.g.dart';

enum WireframeKind {
  window,
  label,
  @JsonValue('textfield')
  textField,
  image,
  button,
  utility,
  unknown,
}

@JsonSerializable()
class WireframeTextOptions {
  final String? text;
  final String? textColor;
  final String? fontName;
  final String? fontFamilyName;
  final num? fontSize;

  WireframeTextOptions(
      {this.text,
      this.textColor,
      this.fontName,
      this.fontFamilyName,
      this.fontSize});

  factory WireframeTextOptions.fromJson(Map<String, dynamic> json) =>
      _$WireframeTextOptionsFromJson(json);
  Map<String, dynamic> toJson() => _$WireframeTextOptionsToJson(this);
}

@JsonSerializable()
class WireframeImageOptions {
  final String? imageName;

  WireframeImageOptions({
    this.imageName,
  });

  factory WireframeImageOptions.fromJson(Map<String, dynamic> json) =>
      _$WireframeImageOptionsFromJson(json);
  Map<String, dynamic> toJson() => _$WireframeImageOptionsToJson(this);
}

class WireframeImageCapture {
  final String id;
  final ui.Image capture;
  final bool cropRect;

  WireframeImageCapture({
    required this.id,
    required this.capture,
    this.cropRect = false,
  });
}

@JsonSerializable()
class Wireframe {
  final num x;
  final num y;
  final num w;
  final num h;
  final WireframeKind kind;
  final String? backgroundColor;
  final WireframeTextOptions? textOptions;
  final WireframeImageOptions? imageOptions;

  @JsonKey(ignore: true)
  List<Wireframe> wireframeChildren = [];

  @JsonKey(ignore: true)
  WireframeImageCapture? imageCapture;

  Wireframe({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.kind,
    this.backgroundColor,
    this.textOptions,
    this.imageOptions,
    this.imageCapture,
  });

  factory Wireframe.fromJson(Map<String, dynamic> json) =>
      _$WireframeFromJson(json);
  Map<String, dynamic> toJson() => _$WireframeToJson(this);
}
