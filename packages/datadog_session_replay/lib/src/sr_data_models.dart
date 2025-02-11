// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'sr_data_models.g.dart';

// Helper for mutations, maybe move?
T? useIfDifferent<T>(T? use, T? compare) {
  return use == compare ? null : use;
}

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
  final int id;
  final String type;
  final int x;
  final int y;
  final int width;
  final int height;

  SRWireframe({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  @mustBeOverridden
  bool isDifferent(SRWireframe other) {
    if (runtimeType != other.runtimeType) return true;

    return !(id == other.id &&
        type == other.type &&
        x == other.x &&
        y == other.y &&
        width == other.width &&
        height == other.height);
  }

  SRIncrementalUpdate mutationsFrom(SRWireframe other);

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

  @override
  bool operator ==(Object other) =>
      other is SRShapeBorder && color == other.color && width == other.width;

  @override
  int get hashCode => Object.hash(color, width);

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

  @override
  bool operator ==(Object other) =>
      other is SRContentClip &&
      bottom == other.bottom &&
      left == other.left &&
      right == other.right &&
      top == other.top;

  @override
  int get hashCode => Object.hash(bottom, left, right, top);

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

  @override
  bool operator ==(Object other) =>
      other is SRTextStyle &&
      color == other.color &&
      family == other.family &&
      size == other.size;

  @override
  int get hashCode => Object.hash(color, family, size);

  factory SRTextStyle.fromJson(Map<String, dynamic> json) =>
      _$SRTextStyleFromJson(json);
  Map<String, dynamic> toJson() => _$SRTextStyleToJson(this);
}

@JsonSerializable()
class SRShapeStyle {
  final double cornerRadius;
  final String backgroundColor;
  final double opacity;

  SRShapeStyle({
    this.cornerRadius = 0.0,
    this.backgroundColor = '#ffffff00',
    this.opacity = 1.0,
  });

  @override
  bool operator ==(Object other) =>
      other is SRShapeStyle &&
      cornerRadius == other.cornerRadius &&
      backgroundColor == other.backgroundColor &&
      opacity == other.opacity;

  @override
  int get hashCode => Object.hash(cornerRadius, backgroundColor, opacity);

  factory SRShapeStyle.fromJson(Map<String, dynamic> json) =>
      _$SRShapeStyleFromJson(json);
  Map<String, dynamic> toJson() => _$SRShapeStyleToJson(this);
}

@JsonSerializable()
class SRShapeWireframe extends SRWireframe {
  final SRShapeBorder? border;
  final SRContentClip? clip;
  final SRShapeStyle? shapeStyle;

  SRShapeWireframe({
    super.type = 'shape',
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    this.border,
    this.clip,
    this.shapeStyle,
  });

  @override
  bool isDifferent(SRWireframe other) {
    if (other is! SRShapeWireframe) return false;

    return super.isDifferent(other) ||
        !(border == other.border &&
            clip == other.clip &&
            shapeStyle == other.shapeStyle);
  }

  @override
  SRIncrementalUpdate mutationsFrom(SRWireframe other) {
    if (other is! SRShapeWireframe || id != other.id) {
      throw Error();
    }

    return SRShapeWireframeUpdate(
      id: id,
      x: useIfDifferent(x, other.x),
      y: useIfDifferent(y, other.y),
      width: useIfDifferent(width, other.width),
      height: useIfDifferent(height, other.height),
      border: useIfDifferent(border, other.border),
      clip: useIfDifferent(clip, other.clip),
      shapeStyle: useIfDifferent(shapeStyle, other.shapeStyle),
    );
  }

  factory SRShapeWireframe.fromJson(Map<String, dynamic> json) =>
      _$SRShapeWireframeFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$SRShapeWireframeToJson(this);
}

@JsonSerializable()
class SRPadding {
  final int? top;
  final int? left;
  final int? bottom;
  final int? right;

  SRPadding({this.top, this.left, this.bottom, this.right});

  @override
  bool operator ==(Object other) =>
      other is SRPadding &&
      top == other.top &&
      left == other.left &&
      bottom == other.bottom &&
      right == other.right;

  @override
  int get hashCode => Object.hash(top, left, bottom, right);

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

  @override
  bool operator ==(Object other) =>
      other is SRAlignment &&
      horizontal == other.horizontal &&
      vertical == other.vertical;

  @override
  int get hashCode => Object.hash(horizontal, vertical);

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

  @override
  bool operator ==(Object other) =>
      other is SRTextPosition &&
      alignment == other.alignment &&
      padding == other.padding;

  @override
  int get hashCode => Object.hash(alignment, padding);

  factory SRTextPosition.fromJson(Map<String, dynamic> json) =>
      _$SRTextPositionFromJson(json);
  Map<String, dynamic> toJson() => _$SRTextPositionToJson(this);
}

@JsonSerializable()
class SRTextWireframe extends SRWireframe {
  final String text;
  final SRTextStyle textStyle;

  final SRShapeBorder? border;
  final SRContentClip? clip;
  final SRShapeStyle? shapeStyle;
  final SRTextPosition? textPosition;

  SRTextWireframe({
    super.type = 'text',
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.text,
    required this.textStyle,
    this.border,
    this.clip,
    this.shapeStyle,
    this.textPosition,
  });

  @override
  bool isDifferent(SRWireframe other) {
    if (other is! SRTextWireframe) return false;

    return super.isDifferent(other) ||
        !(text == other.text &&
            textStyle == other.textStyle &&
            border == other.border &&
            clip == other.clip &&
            shapeStyle == other.shapeStyle &&
            textPosition == other.textPosition);
  }

  @override
  SRIncrementalUpdate mutationsFrom(SRWireframe other) {
    if (other is! SRTextWireframe || id != other.id) {
      throw Error();
    }

    return SRTextWireframeUpdate(
      id: id,
      x: useIfDifferent(x, other.x),
      y: useIfDifferent(y, other.y),
      width: useIfDifferent(width, other.width),
      height: useIfDifferent(height, other.height),
      text: useIfDifferent(text, other.text),
      textStyle: useIfDifferent(textStyle, other.textStyle),
      border: useIfDifferent(border, other.border),
      clip: useIfDifferent(clip, other.clip),
      shapeStyle: useIfDifferent(shapeStyle, other.shapeStyle),
      textPosition: useIfDifferent(textPosition, other.textPosition),
    );
  }

  factory SRTextWireframe.fromJson(Map<String, dynamic> json) =>
      _$SRTextWireframeFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$SRTextWireframeToJson(this);
}

@JsonSerializable()
class SRPlaceholderWireframe extends SRWireframe {
  final String? label;
  final SRContentClip? clip;

  SRPlaceholderWireframe({
    super.type = 'placeholder',
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    this.label,
    this.clip,
  });

  @override
  bool isDifferent(SRWireframe other) {
    if (other is! SRPlaceholderWireframe) return false;

    return super.isDifferent(other) ||
        !(label == other.label && clip == other.clip);
  }

  @override
  SRIncrementalUpdate mutationsFrom(SRWireframe other) {
    if (other is! SRPlaceholderWireframe || id != other.id) {
      throw Error();
    }

    return SRPlaceholderWireframeUpdate(
      id: id,
      x: useIfDifferent(x, other.x),
      y: useIfDifferent(y, other.y),
      width: useIfDifferent(width, other.width),
      height: useIfDifferent(height, other.height),
      label: useIfDifferent(label, other.label),
      clip: useIfDifferent(clip, other.clip),
    );
  }

  factory SRPlaceholderWireframe.fromJson(Map<String, dynamic> json) =>
      _$SRPlaceholderWireframeFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$SRPlaceholderWireframeToJson(this);
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

abstract class SRIncrementalSnapshotData {
  final int source;

  SRIncrementalSnapshotData({
    required this.source,
  });

  factory SRIncrementalSnapshotData.fromJson(Map<String, dynamic> json) {
    throw Error();
  }
  Map<String, dynamic> toJson();
}

@JsonSerializable()
class SRIntrementalAdd {
  final int? previousId;
  final SRWireframe wireframe;

  SRIntrementalAdd({this.previousId, required this.wireframe});

  factory SRIntrementalAdd.fromJson(Map<String, dynamic> json) =>
      _$SRIntrementalAddFromJson(json);
  Map<String, dynamic> toJson() => _$SRIntrementalAddToJson(this);
}

@JsonSerializable()
class SRIncrementalRemove {
  final int id;

  SRIncrementalRemove({
    required this.id,
  });

  factory SRIncrementalRemove.fromJson(Map<String, dynamic> json) =>
      _$SRIncrementalRemoveFromJson(json);
  Map<String, dynamic> toJson() => _$SRIncrementalRemoveToJson(this);
}

abstract class SRIncrementalUpdate {
  final String type;
  final int id;
  final int? x;
  final int? y;
  final int? width;
  final int? height;

  SRIncrementalUpdate({
    required this.type,
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory SRIncrementalUpdate.fromJson(Map<String, dynamic> json) {
    throw Error();
  }
  Map<String, dynamic> toJson();
}

@JsonSerializable()
class SRShapeWireframeUpdate extends SRIncrementalUpdate {
  final SRShapeBorder? border;
  final SRContentClip? clip;
  final SRShapeStyle? shapeStyle;

  SRShapeWireframeUpdate({
    super.type = 'shape',
    required super.id,
    super.x,
    super.y,
    super.width,
    super.height,
    required this.border,
    required this.clip,
    required this.shapeStyle,
  });

  factory SRShapeWireframeUpdate.fromJson(Map<String, dynamic> json) =>
      _$SRShapeWireframeUpdateFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$SRShapeWireframeUpdateToJson(this);
}

@JsonSerializable()
class SRTextWireframeUpdate extends SRIncrementalUpdate {
  final String? text;
  final SRTextStyle? textStyle;

  final SRShapeBorder? border;
  final SRContentClip? clip;
  final SRShapeStyle? shapeStyle;
  final SRTextPosition? textPosition;

  SRTextWireframeUpdate({
    super.type = 'text',
    required super.id,
    super.x,
    super.y,
    super.width,
    super.height,
    this.text,
    this.textStyle,
    this.border,
    this.clip,
    this.shapeStyle,
    this.textPosition,
  });

  factory SRTextWireframeUpdate.fromJson(Map<String, dynamic> json) =>
      _$SRTextWireframeUpdateFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$SRTextWireframeUpdateToJson(this);
}

@JsonSerializable()
class SRImageWireframeUpdate extends SRIncrementalUpdate {
  SRShapeBorder? border;
  SRContentClip? clip;
  SRShapeStyle? shapeStyle;

  SRImageWireframeUpdate({
    super.type = 'shape',
    required super.id,
    super.x,
    super.y,
    super.width,
    super.height,
    this.border,
    this.clip,
    this.shapeStyle,
  });

  factory SRImageWireframeUpdate.fromJson(Map<String, dynamic> json) =>
      _$SRImageWireframeUpdateFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$SRImageWireframeUpdateToJson(this);
}

@JsonSerializable()
class SRPlaceholderWireframeUpdate extends SRIncrementalUpdate {
  String? label;
  SRContentClip? clip;

  SRPlaceholderWireframeUpdate({
    super.type = 'placeholder',
    required super.id,
    super.x,
    super.y,
    super.width,
    super.height,
    this.label,
    this.clip,
  });

  factory SRPlaceholderWireframeUpdate.fromJson(Map<String, dynamic> json) =>
      _$SRPlaceholderWireframeUpdateFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$SRPlaceholderWireframeUpdateToJson(this);
}

@JsonSerializable()
class SRIncrementalMutationData extends SRIncrementalSnapshotData {
  List<SRIntrementalAdd> adds;
  List<SRIncrementalRemove> removes;
  List<SRIncrementalUpdate> updates;

  SRIncrementalMutationData({
    super.source = 0,
    required this.adds,
    required this.removes,
    required this.updates,
  });

  factory SRIncrementalMutationData.fromJson(Map<String, dynamic> json) =>
      _$SRIncrementalMutationDataFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$SRIncrementalMutationDataToJson(this);
}

@JsonSerializable()
class SRIncrementalSnapshotRecord extends SRRecord {
  final SRIncrementalSnapshotData data;
  final int timestamp;

  SRIncrementalSnapshotRecord({
    super.type = 11,
    required this.data,
    required this.timestamp,
  });

  factory SRIncrementalSnapshotRecord.fromJson(Map<String, dynamic> json) =>
      _$SRIncrementalSnapshotRecordFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$SRIncrementalSnapshotRecordToJson(this);
}

// Don't rename these as they are not used by the SR endpoint, only
// internally by iOS (which expects these names unchanged.)
@JsonSerializable(fieldRename: FieldRename.none)
class SREnrichedRecord {
  final List<SRRecord> records;

  final String applicationID;
  final String sessionID;
  final String viewID;

  SREnrichedRecord({
    required this.records,
    required this.applicationID,
    required this.sessionID,
    required this.viewID,
  });

  factory SREnrichedRecord.fromJson(Map<String, dynamic> json) =>
      _$SREnrichedRecordFromJson(json);
  Map<String, dynamic> toJson() => _$SREnrichedRecordToJson(this);
}
