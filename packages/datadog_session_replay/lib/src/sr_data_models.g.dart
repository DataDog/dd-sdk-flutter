// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sr_data_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SRMetaRecord _$SRMetaRecordFromJson(Map<String, dynamic> json) => SRMetaRecord(
      type: (json['type'] as num?)?.toInt() ?? SRRecord.metaRecordType,
      data: SRMetaRecordData.fromJson(json['data'] as Map<String, dynamic>),
      timestamp: (json['timestamp'] as num).toInt(),
    );

Map<String, dynamic> _$SRMetaRecordToJson(SRMetaRecord instance) =>
    <String, dynamic>{
      'type': instance.type,
      'data': instance.data.toJson(),
      'timestamp': instance.timestamp,
    };

SRMetaRecordData _$SRMetaRecordDataFromJson(Map<String, dynamic> json) =>
    SRMetaRecordData(
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
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
      type: (json['type'] as num?)?.toInt() ?? SRRecord.focusRecordType,
      data: SRFocusRecordData.fromJson(json['data'] as Map<String, dynamic>),
      timestamp: (json['timestamp'] as num).toInt(),
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
      type: (json['type'] as num?)?.toInt() ?? SRRecord.fullSnapshotRecordType,
      data: SRFullSnapshotRecordData.fromJson(
          json['data'] as Map<String, dynamic>),
      timestamp: (json['timestamp'] as num).toInt(),
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
      width: (json['width'] as num).toInt(),
    );

Map<String, dynamic> _$SRShapeBorderToJson(SRShapeBorder instance) =>
    <String, dynamic>{
      'color': instance.color,
      'width': instance.width,
    };

SRContentClip _$SRContentClipFromJson(Map<String, dynamic> json) =>
    SRContentClip(
      bottom: (json['bottom'] as num).toInt(),
      left: (json['left'] as num).toInt(),
      right: (json['right'] as num).toInt(),
      top: (json['top'] as num).toInt(),
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
      size: (json['size'] as num).toInt(),
    );

Map<String, dynamic> _$SRTextStyleToJson(SRTextStyle instance) =>
    <String, dynamic>{
      'color': instance.color,
      'family': instance.family,
      'size': instance.size,
    };

SRShapeStyle _$SRShapeStyleFromJson(Map<String, dynamic> json) => SRShapeStyle(
      cornerRadius: (json['cornerRadius'] as num?)?.toDouble() ?? 0.0,
      backgroundColor: json['backgroundColor'] as String? ?? '#ffffff00',
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
    );

Map<String, dynamic> _$SRShapeStyleToJson(SRShapeStyle instance) =>
    <String, dynamic>{
      'cornerRadius': instance.cornerRadius,
      'backgroundColor': instance.backgroundColor,
      'opacity': instance.opacity,
    };

SRShapeWireframe _$SRShapeWireframeFromJson(Map<String, dynamic> json) =>
    SRShapeWireframe(
      type: json['type'] as String? ?? 'shape',
      id: (json['id'] as num).toInt(),
      x: (json['x'] as num).toInt(),
      y: (json['y'] as num).toInt(),
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      border: json['border'] == null
          ? null
          : SRShapeBorder.fromJson(json['border'] as Map<String, dynamic>),
      clip: json['clip'] == null
          ? null
          : SRContentClip.fromJson(json['clip'] as Map<String, dynamic>),
      shapeStyle: json['shapeStyle'] == null
          ? null
          : SRShapeStyle.fromJson(json['shapeStyle'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SRShapeWireframeToJson(SRShapeWireframe instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'x': instance.x,
      'y': instance.y,
      'width': instance.width,
      'height': instance.height,
      if (instance.border?.toJson() case final value?) 'border': value,
      if (instance.clip?.toJson() case final value?) 'clip': value,
      if (instance.shapeStyle?.toJson() case final value?) 'shapeStyle': value,
    };

SRPadding _$SRPaddingFromJson(Map<String, dynamic> json) => SRPadding(
      top: (json['top'] as num?)?.toInt(),
      left: (json['left'] as num?)?.toInt(),
      bottom: (json['bottom'] as num?)?.toInt(),
      right: (json['right'] as num?)?.toInt(),
    );

Map<String, dynamic> _$SRPaddingToJson(SRPadding instance) => <String, dynamic>{
      if (instance.top case final value?) 'top': value,
      if (instance.left case final value?) 'left': value,
      if (instance.bottom case final value?) 'bottom': value,
      if (instance.right case final value?) 'right': value,
    };

SRAlignment _$SRAlignmentFromJson(Map<String, dynamic> json) => SRAlignment(
      horizontal: $enumDecodeNullable(
          _$SRHorizontalAlignmentEnumMap, json['horizontal']),
      vertical:
          $enumDecodeNullable(_$SRVerticalAlignmentEnumMap, json['vertical']),
    );

Map<String, dynamic> _$SRAlignmentToJson(SRAlignment instance) =>
    <String, dynamic>{
      if (_$SRHorizontalAlignmentEnumMap[instance.horizontal] case final value?)
        'horizontal': value,
      if (_$SRVerticalAlignmentEnumMap[instance.vertical] case final value?)
        'vertical': value,
    };

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

Map<String, dynamic> _$SRTextPositionToJson(SRTextPosition instance) =>
    <String, dynamic>{
      if (instance.alignment?.toJson() case final value?) 'alignment': value,
      if (instance.padding?.toJson() case final value?) 'padding': value,
    };

SRTextWireframe _$SRTextWireframeFromJson(Map<String, dynamic> json) =>
    SRTextWireframe(
      type: json['type'] as String? ?? 'text',
      id: (json['id'] as num).toInt(),
      x: (json['x'] as num).toInt(),
      y: (json['y'] as num).toInt(),
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
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

Map<String, dynamic> _$SRTextWireframeToJson(SRTextWireframe instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'x': instance.x,
      'y': instance.y,
      'width': instance.width,
      'height': instance.height,
      'text': instance.text,
      'textStyle': instance.textStyle.toJson(),
      if (instance.border?.toJson() case final value?) 'border': value,
      if (instance.clip?.toJson() case final value?) 'clip': value,
      if (instance.shapeStyle?.toJson() case final value?) 'shapeStyle': value,
      if (instance.textPosition?.toJson() case final value?)
        'textPosition': value,
    };

SRPlaceholderWireframe _$SRPlaceholderWireframeFromJson(
        Map<String, dynamic> json) =>
    SRPlaceholderWireframe(
      type: json['type'] as String? ?? 'placeholder',
      id: (json['id'] as num).toInt(),
      x: (json['x'] as num).toInt(),
      y: (json['y'] as num).toInt(),
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      label: json['label'] as String?,
      clip: json['clip'] == null
          ? null
          : SRContentClip.fromJson(json['clip'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SRPlaceholderWireframeToJson(
        SRPlaceholderWireframe instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'x': instance.x,
      'y': instance.y,
      'width': instance.width,
      'height': instance.height,
      if (instance.label case final value?) 'label': value,
      if (instance.clip?.toJson() case final value?) 'clip': value,
    };

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
      start: (json['start'] as num).toInt(),
      end: (json['end'] as num).toInt(),
      hasFullSnapshot: json['hasFullSnapshot'] as bool?,
      indexInView: (json['indexInView'] as num).toInt(),
      records: (json['records'] as List<dynamic>)
          .map((e) => SRRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      recordsCount: (json['recordsCount'] as num).toInt(),
      source: json['source'] as String? ?? 'flutter',
    );

Map<String, dynamic> _$SRSegmentToJson(SRSegment instance) => <String, dynamic>{
      'application': instance.application.toJson(),
      'session': instance.session.toJson(),
      'view': instance.view.toJson(),
      'start': instance.start,
      'end': instance.end,
      if (instance.hasFullSnapshot case final value?) 'hasFullSnapshot': value,
      'indexInView': instance.indexInView,
      'records': instance.records.map((e) => e.toJson()).toList(),
      'recordsCount': instance.recordsCount,
      'source': instance.source,
    };

SRIntrementalAdd _$SRIntrementalAddFromJson(Map<String, dynamic> json) =>
    SRIntrementalAdd(
      previousId: (json['previousId'] as num?)?.toInt(),
      wireframe:
          SRWireframe.fromJson(json['wireframe'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SRIntrementalAddToJson(SRIntrementalAdd instance) =>
    <String, dynamic>{
      if (instance.previousId case final value?) 'previousId': value,
      'wireframe': instance.wireframe.toJson(),
    };

SRIncrementalRemove _$SRIncrementalRemoveFromJson(Map<String, dynamic> json) =>
    SRIncrementalRemove(
      id: (json['id'] as num).toInt(),
    );

Map<String, dynamic> _$SRIncrementalRemoveToJson(
        SRIncrementalRemove instance) =>
    <String, dynamic>{
      'id': instance.id,
    };

SRShapeWireframeUpdate _$SRShapeWireframeUpdateFromJson(
        Map<String, dynamic> json) =>
    SRShapeWireframeUpdate(
      type: json['type'] as String? ?? 'shape',
      id: (json['id'] as num).toInt(),
      x: (json['x'] as num?)?.toInt(),
      y: (json['y'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      border: json['border'] == null
          ? null
          : SRShapeBorder.fromJson(json['border'] as Map<String, dynamic>),
      clip: json['clip'] == null
          ? null
          : SRContentClip.fromJson(json['clip'] as Map<String, dynamic>),
      shapeStyle: json['shapeStyle'] == null
          ? null
          : SRShapeStyle.fromJson(json['shapeStyle'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SRShapeWireframeUpdateToJson(
        SRShapeWireframeUpdate instance) =>
    <String, dynamic>{
      'type': instance.type,
      'id': instance.id,
      if (instance.x case final value?) 'x': value,
      if (instance.y case final value?) 'y': value,
      if (instance.width case final value?) 'width': value,
      if (instance.height case final value?) 'height': value,
      if (instance.border?.toJson() case final value?) 'border': value,
      if (instance.clip?.toJson() case final value?) 'clip': value,
      if (instance.shapeStyle?.toJson() case final value?) 'shapeStyle': value,
    };

SRTextWireframeUpdate _$SRTextWireframeUpdateFromJson(
        Map<String, dynamic> json) =>
    SRTextWireframeUpdate(
      type: json['type'] as String? ?? 'text',
      id: (json['id'] as num).toInt(),
      x: (json['x'] as num?)?.toInt(),
      y: (json['y'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      text: json['text'] as String?,
      textStyle: json['textStyle'] == null
          ? null
          : SRTextStyle.fromJson(json['textStyle'] as Map<String, dynamic>),
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

Map<String, dynamic> _$SRTextWireframeUpdateToJson(
        SRTextWireframeUpdate instance) =>
    <String, dynamic>{
      'type': instance.type,
      'id': instance.id,
      if (instance.x case final value?) 'x': value,
      if (instance.y case final value?) 'y': value,
      if (instance.width case final value?) 'width': value,
      if (instance.height case final value?) 'height': value,
      if (instance.text case final value?) 'text': value,
      if (instance.textStyle?.toJson() case final value?) 'textStyle': value,
      if (instance.border?.toJson() case final value?) 'border': value,
      if (instance.clip?.toJson() case final value?) 'clip': value,
      if (instance.shapeStyle?.toJson() case final value?) 'shapeStyle': value,
      if (instance.textPosition?.toJson() case final value?)
        'textPosition': value,
    };

SRImageWireframeUpdate _$SRImageWireframeUpdateFromJson(
        Map<String, dynamic> json) =>
    SRImageWireframeUpdate(
      type: json['type'] as String? ?? 'shape',
      id: (json['id'] as num).toInt(),
      x: (json['x'] as num?)?.toInt(),
      y: (json['y'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      border: json['border'] == null
          ? null
          : SRShapeBorder.fromJson(json['border'] as Map<String, dynamic>),
      clip: json['clip'] == null
          ? null
          : SRContentClip.fromJson(json['clip'] as Map<String, dynamic>),
      shapeStyle: json['shapeStyle'] == null
          ? null
          : SRShapeStyle.fromJson(json['shapeStyle'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SRImageWireframeUpdateToJson(
        SRImageWireframeUpdate instance) =>
    <String, dynamic>{
      'type': instance.type,
      'id': instance.id,
      if (instance.x case final value?) 'x': value,
      if (instance.y case final value?) 'y': value,
      if (instance.width case final value?) 'width': value,
      if (instance.height case final value?) 'height': value,
      if (instance.border?.toJson() case final value?) 'border': value,
      if (instance.clip?.toJson() case final value?) 'clip': value,
      if (instance.shapeStyle?.toJson() case final value?) 'shapeStyle': value,
    };

SRPlaceholderWireframeUpdate _$SRPlaceholderWireframeUpdateFromJson(
        Map<String, dynamic> json) =>
    SRPlaceholderWireframeUpdate(
      type: json['type'] as String? ?? 'placeholder',
      id: (json['id'] as num).toInt(),
      x: (json['x'] as num?)?.toInt(),
      y: (json['y'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      label: json['label'] as String?,
      clip: json['clip'] == null
          ? null
          : SRContentClip.fromJson(json['clip'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SRPlaceholderWireframeUpdateToJson(
        SRPlaceholderWireframeUpdate instance) =>
    <String, dynamic>{
      'type': instance.type,
      'id': instance.id,
      if (instance.x case final value?) 'x': value,
      if (instance.y case final value?) 'y': value,
      if (instance.width case final value?) 'width': value,
      if (instance.height case final value?) 'height': value,
      if (instance.label case final value?) 'label': value,
      if (instance.clip?.toJson() case final value?) 'clip': value,
    };

SRIncrementalMutationData _$SRIncrementalMutationDataFromJson(
        Map<String, dynamic> json) =>
    SRIncrementalMutationData(
      source: (json['source'] as num?)?.toInt() ?? 0,
      adds: (json['adds'] as List<dynamic>)
          .map((e) => SRIntrementalAdd.fromJson(e as Map<String, dynamic>))
          .toList(),
      removes: (json['removes'] as List<dynamic>)
          .map((e) => SRIncrementalRemove.fromJson(e as Map<String, dynamic>))
          .toList(),
      updates: (json['updates'] as List<dynamic>)
          .map((e) => SRIncrementalUpdate.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SRIncrementalMutationDataToJson(
        SRIncrementalMutationData instance) =>
    <String, dynamic>{
      'source': instance.source,
      'adds': instance.adds.map((e) => e.toJson()).toList(),
      'removes': instance.removes.map((e) => e.toJson()).toList(),
      'updates': instance.updates.map((e) => e.toJson()).toList(),
    };

SRIncrementalSnapshotRecord _$SRIncrementalSnapshotRecordFromJson(
        Map<String, dynamic> json) =>
    SRIncrementalSnapshotRecord(
      type: (json['type'] as num?)?.toInt() ?? 11,
      data: SRIncrementalSnapshotData.fromJson(
          json['data'] as Map<String, dynamic>),
      timestamp: (json['timestamp'] as num).toInt(),
    );

Map<String, dynamic> _$SRIncrementalSnapshotRecordToJson(
        SRIncrementalSnapshotRecord instance) =>
    <String, dynamic>{
      'type': instance.type,
      'data': instance.data.toJson(),
      'timestamp': instance.timestamp,
    };

SRPointerInteractionData _$SRPointerInteractionDataFromJson(
        Map<String, dynamic> json) =>
    SRPointerInteractionData(
      source: (json['source'] as num?)?.toInt() ?? 9,
      pointerEventType:
          $enumDecode(_$SRPointerEventTypeEnumMap, json['pointerEventType']),
      pointerId: (json['pointerId'] as num).toInt(),
      pointerType: $enumDecode(_$SRPointerTypeEnumMap, json['pointerType']),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );

Map<String, dynamic> _$SRPointerInteractionDataToJson(
        SRPointerInteractionData instance) =>
    <String, dynamic>{
      'source': instance.source,
      'pointerEventType':
          _$SRPointerEventTypeEnumMap[instance.pointerEventType]!,
      'pointerId': instance.pointerId,
      'pointerType': _$SRPointerTypeEnumMap[instance.pointerType]!,
      'x': instance.x,
      'y': instance.y,
    };

const _$SRPointerEventTypeEnumMap = {
  SRPointerEventType.down: 'down',
  SRPointerEventType.up: 'up',
  SRPointerEventType.move: 'move',
};

const _$SRPointerTypeEnumMap = {
  SRPointerType.mouse: 'mouse',
  SRPointerType.touch: 'touch',
  SRPointerType.pen: 'pen',
};

SREnrichedRecord _$SREnrichedRecordFromJson(Map<String, dynamic> json) =>
    SREnrichedRecord(
      records: (json['records'] as List<dynamic>)
          .map((e) => SRRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      applicationID: json['applicationID'] as String,
      sessionID: json['sessionID'] as String,
      viewID: json['viewID'] as String,
    );

Map<String, dynamic> _$SREnrichedRecordToJson(SREnrichedRecord instance) =>
    <String, dynamic>{
      'records': instance.records.map((e) => e.toJson()).toList(),
      'applicationID': instance.applicationID,
      'sessionID': instance.sessionID,
      'viewID': instance.viewID,
    };
