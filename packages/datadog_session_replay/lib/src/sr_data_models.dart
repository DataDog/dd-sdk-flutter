// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:json_annotation/json_annotation.dart';

part 'sr_data_models.g.dart';

enum SRRecordType {
  @JsonValue(10)
  fullSnapshot,

  @JsonValue(11)
  incrementalSnapshot,

  @JsonValue(4)
  meta,

  @JsonValue(6)
  focus,

  @JsonValue(7)
  viewEnd,

  @JsonValue(8)
  visualViewport
}

abstract class SRRecord {
  static const int metaRecordType = 4;
  static const int focusRecordType = 6;
  static const int viewEndRecordType = 7;
  static const int visualViewportRecordType = 8;
  static const int fullSnapshotRecordType = 10;
  static const int incrementalSnapshotRecordType = 11;

  final int type;

  SRRecord({required this.type});

  factory SRRecord.fromJson(Map<String, dynamic> json) {
    final recordType = json['type'];
    if (recordType is int) {
      switch (recordType) {
        case fullSnapshotRecordType:
          return SRFullSnapshotRecord.fromJson(json);
      }
    }
    // TODO:
    throw Error();
  }
  Map<String, dynamic> toJson();
}

@JsonSerializable()
class SRMetaRecord extends SRRecord {
  final SRMetaRecordData data;
  final int timestamp;

  SRMetaRecord({
    super.type = SRRecord.metaRecordType,
    required this.data,
    required this.timestamp,
  });

  factory SRMetaRecord.fromJson(Map<String, dynamic> json) =>
      _$SRMetaRecordFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$SRMetaRecordToJson(this);
}

@JsonSerializable()
class SRMetaRecordData {
  final int width;
  final int height;

  SRMetaRecordData({
    required this.width,
    required this.height,
  });

  factory SRMetaRecordData.fromJson(Map<String, dynamic> json) =>
      _$SRMetaRecordDataFromJson(json);
  Map<String, dynamic> toJson() => _$SRMetaRecordDataToJson(this);
}

@JsonSerializable()
class SRFocusRecordData {
  @JsonKey(name: 'has_focus')
  final bool hasFocus;

  SRFocusRecordData({
    required this.hasFocus,
  });

  factory SRFocusRecordData.fromJson(Map<String, dynamic> json) =>
      _$SRFocusRecordDataFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$SRFocusRecordDataToJson(this);
}

@JsonSerializable()
class SRFocusRecord extends SRRecord {
  final SRFocusRecordData data;
  final int timestamp;

  SRFocusRecord({
    super.type = SRRecord.focusRecordType,
    required this.data,
    required this.timestamp,
  });

  factory SRFocusRecord.fromJson(Map<String, dynamic> json) =>
      _$SRFocusRecordFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$SRFocusRecordToJson(this);
}

@JsonSerializable()
class SRFullSnapshotRecordData {
  final List<SRWireframe> wireframes;

  SRFullSnapshotRecordData({
    required this.wireframes,
  });

  factory SRFullSnapshotRecordData.fromJson(Map<String, dynamic> json) =>
      _$SRFullSnapshotRecordDataFromJson(json);
  Map<String, dynamic> toJson() => _$SRFullSnapshotRecordDataToJson(this);
}

@JsonSerializable()
class SRFullSnapshotRecord extends SRRecord {
  final SRFullSnapshotRecordData data;
  final int timestamp;

  SRFullSnapshotRecord({
    super.type = SRRecord.fullSnapshotRecordType,
    required this.data,
    required this.timestamp,
  });

  factory SRFullSnapshotRecord.fromJson(Map<String, dynamic> json) =>
      _$SRFullSnapshotRecordFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$SRFullSnapshotRecordToJson(this);
}

abstract class SRWireframe {
  final String type;

  SRWireframe({
    required this.type,
  });

  factory SRWireframe.fromJson(Map<String, dynamic> json) {
    throw Error();
  }
  Map<String, dynamic> toJson();
}

@JsonSerializable()
class SRShapeBorder {
  final String color;
  final int width;

  SRShapeBorder({
    required this.color,
    required this.width,
  });

  factory SRShapeBorder.fromJson(Map<String, dynamic> json) =>
      _$SRShapeBorderFromJson(json);
  Map<String, dynamic> toJson() => _$SRShapeBorderToJson(this);
}

@JsonSerializable()
class SRContentClip {
  final int bottom;
  final int left;
  final int right;
  final int top;

  SRContentClip({
    required this.bottom,
    required this.left,
    required this.right,
    required this.top,
  });

  factory SRContentClip.fromJson(Map<String, dynamic> json) =>
      _$SRContentClipFromJson(json);
  Map<String, dynamic> toJson() => _$SRContentClipToJson(this);
}

@JsonSerializable()
class SRTextStyle {
  final String color;
  final String family;
  final int size;

  SRTextStyle({
    required this.color,
    required this.family,
    required this.size,
  });

  factory SRTextStyle.fromJson(Map<String, dynamic> json) =>
      _$SRTextStyleFromJson(json);
  Map<String, dynamic> toJson() => _$SRTextStyleToJson(this);
}

@JsonSerializable()
class SRShapeStyle {
  final double? cornerRadius;
  final String? backgroundColor;
  final double? opacity;

  SRShapeStyle({
    this.cornerRadius,
    this.backgroundColor,
    this.opacity,
  });

  factory SRShapeStyle.fromJson(Map<String, dynamic> json) =>
      _$SRShapeStyleFromJson(json);
  Map<String, dynamic> toJson() => _$SRShapeStyleToJson(this);
}

@JsonSerializable()
class SRPadding {
  final int? top;
  final int? left;
  final int? bottom;
  final int? right;

  SRPadding({this.top, this.left, this.bottom, this.right});

  factory SRPadding.fromJson(Map<String, dynamic> json) =>
      _$SRPaddingFromJson(json);
  Map<String, dynamic> toJson() => _$SRPaddingToJson(this);
}

enum SRHorizontalAlignment {
  @JsonValue('left')
  left,

  @JsonValue('center')
  center,

  @JsonValue('right')
  right,
}

enum SRVerticalAlignment {
  @JsonValue('top')
  top,

  @JsonValue('center')
  center,

  @JsonValue('bottom')
  bottom,
}

@JsonSerializable()
class SRAlignment {
  SRHorizontalAlignment? horizontal;
  SRVerticalAlignment? vertical;

  SRAlignment({
    this.horizontal,
    this.vertical,
  });

  factory SRAlignment.fromJson(Map<String, dynamic> json) =>
      _$SRAlignmentFromJson(json);
  Map<String, dynamic> toJson() => _$SRAlignmentToJson(this);
}

@JsonSerializable()
class SRTextPosition {
  final SRAlignment? alignment;
  final SRPadding? padding;

  SRTextPosition({
    this.alignment,
    this.padding,
  });

  factory SRTextPosition.fromJson(Map<String, dynamic> json) =>
      _$SRTextPositionFromJson(json);
  Map<String, dynamic> toJson() => _$SRTextPositionToJson(this);
}

@JsonSerializable()
class SRTextWireframe extends SRWireframe {
  final int id;
  final int x;
  final int y;
  final int width;
  final int height;
  final String text;
  final SRTextStyle textStyle;

  final SRShapeBorder? border;
  final SRContentClip? clip;
  final SRShapeStyle? shapeStyle;
  final SRTextPosition? textPosition;

  SRTextWireframe({
    super.type = 'text',
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.text,
    required this.textStyle,
    this.border,
    this.clip,
    this.shapeStyle,
    this.textPosition,
  });

  factory SRTextWireframe.fromJson(Map<String, dynamic> json) =>
      _$SRTextWireframeFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$SRTextWireframeToJson(this);
}

@JsonSerializable()
class SRIdHolder {
  final String id;

  SRIdHolder({
    required this.id,
  });

  factory SRIdHolder.fromJson(Map<String, dynamic> json) =>
      _$SRIdHolderFromJson(json);
  Map<String, dynamic> toJson() => _$SRIdHolderToJson(this);
}

@JsonSerializable()
class SRSegment {
  final SRIdHolder application;
  final SRIdHolder session;
  final SRIdHolder view;
  final int start;
  final int end;
  final bool? hasFullSnapshot;
  final int indexInView;
  final List<SRRecord> records;
  final int recordsCount;
  final String source;

  SRSegment({
    required this.application,
    required this.session,
    required this.view,
    required this.start,
    required this.end,
    this.hasFullSnapshot,
    required this.indexInView,
    required this.records,
    required this.recordsCount,
    this.source = 'flutter',
  });

  factory SRSegment.fromJson(Map<String, dynamic> json) =>
      _$SRSegmentFromJson(json);
  Map<String, dynamic> toJson() => _$SRSegmentToJson(this);
}

// Don't rename these as they are not used by the SR endpoint, only
// internally by iOS (which expects these names unchanged.)
@JsonSerializable(fieldRename: FieldRename.none)
class SREnrichedRecord {
  final List<SRRecord> records;

  final String applicationID;
  final String sessionID;
  final String viewID;
  final bool hasFullSnapshot;
  final int earliestTimestamp;
  final int latestTimestamp;

  SREnrichedRecord({
    required this.records,
    required this.applicationID,
    required this.sessionID,
    required this.viewID,
    required this.hasFullSnapshot,
    required this.earliestTimestamp,
    required this.latestTimestamp,
  });

  factory SREnrichedRecord.fromJson(Map<String, dynamic> json) =>
      _$SREnrichedRecordFromJson(json);
  Map<String, dynamic> toJson() => _$SREnrichedRecordToJson(this);
}
