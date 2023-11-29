// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sr_data_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SRMetaRecord _$SRMetaRecordFromJson(Map<String, dynamic> json) => SRMetaRecord(
      type: json['type'] as int? ?? SRRecord.metaRecordType,
      data: SRMetaRecordData.fromJson(json['data'] as Map<String, dynamic>),
      timestamp: json['timestamp'] as int,
    );

Map<String, dynamic> _$SRMetaRecordToJson(SRMetaRecord instance) =>
    <String, dynamic>{
      'type': instance.type,
      'data': instance.data.toJson(),
      'timestamp': instance.timestamp,
    };

SRMetaRecordData _$SRMetaRecordDataFromJson(Map<String, dynamic> json) =>
    SRMetaRecordData(
      width: json['width'] as int,
      height: json['height'] as int,
    );

Map<String, dynamic> _$SRMetaRecordDataToJson(SRMetaRecordData instance) =>
    <String, dynamic>{
      'width': instance.width,
      'height': instance.height,
    };

SRFocusRecordData _$SRFocusRecordDataFromJson(Map<String, dynamic> json) =>
    SRFocusRecordData(
      hasFocus: json['has_focus'] as bool,
    );

Map<String, dynamic> _$SRFocusRecordDataToJson(SRFocusRecordData instance) =>
    <String, dynamic>{
      'has_focus': instance.hasFocus,
    };

SRFocusRecord _$SRFocusRecordFromJson(Map<String, dynamic> json) =>
    SRFocusRecord(
      type: json['type'] as int? ?? SRRecord.focusRecordType,
      data: SRFocusRecordData.fromJson(json['data'] as Map<String, dynamic>),
      timestamp: json['timestamp'] as int,
    );

Map<String, dynamic> _$SRFocusRecordToJson(SRFocusRecord instance) =>
    <String, dynamic>{
      'type': instance.type,
      'data': instance.data.toJson(),
      'timestamp': instance.timestamp,
    };

SRFullSnapshotRecordData _$SRFullSnapshotRecordDataFromJson(
        Map<String, dynamic> json) =>
    SRFullSnapshotRecordData(
      wireframes: (json['wireframes'] as List<dynamic>)
          .map((e) => SRWireframe.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SRFullSnapshotRecordDataToJson(
        SRFullSnapshotRecordData instance) =>
    <String, dynamic>{
      'wireframes': instance.wireframes.map((e) => e.toJson()).toList(),
    };

SRFullSnapshotRecord _$SRFullSnapshotRecordFromJson(
        Map<String, dynamic> json) =>
    SRFullSnapshotRecord(
      type: json['type'] as int? ?? SRRecord.fullSnapshotRecordType,
      data: SRFullSnapshotRecordData.fromJson(
          json['data'] as Map<String, dynamic>),
      timestamp: json['timestamp'] as int,
    );

Map<String, dynamic> _$SRFullSnapshotRecordToJson(
        SRFullSnapshotRecord instance) =>
    <String, dynamic>{
      'type': instance.type,
      'data': instance.data.toJson(),
      'timestamp': instance.timestamp,
    };

SRShapeBorder _$SRShapeBorderFromJson(Map<String, dynamic> json) =>
    SRShapeBorder(
      color: json['color'] as String,
      width: json['width'] as int,
    );

Map<String, dynamic> _$SRShapeBorderToJson(SRShapeBorder instance) =>
    <String, dynamic>{
      'color': instance.color,
      'width': instance.width,
    };

SRContentClip _$SRContentClipFromJson(Map<String, dynamic> json) =>
    SRContentClip(
      bottom: json['bottom'] as int,
      left: json['left'] as int,
      right: json['right'] as int,
      top: json['top'] as int,
    );

Map<String, dynamic> _$SRContentClipToJson(SRContentClip instance) =>
    <String, dynamic>{
      'bottom': instance.bottom,
      'left': instance.left,
      'right': instance.right,
      'top': instance.top,
    };

SRTextStyle _$SRTextStyleFromJson(Map<String, dynamic> json) => SRTextStyle(
      color: json['color'] as String,
      family: json['family'] as String,
      size: json['size'] as int,
    );

Map<String, dynamic> _$SRTextStyleToJson(SRTextStyle instance) =>
    <String, dynamic>{
      'color': instance.color,
      'family': instance.family,
      'size': instance.size,
    };

SRShapeStyle _$SRShapeStyleFromJson(Map<String, dynamic> json) => SRShapeStyle(
      cornerRadius: (json['cornerRadius'] as num?)?.toDouble(),
      backgroundColor: json['backgroundColor'] as String?,
      opacity: (json['opacity'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$SRShapeStyleToJson(SRShapeStyle instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('cornerRadius', instance.cornerRadius);
  writeNotNull('backgroundColor', instance.backgroundColor);
  writeNotNull('opacity', instance.opacity);
  return val;
}

SRPadding _$SRPaddingFromJson(Map<String, dynamic> json) => SRPadding(
      top: json['top'] as int?,
      left: json['left'] as int?,
      bottom: json['bottom'] as int?,
      right: json['right'] as int?,
    );

Map<String, dynamic> _$SRPaddingToJson(SRPadding instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('top', instance.top);
  writeNotNull('left', instance.left);
  writeNotNull('bottom', instance.bottom);
  writeNotNull('right', instance.right);
  return val;
}

SRAlignment _$SRAlignmentFromJson(Map<String, dynamic> json) => SRAlignment(
      horizontal: $enumDecodeNullable(
          _$SRHorizontalAlignmentEnumMap, json['horizontal']),
      vertical:
          $enumDecodeNullable(_$SRVerticalAlignmentEnumMap, json['vertical']),
    );

Map<String, dynamic> _$SRAlignmentToJson(SRAlignment instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull(
      'horizontal', _$SRHorizontalAlignmentEnumMap[instance.horizontal]);
  writeNotNull('vertical', _$SRVerticalAlignmentEnumMap[instance.vertical]);
  return val;
}

const _$SRHorizontalAlignmentEnumMap = {
  SRHorizontalAlignment.left: 'left',
  SRHorizontalAlignment.center: 'center',
  SRHorizontalAlignment.right: 'right',
};

const _$SRVerticalAlignmentEnumMap = {
  SRVerticalAlignment.top: 'top',
  SRVerticalAlignment.center: 'center',
  SRVerticalAlignment.bottom: 'bottom',
};

SRTextPosition _$SRTextPositionFromJson(Map<String, dynamic> json) =>
    SRTextPosition(
      alignment: json['alignment'] == null
          ? null
          : SRAlignment.fromJson(json['alignment'] as Map<String, dynamic>),
      padding: json['padding'] == null
          ? null
          : SRPadding.fromJson(json['padding'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SRTextPositionToJson(SRTextPosition instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('alignment', instance.alignment?.toJson());
  writeNotNull('padding', instance.padding?.toJson());
  return val;
}

SRTextWireframe _$SRTextWireframeFromJson(Map<String, dynamic> json) =>
    SRTextWireframe(
      type: json['type'] as String? ?? 'text',
      id: json['id'] as int,
      x: json['x'] as int,
      y: json['y'] as int,
      width: json['width'] as int,
      height: json['height'] as int,
      text: json['text'] as String,
      textStyle:
          SRTextStyle.fromJson(json['textStyle'] as Map<String, dynamic>),
      border: json['border'] == null
          ? null
          : SRShapeBorder.fromJson(json['border'] as Map<String, dynamic>),
      clip: json['clip'] == null
          ? null
          : SRContentClip.fromJson(json['clip'] as Map<String, dynamic>),
      shapeStyle: json['shapeStyle'] == null
          ? null
          : SRShapeStyle.fromJson(json['shapeStyle'] as Map<String, dynamic>),
      textPosition: json['textPosition'] == null
          ? null
          : SRTextPosition.fromJson(
              json['textPosition'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SRTextWireframeToJson(SRTextWireframe instance) {
  final val = <String, dynamic>{
    'type': instance.type,
    'id': instance.id,
    'x': instance.x,
    'y': instance.y,
    'width': instance.width,
    'height': instance.height,
    'text': instance.text,
    'textStyle': instance.textStyle.toJson(),
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('border', instance.border?.toJson());
  writeNotNull('clip', instance.clip?.toJson());
  writeNotNull('shapeStyle', instance.shapeStyle?.toJson());
  writeNotNull('textPosition', instance.textPosition?.toJson());
  return val;
}

SRIdHolder _$SRIdHolderFromJson(Map<String, dynamic> json) => SRIdHolder(
      id: json['id'] as String,
    );

Map<String, dynamic> _$SRIdHolderToJson(SRIdHolder instance) =>
    <String, dynamic>{
      'id': instance.id,
    };

SRSegment _$SRSegmentFromJson(Map<String, dynamic> json) => SRSegment(
      application:
          SRIdHolder.fromJson(json['application'] as Map<String, dynamic>),
      session: SRIdHolder.fromJson(json['session'] as Map<String, dynamic>),
      view: SRIdHolder.fromJson(json['view'] as Map<String, dynamic>),
      start: json['start'] as int,
      end: json['end'] as int,
      hasFullSnapshot: json['hasFullSnapshot'] as bool?,
      indexInView: json['indexInView'] as int,
      records: (json['records'] as List<dynamic>)
          .map((e) => SRRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      recordsCount: json['recordsCount'] as int,
      source: json['source'] as String? ?? 'flutter',
    );

Map<String, dynamic> _$SRSegmentToJson(SRSegment instance) {
  final val = <String, dynamic>{
    'application': instance.application.toJson(),
    'session': instance.session.toJson(),
    'view': instance.view.toJson(),
    'start': instance.start,
    'end': instance.end,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('hasFullSnapshot', instance.hasFullSnapshot);
  val['indexInView'] = instance.indexInView;
  val['records'] = instance.records.map((e) => e.toJson()).toList();
  val['recordsCount'] = instance.recordsCount;
  val['source'] = instance.source;
  return val;
}

SREnrichedRecord _$SREnrichedRecordFromJson(Map<String, dynamic> json) =>
    SREnrichedRecord(
      records: (json['records'] as List<dynamic>)
          .map((e) => SRRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      applicationID: json['applicationID'] as String,
      sessionID: json['sessionID'] as String,
      viewID: json['viewID'] as String,
      hasFullSnapshot: json['hasFullSnapshot'] as bool,
      earliestTimestamp: json['earliestTimestamp'] as int,
      latestTimestamp: json['latestTimestamp'] as int,
    );

Map<String, dynamic> _$SREnrichedRecordToJson(SREnrichedRecord instance) =>
    <String, dynamic>{
      'records': instance.records.map((e) => e.toJson()).toList(),
      'applicationID': instance.applicationID,
      'sessionID': instance.sessionID,
      'viewID': instance.viewID,
      'hasFullSnapshot': instance.hasFullSnapshot,
      'earliestTimestamp': instance.earliestTimestamp,
      'latestTimestamp': instance.latestTimestamp,
    };
