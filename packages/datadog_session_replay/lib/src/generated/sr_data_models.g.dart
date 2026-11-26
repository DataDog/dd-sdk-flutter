// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sr_data_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SRAlignment _$SRAlignmentFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRAlignment', json, ($checkedConvert) {
      final val = SRAlignment(
        horizontal: $checkedConvert(
          'horizontal',
          (v) => $enumDecodeNullable(_$SRHorizontalAlignmentEnumMap, v),
        ),
        vertical: $checkedConvert(
          'vertical',
          (v) => $enumDecodeNullable(_$SRVerticalAlignmentEnumMap, v),
        ),
      );
      return val;
    });

Map<String, dynamic> _$SRAlignmentToJson(SRAlignment instance) =>
    <String, dynamic>{
      'horizontal': ?_$SRHorizontalAlignmentEnumMap[instance.horizontal],
      'vertical': ?_$SRVerticalAlignmentEnumMap[instance.vertical],
    };

const _$SRHorizontalAlignmentEnumMap = {
  SRHorizontalAlignment.left: 'left',
  SRHorizontalAlignment.right: 'right',
  SRHorizontalAlignment.center: 'center',
};

const _$SRVerticalAlignmentEnumMap = {
  SRVerticalAlignment.top: 'top',
  SRVerticalAlignment.bottom: 'bottom',
  SRVerticalAlignment.center: 'center',
};

SRCompositionLayer _$SRCompositionLayerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRCompositionLayer', json, ($checkedConvert) {
  final val = SRCompositionLayer(
    id: $checkedConvert('id', (v) => (v as num).toInt()),
    x: $checkedConvert('x', (v) => (v as num).toInt()),
    y: $checkedConvert('y', (v) => (v as num).toInt()),
    width: $checkedConvert('width', (v) => (v as num).toInt()),
    height: $checkedConvert('height', (v) => (v as num).toInt()),
    children: $checkedConvert(
      'children',
      (v) => (v as List<dynamic>)
          .map(
            (e) => SRCompositionLayerChild.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    ),
    modifiers: $checkedConvert(
      'modifiers',
      (v) => (v as List<dynamic>?)
          ?.map(
            (e) =>
                SRCompositionLayerModifier.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    ),
    compositeOperation: $checkedConvert(
      'compositeOperation',
      (v) =>
          $enumDecodeNullable(_$SRCompositionLayerCompositeOperationEnumMap, v),
    ),
  );
  return val;
});

Map<String, dynamic> _$SRCompositionLayerToJson(SRCompositionLayer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'x': instance.x,
      'y': instance.y,
      'width': instance.width,
      'height': instance.height,
      'children': instance.children.map((e) => e.toJson()).toList(),
      'modifiers': ?instance.modifiers?.map((e) => e.toJson()).toList(),
      'compositeOperation':
          ?_$SRCompositionLayerCompositeOperationEnumMap[instance
              .compositeOperation],
    };

const _$SRCompositionLayerCompositeOperationEnumMap = {
  SRCompositionLayerCompositeOperation.sourceOver: 'sourceOver',
  SRCompositionLayerCompositeOperation.destinationIn: 'destinationIn',
  SRCompositionLayerCompositeOperation.destinationOut: 'destinationOut',
  SRCompositionLayerCompositeOperation.plusDarker: 'plusDarker',
};

SRCompositionLayerBrightnessBiasModifier
_$SRCompositionLayerBrightnessBiasModifierFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRCompositionLayerBrightnessBiasModifier', json, (
      $checkedConvert,
    ) {
      final val = SRCompositionLayerBrightnessBiasModifier(
        value: $checkedConvert('value', (v) => (v as num).toDouble()),
      );
      return val;
    });

Map<String, dynamic> _$SRCompositionLayerBrightnessBiasModifierToJson(
  SRCompositionLayerBrightnessBiasModifier instance,
) => <String, dynamic>{'type': instance.type, 'value': instance.value};

SRCompositionLayerChild _$SRCompositionLayerChildFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRCompositionLayerChild', json, ($checkedConvert) {
  final val = SRCompositionLayerChild(
    type: $checkedConvert(
      'type',
      (v) => $enumDecode(_$SRCompositionLayerChildTypeEnumMap, v),
    ),
    id: $checkedConvert('id', (v) => (v as num).toInt()),
  );
  return val;
});

Map<String, dynamic> _$SRCompositionLayerChildToJson(
  SRCompositionLayerChild instance,
) => <String, dynamic>{
  'type': _$SRCompositionLayerChildTypeEnumMap[instance.type]!,
  'id': instance.id,
};

const _$SRCompositionLayerChildTypeEnumMap = {
  SRCompositionLayerChildType.wireframe: 'wireframe',
  SRCompositionLayerChildType.layer: 'layer',
};

SRCompositionLayerClipModifier _$SRCompositionLayerClipModifierFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRCompositionLayerClipModifier', json, ($checkedConvert) {
  final val = SRCompositionLayerClipModifier(
    path: $checkedConvert('path', (v) => v as String),
    fillRule: $checkedConvert(
      'fillRule',
      (v) => $enumDecodeNullable(
        _$SRCompositionLayerClipModifierFillRuleEnumMap,
        v,
      ),
    ),
  );
  return val;
});

Map<String, dynamic> _$SRCompositionLayerClipModifierToJson(
  SRCompositionLayerClipModifier instance,
) => <String, dynamic>{
  'type': instance.type,
  'path': instance.path,
  'fillRule':
      ?_$SRCompositionLayerClipModifierFillRuleEnumMap[instance.fillRule],
};

const _$SRCompositionLayerClipModifierFillRuleEnumMap = {
  SRCompositionLayerClipModifierFillRule.nonzero: 'nonzero',
  SRCompositionLayerClipModifierFillRule.evenodd: 'evenodd',
};

SRCompositionLayerColorMatrixModifier
_$SRCompositionLayerColorMatrixModifierFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRCompositionLayerColorMatrixModifier', json, (
      $checkedConvert,
    ) {
      final val = SRCompositionLayerColorMatrixModifier(
        matrix: $checkedConvert(
          'matrix',
          (v) =>
              (v as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$SRCompositionLayerColorMatrixModifierToJson(
  SRCompositionLayerColorMatrixModifier instance,
) => <String, dynamic>{'type': instance.type, 'matrix': instance.matrix};

SRCompositionLayerGaussianBlurModifier
_$SRCompositionLayerGaussianBlurModifierFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRCompositionLayerGaussianBlurModifier', json, (
      $checkedConvert,
    ) {
      final val = SRCompositionLayerGaussianBlurModifier(
        radius: $checkedConvert('radius', (v) => (v as num).toDouble()),
      );
      return val;
    });

Map<String, dynamic> _$SRCompositionLayerGaussianBlurModifierToJson(
  SRCompositionLayerGaussianBlurModifier instance,
) => <String, dynamic>{'type': instance.type, 'radius': instance.radius};

SRCompositionLayerMaskImageModifier
_$SRCompositionLayerMaskImageModifierFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRCompositionLayerMaskImageModifier', json, (
      $checkedConvert,
    ) {
      final val = SRCompositionLayerMaskImageModifier(
        resourceId: $checkedConvert('resourceId', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$SRCompositionLayerMaskImageModifierToJson(
  SRCompositionLayerMaskImageModifier instance,
) => <String, dynamic>{
  'type': instance.type,
  'resourceId': instance.resourceId,
};

SRCompositionLayerOpacityModifier _$SRCompositionLayerOpacityModifierFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRCompositionLayerOpacityModifier', json, (
  $checkedConvert,
) {
  final val = SRCompositionLayerOpacityModifier(
    value: $checkedConvert('value', (v) => (v as num).toDouble()),
  );
  return val;
});

Map<String, dynamic> _$SRCompositionLayerOpacityModifierToJson(
  SRCompositionLayerOpacityModifier instance,
) => <String, dynamic>{'type': instance.type, 'value': instance.value};

SRCompositionLayerSaturateModifier _$SRCompositionLayerSaturateModifierFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRCompositionLayerSaturateModifier', json, (
  $checkedConvert,
) {
  final val = SRCompositionLayerSaturateModifier(
    value: $checkedConvert('value', (v) => (v as num).toDouble()),
  );
  return val;
});

Map<String, dynamic> _$SRCompositionLayerSaturateModifierToJson(
  SRCompositionLayerSaturateModifier instance,
) => <String, dynamic>{'type': instance.type, 'value': instance.value};

SRCompositionLayerShadowModifier _$SRCompositionLayerShadowModifierFromJson(
  Map<String, dynamic> json,
) =>
    $checkedCreate('SRCompositionLayerShadowModifier', json, ($checkedConvert) {
      final val = SRCompositionLayerShadowModifier(
        color: $checkedConvert('color', (v) => v as String),
        offsetX: $checkedConvert('offsetX', (v) => (v as num).toDouble()),
        offsetY: $checkedConvert('offsetY', (v) => (v as num).toDouble()),
        radius: $checkedConvert('radius', (v) => (v as num).toDouble()),
        path: $checkedConvert('path', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$SRCompositionLayerShadowModifierToJson(
  SRCompositionLayerShadowModifier instance,
) => <String, dynamic>{
  'type': instance.type,
  'color': instance.color,
  'offsetX': instance.offsetX,
  'offsetY': instance.offsetY,
  'radius': instance.radius,
  'path': ?instance.path,
};

SRCompositionLayerUpdate _$SRCompositionLayerUpdateFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRCompositionLayerUpdate', json, ($checkedConvert) {
  final val = SRCompositionLayerUpdate(
    id: $checkedConvert('id', (v) => (v as num).toInt()),
    x: $checkedConvert('x', (v) => (v as num?)?.toInt()),
    y: $checkedConvert('y', (v) => (v as num?)?.toInt()),
    width: $checkedConvert('width', (v) => (v as num?)?.toInt()),
    height: $checkedConvert('height', (v) => (v as num?)?.toInt()),
    children: $checkedConvert(
      'children',
      (v) => (v as List<dynamic>?)
          ?.map(
            (e) => SRCompositionLayerChild.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    ),
    modifiers: $checkedConvert(
      'modifiers',
      (v) => (v as List<dynamic>?)
          ?.map(
            (e) =>
                SRCompositionLayerModifier.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    ),
    compositeOperation: $checkedConvert(
      'compositeOperation',
      (v) => $enumDecodeNullable(
        _$SRCompositionLayerUpdateCompositeOperationEnumMap,
        v,
      ),
    ),
  );
  return val;
});

Map<String, dynamic> _$SRCompositionLayerUpdateToJson(
  SRCompositionLayerUpdate instance,
) => <String, dynamic>{
  'id': instance.id,
  'x': ?instance.x,
  'y': ?instance.y,
  'width': ?instance.width,
  'height': ?instance.height,
  'children': ?instance.children?.map((e) => e.toJson()).toList(),
  'modifiers': ?instance.modifiers?.map((e) => e.toJson()).toList(),
  'compositeOperation':
      ?_$SRCompositionLayerUpdateCompositeOperationEnumMap[instance
          .compositeOperation],
};

const _$SRCompositionLayerUpdateCompositeOperationEnumMap = {
  SRCompositionLayerUpdateCompositeOperation.sourceOver: 'sourceOver',
  SRCompositionLayerUpdateCompositeOperation.destinationIn: 'destinationIn',
  SRCompositionLayerUpdateCompositeOperation.destinationOut: 'destinationOut',
  SRCompositionLayerUpdateCompositeOperation.plusDarker: 'plusDarker',
};

SRCompositionTree _$SRCompositionTreeFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRCompositionTree', json, ($checkedConvert) {
      final val = SRCompositionTree(
        root: $checkedConvert(
          'root',
          (v) => SRCompositionLayer.fromJson(v as Map<String, dynamic>),
        ),
        layers: $checkedConvert(
          'layers',
          (v) => (v as List<dynamic>?)
              ?.map(
                (e) => SRCompositionLayer.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$SRCompositionTreeToJson(SRCompositionTree instance) =>
    <String, dynamic>{
      'root': instance.root.toJson(),
      'layers': ?instance.layers?.map((e) => e.toJson()).toList(),
    };

SRCompositionTreeMutationData _$SRCompositionTreeMutationDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRCompositionTreeMutationData', json, ($checkedConvert) {
  final val = SRCompositionTreeMutationData(
    root: $checkedConvert(
      'root',
      (v) => v == null
          ? null
          : SRCompositionLayer.fromJson(v as Map<String, dynamic>),
    ),
    adds: $checkedConvert(
      'adds',
      (v) => (v as List<dynamic>?)
          ?.map((e) => SRCompositionLayer.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    removes: $checkedConvert(
      'removes',
      (v) => (v as List<dynamic>?)?.map((e) => (e as num).toInt()).toList(),
    ),
    updates: $checkedConvert(
      'updates',
      (v) => (v as List<dynamic>?)
          ?.map(
            (e) => SRCompositionLayerUpdate.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$SRCompositionTreeMutationDataToJson(
  SRCompositionTreeMutationData instance,
) => <String, dynamic>{
  'source': instance.source,
  'root': ?instance.root?.toJson(),
  'adds': ?instance.adds?.map((e) => e.toJson()).toList(),
  'removes': ?instance.removes,
  'updates': ?instance.updates?.map((e) => e.toJson()).toList(),
};

SRContentClip _$SRContentClipFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRContentClip', json, ($checkedConvert) {
      final val = SRContentClip(
        top: $checkedConvert('top', (v) => (v as num?)?.toInt()),
        bottom: $checkedConvert('bottom', (v) => (v as num?)?.toInt()),
        left: $checkedConvert('left', (v) => (v as num?)?.toInt()),
        right: $checkedConvert('right', (v) => (v as num?)?.toInt()),
      );
      return val;
    });

Map<String, dynamic> _$SRContentClipToJson(SRContentClip instance) =>
    <String, dynamic>{
      'top': ?instance.top,
      'bottom': ?instance.bottom,
      'left': ?instance.left,
      'right': ?instance.right,
    };

SREmbeddedContentWireframe _$SREmbeddedContentWireframeFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SREmbeddedContentWireframe', json, ($checkedConvert) {
  final val = SREmbeddedContentWireframe(
    id: $checkedConvert('id', (v) => (v as num).toInt()),
    x: $checkedConvert('x', (v) => (v as num).toInt()),
    y: $checkedConvert('y', (v) => (v as num).toInt()),
    width: $checkedConvert('width', (v) => (v as num).toInt()),
    height: $checkedConvert('height', (v) => (v as num).toInt()),
    clip: $checkedConvert(
      'clip',
      (v) =>
          v == null ? null : SRContentClip.fromJson(v as Map<String, dynamic>),
    ),
    shapeStyle: $checkedConvert(
      'shapeStyle',
      (v) =>
          v == null ? null : SRShapeStyle.fromJson(v as Map<String, dynamic>),
    ),
    border: $checkedConvert(
      'border',
      (v) =>
          v == null ? null : SRShapeBorder.fromJson(v as Map<String, dynamic>),
    ),
    slotId: $checkedConvert('slotId', (v) => v as String),
    isVisible: $checkedConvert('isVisible', (v) => v as bool?),
    permanentId: $checkedConvert('permanentId', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$SREmbeddedContentWireframeToJson(
  SREmbeddedContentWireframe instance,
) => <String, dynamic>{
  'id': instance.id,
  'x': instance.x,
  'y': instance.y,
  'width': instance.width,
  'height': instance.height,
  'clip': ?instance.clip?.toJson(),
  'shapeStyle': ?instance.shapeStyle?.toJson(),
  'border': ?instance.border?.toJson(),
  'type': instance.type,
  'slotId': instance.slotId,
  'isVisible': ?instance.isVisible,
  'permanentId': ?instance.permanentId,
};

SREmbeddedContentWireframeUpdate _$SREmbeddedContentWireframeUpdateFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SREmbeddedContentWireframeUpdate', json, (
  $checkedConvert,
) {
  final val = SREmbeddedContentWireframeUpdate(
    id: $checkedConvert('id', (v) => (v as num).toInt()),
    x: $checkedConvert('x', (v) => (v as num?)?.toInt()),
    y: $checkedConvert('y', (v) => (v as num?)?.toInt()),
    width: $checkedConvert('width', (v) => (v as num?)?.toInt()),
    height: $checkedConvert('height', (v) => (v as num?)?.toInt()),
    clip: $checkedConvert(
      'clip',
      (v) =>
          v == null ? null : SRContentClip.fromJson(v as Map<String, dynamic>),
    ),
    shapeStyle: $checkedConvert(
      'shapeStyle',
      (v) =>
          v == null ? null : SRShapeStyle.fromJson(v as Map<String, dynamic>),
    ),
    border: $checkedConvert(
      'border',
      (v) =>
          v == null ? null : SRShapeBorder.fromJson(v as Map<String, dynamic>),
    ),
    slotId: $checkedConvert('slotId', (v) => v as String),
    isVisible: $checkedConvert('isVisible', (v) => v as bool?),
  );
  return val;
});

Map<String, dynamic> _$SREmbeddedContentWireframeUpdateToJson(
  SREmbeddedContentWireframeUpdate instance,
) => <String, dynamic>{
  'id': instance.id,
  'x': ?instance.x,
  'y': ?instance.y,
  'width': ?instance.width,
  'height': ?instance.height,
  'clip': ?instance.clip?.toJson(),
  'shapeStyle': ?instance.shapeStyle?.toJson(),
  'border': ?instance.border?.toJson(),
  'type': instance.type,
  'slotId': instance.slotId,
  'isVisible': ?instance.isVisible,
};

SREnrichedRecord _$SREnrichedRecordFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SREnrichedRecord', json, ($checkedConvert) {
      final val = SREnrichedRecord(
        records: $checkedConvert(
          'records',
          (v) => (v as List<dynamic>)
              .map((e) => SRRecord.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        applicationID: $checkedConvert('applicationID', (v) => v as String),
        sessionID: $checkedConvert('sessionID', (v) => v as String),
        viewID: $checkedConvert('viewID', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$SREnrichedRecordToJson(SREnrichedRecord instance) =>
    <String, dynamic>{
      'records': instance.records.map((e) => e.toJson()).toList(),
      'applicationID': instance.applicationID,
      'sessionID': instance.sessionID,
      'viewID': instance.viewID,
    };

SRFocusRecord _$SRFocusRecordFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRFocusRecord', json, ($checkedConvert) {
      final val = SRFocusRecord(
        timestamp: $checkedConvert('timestamp', (v) => (v as num).toInt()),
        slotId: $checkedConvert('slotId', (v) => v as String?),
        data: $checkedConvert(
          'data',
          (v) => SRFocusRecordData.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$SRFocusRecordToJson(SRFocusRecord instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp,
      'slotId': ?instance.slotId,
      'type': instance.type,
      'data': instance.data.toJson(),
    };

SRFocusRecordData _$SRFocusRecordDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRFocusRecordData', json, ($checkedConvert) {
      final val = SRFocusRecordData(
        hasFocus: $checkedConvert('has_focus', (v) => v as bool),
      );
      return val;
    }, fieldKeyMap: const {'hasFocus': 'has_focus'});

Map<String, dynamic> _$SRFocusRecordDataToJson(SRFocusRecordData instance) =>
    <String, dynamic>{'has_focus': instance.hasFocus};

SRFullSnapshotRecord _$SRFullSnapshotRecordFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRFullSnapshotRecord', json, ($checkedConvert) {
  final val = SRFullSnapshotRecord(
    timestamp: $checkedConvert('timestamp', (v) => (v as num).toInt()),
    data: $checkedConvert(
      'data',
      (v) => SRFullSnapshotRecordData.fromJson(v as Map<String, dynamic>),
    ),
    slotId: $checkedConvert('slotId', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$SRFullSnapshotRecordToJson(
  SRFullSnapshotRecord instance,
) => <String, dynamic>{
  'timestamp': instance.timestamp,
  'type': instance.type,
  'data': instance.data.toJson(),
  'slotId': ?instance.slotId,
};

SRFullSnapshotRecordData _$SRFullSnapshotRecordDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRFullSnapshotRecordData', json, ($checkedConvert) {
  final val = SRFullSnapshotRecordData(
    wireframes: $checkedConvert(
      'wireframes',
      (v) => (v as List<dynamic>)
          .map((e) => SRWireframe.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    compositionTree: $checkedConvert(
      'compositionTree',
      (v) => v == null
          ? null
          : SRCompositionTree.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$SRFullSnapshotRecordDataToJson(
  SRFullSnapshotRecordData instance,
) => <String, dynamic>{
  'wireframes': instance.wireframes.map((e) => e.toJson()).toList(),
  'compositionTree': ?instance.compositionTree?.toJson(),
};

SRImageWireframe _$SRImageWireframeFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRImageWireframe', json, ($checkedConvert) {
  final val = SRImageWireframe(
    id: $checkedConvert('id', (v) => (v as num).toInt()),
    x: $checkedConvert('x', (v) => (v as num).toInt()),
    y: $checkedConvert('y', (v) => (v as num).toInt()),
    width: $checkedConvert('width', (v) => (v as num).toInt()),
    height: $checkedConvert('height', (v) => (v as num).toInt()),
    clip: $checkedConvert(
      'clip',
      (v) =>
          v == null ? null : SRContentClip.fromJson(v as Map<String, dynamic>),
    ),
    shapeStyle: $checkedConvert(
      'shapeStyle',
      (v) =>
          v == null ? null : SRShapeStyle.fromJson(v as Map<String, dynamic>),
    ),
    border: $checkedConvert(
      'border',
      (v) =>
          v == null ? null : SRShapeBorder.fromJson(v as Map<String, dynamic>),
    ),
    base64: $checkedConvert('base64', (v) => v as String?),
    resourceId: $checkedConvert('resourceId', (v) => v as String?),
    mimeType: $checkedConvert('mimeType', (v) => v as String?),
    isEmpty: $checkedConvert('isEmpty', (v) => v as bool?),
    permanentId: $checkedConvert('permanentId', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$SRImageWireframeToJson(SRImageWireframe instance) =>
    <String, dynamic>{
      'id': instance.id,
      'x': instance.x,
      'y': instance.y,
      'width': instance.width,
      'height': instance.height,
      'clip': ?instance.clip?.toJson(),
      'shapeStyle': ?instance.shapeStyle?.toJson(),
      'border': ?instance.border?.toJson(),
      'type': instance.type,
      'base64': ?instance.base64,
      'resourceId': ?instance.resourceId,
      'mimeType': ?instance.mimeType,
      'isEmpty': ?instance.isEmpty,
      'permanentId': ?instance.permanentId,
    };

SRImageWireframeUpdate _$SRImageWireframeUpdateFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRImageWireframeUpdate', json, ($checkedConvert) {
  final val = SRImageWireframeUpdate(
    id: $checkedConvert('id', (v) => (v as num).toInt()),
    x: $checkedConvert('x', (v) => (v as num?)?.toInt()),
    y: $checkedConvert('y', (v) => (v as num?)?.toInt()),
    width: $checkedConvert('width', (v) => (v as num?)?.toInt()),
    height: $checkedConvert('height', (v) => (v as num?)?.toInt()),
    clip: $checkedConvert(
      'clip',
      (v) =>
          v == null ? null : SRContentClip.fromJson(v as Map<String, dynamic>),
    ),
    shapeStyle: $checkedConvert(
      'shapeStyle',
      (v) =>
          v == null ? null : SRShapeStyle.fromJson(v as Map<String, dynamic>),
    ),
    border: $checkedConvert(
      'border',
      (v) =>
          v == null ? null : SRShapeBorder.fromJson(v as Map<String, dynamic>),
    ),
    base64: $checkedConvert('base64', (v) => v as String?),
    resourceId: $checkedConvert('resourceId', (v) => v as String?),
    mimeType: $checkedConvert('mimeType', (v) => v as String?),
    isEmpty: $checkedConvert('isEmpty', (v) => v as bool?),
  );
  return val;
});

Map<String, dynamic> _$SRImageWireframeUpdateToJson(
  SRImageWireframeUpdate instance,
) => <String, dynamic>{
  'id': instance.id,
  'x': ?instance.x,
  'y': ?instance.y,
  'width': ?instance.width,
  'height': ?instance.height,
  'clip': ?instance.clip?.toJson(),
  'shapeStyle': ?instance.shapeStyle?.toJson(),
  'border': ?instance.border?.toJson(),
  'type': instance.type,
  'base64': ?instance.base64,
  'resourceId': ?instance.resourceId,
  'mimeType': ?instance.mimeType,
  'isEmpty': ?instance.isEmpty,
};

SRIncrementalAdd _$SRIncrementalAddFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRIncrementalAdd', json, ($checkedConvert) {
      final val = SRIncrementalAdd(
        previousId: $checkedConvert('previousId', (v) => (v as num?)?.toInt()),
        wireframe: $checkedConvert(
          'wireframe',
          (v) => SRWireframe.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$SRIncrementalAddToJson(SRIncrementalAdd instance) =>
    <String, dynamic>{
      'previousId': ?instance.previousId,
      'wireframe': instance.wireframe.toJson(),
    };

SRIncrementalMutationData _$SRIncrementalMutationDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRIncrementalMutationData', json, ($checkedConvert) {
  final val = SRIncrementalMutationData(
    adds: $checkedConvert(
      'adds',
      (v) => (v as List<dynamic>)
          .map((e) => SRIncrementalAdd.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    removes: $checkedConvert(
      'removes',
      (v) => (v as List<dynamic>)
          .map((e) => SRIncrementalRemove.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    updates: $checkedConvert(
      'updates',
      (v) => (v as List<dynamic>)
          .map((e) => SRIncrementalUpdate.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$SRIncrementalMutationDataToJson(
  SRIncrementalMutationData instance,
) => <String, dynamic>{
  'source': instance.source,
  'adds': instance.adds.map((e) => e.toJson()).toList(),
  'removes': instance.removes.map((e) => e.toJson()).toList(),
  'updates': instance.updates.map((e) => e.toJson()).toList(),
};

SRIncrementalRemove _$SRIncrementalRemoveFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRIncrementalRemove', json, ($checkedConvert) {
      final val = SRIncrementalRemove(
        id: $checkedConvert('id', (v) => (v as num).toInt()),
      );
      return val;
    });

Map<String, dynamic> _$SRIncrementalRemoveToJson(
  SRIncrementalRemove instance,
) => <String, dynamic>{'id': instance.id};

SRIncrementalSnapshotRecord _$SRIncrementalSnapshotRecordFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRIncrementalSnapshotRecord', json, ($checkedConvert) {
  final val = SRIncrementalSnapshotRecord(
    timestamp: $checkedConvert('timestamp', (v) => (v as num).toInt()),
    data: $checkedConvert(
      'data',
      (v) => SRIncrementalSnapshotData.fromJson(v as Map<String, dynamic>),
    ),
    slotId: $checkedConvert('slotId', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$SRIncrementalSnapshotRecordToJson(
  SRIncrementalSnapshotRecord instance,
) => <String, dynamic>{
  'timestamp': instance.timestamp,
  'type': instance.type,
  'data': instance.data.toJson(),
  'slotId': ?instance.slotId,
};

SRMetaRecord _$SRMetaRecordFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRMetaRecord', json, ($checkedConvert) {
      final val = SRMetaRecord(
        timestamp: $checkedConvert('timestamp', (v) => (v as num).toInt()),
        slotId: $checkedConvert('slotId', (v) => v as String?),
        data: $checkedConvert(
          'data',
          (v) => SRMetaRecordData.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$SRMetaRecordToJson(SRMetaRecord instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp,
      'slotId': ?instance.slotId,
      'type': instance.type,
      'data': instance.data.toJson(),
    };

SRMetaRecordData _$SRMetaRecordDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRMetaRecordData', json, ($checkedConvert) {
      final val = SRMetaRecordData(
        width: $checkedConvert('width', (v) => (v as num).toInt()),
        height: $checkedConvert('height', (v) => (v as num).toInt()),
        href: $checkedConvert('href', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$SRMetaRecordDataToJson(SRMetaRecordData instance) =>
    <String, dynamic>{
      'width': instance.width,
      'height': instance.height,
      'href': ?instance.href,
    };

SRPadding _$SRPaddingFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRPadding', json, ($checkedConvert) {
      final val = SRPadding(
        top: $checkedConvert('top', (v) => (v as num?)?.toInt()),
        bottom: $checkedConvert('bottom', (v) => (v as num?)?.toInt()),
        left: $checkedConvert('left', (v) => (v as num?)?.toInt()),
        right: $checkedConvert('right', (v) => (v as num?)?.toInt()),
      );
      return val;
    });

Map<String, dynamic> _$SRPaddingToJson(SRPadding instance) => <String, dynamic>{
  'top': ?instance.top,
  'bottom': ?instance.bottom,
  'left': ?instance.left,
  'right': ?instance.right,
};

SRPlaceholderWireframe _$SRPlaceholderWireframeFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRPlaceholderWireframe', json, ($checkedConvert) {
  final val = SRPlaceholderWireframe(
    id: $checkedConvert('id', (v) => (v as num).toInt()),
    x: $checkedConvert('x', (v) => (v as num).toInt()),
    y: $checkedConvert('y', (v) => (v as num).toInt()),
    width: $checkedConvert('width', (v) => (v as num).toInt()),
    height: $checkedConvert('height', (v) => (v as num).toInt()),
    clip: $checkedConvert(
      'clip',
      (v) =>
          v == null ? null : SRContentClip.fromJson(v as Map<String, dynamic>),
    ),
    label: $checkedConvert('label', (v) => v as String?),
    permanentId: $checkedConvert('permanentId', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$SRPlaceholderWireframeToJson(
  SRPlaceholderWireframe instance,
) => <String, dynamic>{
  'id': instance.id,
  'x': instance.x,
  'y': instance.y,
  'width': instance.width,
  'height': instance.height,
  'clip': ?instance.clip?.toJson(),
  'type': instance.type,
  'label': ?instance.label,
  'permanentId': ?instance.permanentId,
};

SRPlaceholderWireframeUpdate _$SRPlaceholderWireframeUpdateFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRPlaceholderWireframeUpdate', json, ($checkedConvert) {
  final val = SRPlaceholderWireframeUpdate(
    id: $checkedConvert('id', (v) => (v as num).toInt()),
    x: $checkedConvert('x', (v) => (v as num?)?.toInt()),
    y: $checkedConvert('y', (v) => (v as num?)?.toInt()),
    width: $checkedConvert('width', (v) => (v as num?)?.toInt()),
    height: $checkedConvert('height', (v) => (v as num?)?.toInt()),
    clip: $checkedConvert(
      'clip',
      (v) =>
          v == null ? null : SRContentClip.fromJson(v as Map<String, dynamic>),
    ),
    label: $checkedConvert('label', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$SRPlaceholderWireframeUpdateToJson(
  SRPlaceholderWireframeUpdate instance,
) => <String, dynamic>{
  'id': instance.id,
  'x': ?instance.x,
  'y': ?instance.y,
  'width': ?instance.width,
  'height': ?instance.height,
  'clip': ?instance.clip?.toJson(),
  'type': instance.type,
  'label': ?instance.label,
};

SRPointerInteractionData _$SRPointerInteractionDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRPointerInteractionData', json, ($checkedConvert) {
  final val = SRPointerInteractionData(
    pointerEventType: $checkedConvert(
      'pointerEventType',
      (v) => $enumDecode(_$SRPointerEventTypeEnumMap, v),
    ),
    pointerType: $checkedConvert(
      'pointerType',
      (v) => $enumDecode(_$SRPointerTypeEnumMap, v),
    ),
    pointerId: $checkedConvert('pointerId', (v) => (v as num).toInt()),
    x: $checkedConvert('x', (v) => (v as num).toDouble()),
    y: $checkedConvert('y', (v) => (v as num).toDouble()),
  );
  return val;
});

Map<String, dynamic> _$SRPointerInteractionDataToJson(
  SRPointerInteractionData instance,
) => <String, dynamic>{
  'source': instance.source,
  'pointerEventType': _$SRPointerEventTypeEnumMap[instance.pointerEventType]!,
  'pointerType': _$SRPointerTypeEnumMap[instance.pointerType]!,
  'pointerId': instance.pointerId,
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

SRSegment _$SRSegmentFromJson(Map<String, dynamic> json) => $checkedCreate(
  'SRSegment',
  json,
  ($checkedConvert) {
    final val = SRSegment(
      application: $checkedConvert(
        'application',
        (v) => SRSegmentApplication.fromJson(v as Map<String, dynamic>),
      ),
      session: $checkedConvert(
        'session',
        (v) => SRSegmentSession.fromJson(v as Map<String, dynamic>),
      ),
      view: $checkedConvert(
        'view',
        (v) => SRSegmentView.fromJson(v as Map<String, dynamic>),
      ),
      start: $checkedConvert('start', (v) => (v as num).toInt()),
      end: $checkedConvert('end', (v) => (v as num).toInt()),
      recordsCount: $checkedConvert('records_count', (v) => (v as num).toInt()),
      indexInView: $checkedConvert(
        'index_in_view',
        (v) => (v as num?)?.toInt(),
      ),
      hasFullSnapshot: $checkedConvert('has_full_snapshot', (v) => v as bool?),
      source: $checkedConvert(
        'source',
        (v) => $enumDecode(_$SRSegmentSourceEnumMap, v),
      ),
      records: $checkedConvert(
        'records',
        (v) => (v as List<dynamic>)
            .map((e) => SRRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'recordsCount': 'records_count',
    'indexInView': 'index_in_view',
    'hasFullSnapshot': 'has_full_snapshot',
  },
);

Map<String, dynamic> _$SRSegmentToJson(SRSegment instance) => <String, dynamic>{
  'application': instance.application.toJson(),
  'session': instance.session.toJson(),
  'view': instance.view.toJson(),
  'start': instance.start,
  'end': instance.end,
  'records_count': instance.recordsCount,
  'index_in_view': ?instance.indexInView,
  'has_full_snapshot': ?instance.hasFullSnapshot,
  'source': _$SRSegmentSourceEnumMap[instance.source]!,
  'records': instance.records.map((e) => e.toJson()).toList(),
};

const _$SRSegmentSourceEnumMap = {
  SRSegmentSource.android: 'android',
  SRSegmentSource.ios: 'ios',
  SRSegmentSource.flutter: 'flutter',
  SRSegmentSource.reactNative: 'react-native',
  SRSegmentSource.kotlinMultiplatform: 'kotlin-multiplatform',
  SRSegmentSource.maui: 'maui',
  SRSegmentSource.unreal: 'unreal',
};

SRSegmentApplication _$SRSegmentApplicationFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRSegmentApplication', json, ($checkedConvert) {
  final val = SRSegmentApplication(
    id: $checkedConvert('id', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$SRSegmentApplicationToJson(
  SRSegmentApplication instance,
) => <String, dynamic>{'id': instance.id};

SRSegmentSession _$SRSegmentSessionFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRSegmentSession', json, ($checkedConvert) {
      final val = SRSegmentSession(
        id: $checkedConvert('id', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$SRSegmentSessionToJson(SRSegmentSession instance) =>
    <String, dynamic>{'id': instance.id};

SRSegmentView _$SRSegmentViewFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRSegmentView', json, ($checkedConvert) {
      final val = SRSegmentView(id: $checkedConvert('id', (v) => v as String));
      return val;
    });

Map<String, dynamic> _$SRSegmentViewToJson(SRSegmentView instance) =>
    <String, dynamic>{'id': instance.id};

SRShapeBorder _$SRShapeBorderFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRShapeBorder', json, ($checkedConvert) {
      final val = SRShapeBorder(
        color: $checkedConvert('color', (v) => v as String),
        width: $checkedConvert('width', (v) => (v as num).toInt()),
      );
      return val;
    });

Map<String, dynamic> _$SRShapeBorderToJson(SRShapeBorder instance) =>
    <String, dynamic>{'color': instance.color, 'width': instance.width};

SRShapeGradientPoint _$SRShapeGradientPointFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRShapeGradientPoint', json, ($checkedConvert) {
  final val = SRShapeGradientPoint(
    x: $checkedConvert('x', (v) => (v as num).toDouble()),
    y: $checkedConvert('y', (v) => (v as num).toDouble()),
  );
  return val;
});

Map<String, dynamic> _$SRShapeGradientPointToJson(
  SRShapeGradientPoint instance,
) => <String, dynamic>{'x': instance.x, 'y': instance.y};

SRShapeGradientStop _$SRShapeGradientStopFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRShapeGradientStop', json, ($checkedConvert) {
      final val = SRShapeGradientStop(
        color: $checkedConvert('color', (v) => v as String),
        position: $checkedConvert('position', (v) => (v as num).toDouble()),
      );
      return val;
    });

Map<String, dynamic> _$SRShapeGradientStopToJson(
  SRShapeGradientStop instance,
) => <String, dynamic>{'color': instance.color, 'position': instance.position};

SRShapeLinearGradient _$SRShapeLinearGradientFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRShapeLinearGradient', json, ($checkedConvert) {
  final val = SRShapeLinearGradient(
    stops: $checkedConvert(
      'stops',
      (v) => (v as List<dynamic>)
          .map((e) => SRShapeGradientStop.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    startPoint: $checkedConvert(
      'startPoint',
      (v) => SRShapeGradientPoint.fromJson(v as Map<String, dynamic>),
    ),
    endPoint: $checkedConvert(
      'endPoint',
      (v) => SRShapeGradientPoint.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$SRShapeLinearGradientToJson(
  SRShapeLinearGradient instance,
) => <String, dynamic>{
  'type': instance.type,
  'stops': instance.stops.map((e) => e.toJson()).toList(),
  'startPoint': instance.startPoint.toJson(),
  'endPoint': instance.endPoint.toJson(),
};

SRShapeStyle _$SRShapeStyleFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRShapeStyle', json, ($checkedConvert) {
      final val = SRShapeStyle(
        backgroundColor: $checkedConvert(
          'backgroundColor',
          (v) => v as String?,
        ),
        backgroundGradient: $checkedConvert(
          'backgroundGradient',
          (v) => v == null
              ? null
              : SRShapeGradient.fromJson(v as Map<String, dynamic>),
        ),
        opacity: $checkedConvert('opacity', (v) => (v as num?)?.toDouble()),
        cornerRadius: $checkedConvert(
          'cornerRadius',
          (v) => (v as num?)?.toDouble(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$SRShapeStyleToJson(SRShapeStyle instance) =>
    <String, dynamic>{
      'backgroundColor': ?instance.backgroundColor,
      'backgroundGradient': ?instance.backgroundGradient?.toJson(),
      'opacity': ?instance.opacity,
      'cornerRadius': ?instance.cornerRadius,
    };

SRShapeWireframe _$SRShapeWireframeFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRShapeWireframe', json, ($checkedConvert) {
  final val = SRShapeWireframe(
    id: $checkedConvert('id', (v) => (v as num).toInt()),
    x: $checkedConvert('x', (v) => (v as num).toInt()),
    y: $checkedConvert('y', (v) => (v as num).toInt()),
    width: $checkedConvert('width', (v) => (v as num).toInt()),
    height: $checkedConvert('height', (v) => (v as num).toInt()),
    clip: $checkedConvert(
      'clip',
      (v) =>
          v == null ? null : SRContentClip.fromJson(v as Map<String, dynamic>),
    ),
    shapeStyle: $checkedConvert(
      'shapeStyle',
      (v) =>
          v == null ? null : SRShapeStyle.fromJson(v as Map<String, dynamic>),
    ),
    border: $checkedConvert(
      'border',
      (v) =>
          v == null ? null : SRShapeBorder.fromJson(v as Map<String, dynamic>),
    ),
    permanentId: $checkedConvert('permanentId', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$SRShapeWireframeToJson(SRShapeWireframe instance) =>
    <String, dynamic>{
      'id': instance.id,
      'x': instance.x,
      'y': instance.y,
      'width': instance.width,
      'height': instance.height,
      'clip': ?instance.clip?.toJson(),
      'shapeStyle': ?instance.shapeStyle?.toJson(),
      'border': ?instance.border?.toJson(),
      'type': instance.type,
      'permanentId': ?instance.permanentId,
    };

SRShapeWireframeUpdate _$SRShapeWireframeUpdateFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRShapeWireframeUpdate', json, ($checkedConvert) {
  final val = SRShapeWireframeUpdate(
    id: $checkedConvert('id', (v) => (v as num).toInt()),
    x: $checkedConvert('x', (v) => (v as num?)?.toInt()),
    y: $checkedConvert('y', (v) => (v as num?)?.toInt()),
    width: $checkedConvert('width', (v) => (v as num?)?.toInt()),
    height: $checkedConvert('height', (v) => (v as num?)?.toInt()),
    clip: $checkedConvert(
      'clip',
      (v) =>
          v == null ? null : SRContentClip.fromJson(v as Map<String, dynamic>),
    ),
    shapeStyle: $checkedConvert(
      'shapeStyle',
      (v) =>
          v == null ? null : SRShapeStyle.fromJson(v as Map<String, dynamic>),
    ),
    border: $checkedConvert(
      'border',
      (v) =>
          v == null ? null : SRShapeBorder.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$SRShapeWireframeUpdateToJson(
  SRShapeWireframeUpdate instance,
) => <String, dynamic>{
  'id': instance.id,
  'x': ?instance.x,
  'y': ?instance.y,
  'width': ?instance.width,
  'height': ?instance.height,
  'clip': ?instance.clip?.toJson(),
  'shapeStyle': ?instance.shapeStyle?.toJson(),
  'border': ?instance.border?.toJson(),
  'type': instance.type,
};

SRTextPosition _$SRTextPositionFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRTextPosition', json, ($checkedConvert) {
      final val = SRTextPosition(
        padding: $checkedConvert(
          'padding',
          (v) =>
              v == null ? null : SRPadding.fromJson(v as Map<String, dynamic>),
        ),
        alignment: $checkedConvert(
          'alignment',
          (v) => v == null
              ? null
              : SRAlignment.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$SRTextPositionToJson(SRTextPosition instance) =>
    <String, dynamic>{
      'padding': ?instance.padding?.toJson(),
      'alignment': ?instance.alignment?.toJson(),
    };

SRTextStyle _$SRTextStyleFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRTextStyle', json, ($checkedConvert) {
      final val = SRTextStyle(
        family: $checkedConvert('family', (v) => v as String),
        size: $checkedConvert('size', (v) => (v as num).toInt()),
        color: $checkedConvert('color', (v) => v as String),
        truncationMode: $checkedConvert(
          'truncationMode',
          (v) => $enumDecodeNullable(_$SRTextStyleTruncationModeEnumMap, v),
        ),
      );
      return val;
    });

Map<String, dynamic> _$SRTextStyleToJson(SRTextStyle instance) =>
    <String, dynamic>{
      'family': instance.family,
      'size': instance.size,
      'color': instance.color,
      'truncationMode':
          ?_$SRTextStyleTruncationModeEnumMap[instance.truncationMode],
    };

const _$SRTextStyleTruncationModeEnumMap = {
  SRTextStyleTruncationMode.clip: 'clip',
  SRTextStyleTruncationMode.head: 'head',
  SRTextStyleTruncationMode.tail: 'tail',
  SRTextStyleTruncationMode.middle: 'middle',
};

SRTextWireframe _$SRTextWireframeFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRTextWireframe', json, ($checkedConvert) {
  final val = SRTextWireframe(
    id: $checkedConvert('id', (v) => (v as num).toInt()),
    x: $checkedConvert('x', (v) => (v as num).toInt()),
    y: $checkedConvert('y', (v) => (v as num).toInt()),
    width: $checkedConvert('width', (v) => (v as num).toInt()),
    height: $checkedConvert('height', (v) => (v as num).toInt()),
    clip: $checkedConvert(
      'clip',
      (v) =>
          v == null ? null : SRContentClip.fromJson(v as Map<String, dynamic>),
    ),
    shapeStyle: $checkedConvert(
      'shapeStyle',
      (v) =>
          v == null ? null : SRShapeStyle.fromJson(v as Map<String, dynamic>),
    ),
    border: $checkedConvert(
      'border',
      (v) =>
          v == null ? null : SRShapeBorder.fromJson(v as Map<String, dynamic>),
    ),
    text: $checkedConvert('text', (v) => v as String),
    textStyle: $checkedConvert(
      'textStyle',
      (v) => SRTextStyle.fromJson(v as Map<String, dynamic>),
    ),
    textPosition: $checkedConvert(
      'textPosition',
      (v) =>
          v == null ? null : SRTextPosition.fromJson(v as Map<String, dynamic>),
    ),
    permanentId: $checkedConvert('permanentId', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$SRTextWireframeToJson(SRTextWireframe instance) =>
    <String, dynamic>{
      'id': instance.id,
      'x': instance.x,
      'y': instance.y,
      'width': instance.width,
      'height': instance.height,
      'clip': ?instance.clip?.toJson(),
      'shapeStyle': ?instance.shapeStyle?.toJson(),
      'border': ?instance.border?.toJson(),
      'type': instance.type,
      'text': instance.text,
      'textStyle': instance.textStyle.toJson(),
      'textPosition': ?instance.textPosition?.toJson(),
      'permanentId': ?instance.permanentId,
    };

SRTextWireframeUpdate _$SRTextWireframeUpdateFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRTextWireframeUpdate', json, ($checkedConvert) {
  final val = SRTextWireframeUpdate(
    id: $checkedConvert('id', (v) => (v as num).toInt()),
    x: $checkedConvert('x', (v) => (v as num?)?.toInt()),
    y: $checkedConvert('y', (v) => (v as num?)?.toInt()),
    width: $checkedConvert('width', (v) => (v as num?)?.toInt()),
    height: $checkedConvert('height', (v) => (v as num?)?.toInt()),
    clip: $checkedConvert(
      'clip',
      (v) =>
          v == null ? null : SRContentClip.fromJson(v as Map<String, dynamic>),
    ),
    shapeStyle: $checkedConvert(
      'shapeStyle',
      (v) =>
          v == null ? null : SRShapeStyle.fromJson(v as Map<String, dynamic>),
    ),
    border: $checkedConvert(
      'border',
      (v) =>
          v == null ? null : SRShapeBorder.fromJson(v as Map<String, dynamic>),
    ),
    text: $checkedConvert('text', (v) => v as String?),
    textStyle: $checkedConvert(
      'textStyle',
      (v) => v == null ? null : SRTextStyle.fromJson(v as Map<String, dynamic>),
    ),
    textPosition: $checkedConvert(
      'textPosition',
      (v) =>
          v == null ? null : SRTextPosition.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$SRTextWireframeUpdateToJson(
  SRTextWireframeUpdate instance,
) => <String, dynamic>{
  'id': instance.id,
  'x': ?instance.x,
  'y': ?instance.y,
  'width': ?instance.width,
  'height': ?instance.height,
  'clip': ?instance.clip?.toJson(),
  'shapeStyle': ?instance.shapeStyle?.toJson(),
  'border': ?instance.border?.toJson(),
  'type': instance.type,
  'text': ?instance.text,
  'textStyle': ?instance.textStyle?.toJson(),
  'textPosition': ?instance.textPosition?.toJson(),
};

SRTouchData _$SRTouchDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRTouchData', json, ($checkedConvert) {
      final val = SRTouchData(
        positions: $checkedConvert(
          'positions',
          (v) => (v as List<dynamic>?)
              ?.map(
                (e) => SRTouchDataPositions.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$SRTouchDataToJson(SRTouchData instance) =>
    <String, dynamic>{
      'source': instance.source,
      'positions': ?instance.positions?.map((e) => e.toJson()).toList(),
    };

SRTouchDataPositions _$SRTouchDataPositionsFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRTouchDataPositions', json, ($checkedConvert) {
  final val = SRTouchDataPositions(
    id: $checkedConvert('id', (v) => (v as num).toInt()),
    x: $checkedConvert('x', (v) => (v as num).toInt()),
    y: $checkedConvert('y', (v) => (v as num).toInt()),
    timestamp: $checkedConvert('timestamp', (v) => (v as num).toInt()),
  );
  return val;
});

Map<String, dynamic> _$SRTouchDataPositionsToJson(
  SRTouchDataPositions instance,
) => <String, dynamic>{
  'id': instance.id,
  'x': instance.x,
  'y': instance.y,
  'timestamp': instance.timestamp,
};

SRViewEndRecord _$SRViewEndRecordFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SRViewEndRecord', json, ($checkedConvert) {
      final val = SRViewEndRecord(
        timestamp: $checkedConvert('timestamp', (v) => (v as num).toInt()),
        slotId: $checkedConvert('slotId', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$SRViewEndRecordToJson(SRViewEndRecord instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp,
      'slotId': ?instance.slotId,
      'type': instance.type,
    };

SRViewportResizeData _$SRViewportResizeDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRViewportResizeData', json, ($checkedConvert) {
  final val = SRViewportResizeData(
    width: $checkedConvert('width', (v) => (v as num).toInt()),
    height: $checkedConvert('height', (v) => (v as num).toInt()),
  );
  return val;
});

Map<String, dynamic> _$SRViewportResizeDataToJson(
  SRViewportResizeData instance,
) => <String, dynamic>{
  'source': instance.source,
  'width': instance.width,
  'height': instance.height,
};

SRVisualViewportRecord _$SRVisualViewportRecordFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRVisualViewportRecord', json, ($checkedConvert) {
  final val = SRVisualViewportRecord(
    timestamp: $checkedConvert('timestamp', (v) => (v as num).toInt()),
    slotId: $checkedConvert('slotId', (v) => v as String?),
    data: $checkedConvert(
      'data',
      (v) => SRVisualViewportRecordData.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$SRVisualViewportRecordToJson(
  SRVisualViewportRecord instance,
) => <String, dynamic>{
  'timestamp': instance.timestamp,
  'slotId': ?instance.slotId,
  'data': instance.data.toJson(),
  'type': instance.type,
};

SRVisualViewportRecordData _$SRVisualViewportRecordDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRVisualViewportRecordData', json, ($checkedConvert) {
  final val = SRVisualViewportRecordData(
    height: $checkedConvert('height', (v) => (v as num).toDouble()),
    offsetLeft: $checkedConvert('offsetLeft', (v) => (v as num).toDouble()),
    offsetTop: $checkedConvert('offsetTop', (v) => (v as num).toDouble()),
    pageLeft: $checkedConvert('pageLeft', (v) => (v as num).toDouble()),
    pageTop: $checkedConvert('pageTop', (v) => (v as num).toDouble()),
    scale: $checkedConvert('scale', (v) => (v as num).toDouble()),
    width: $checkedConvert('width', (v) => (v as num).toDouble()),
  );
  return val;
});

Map<String, dynamic> _$SRVisualViewportRecordDataToJson(
  SRVisualViewportRecordData instance,
) => <String, dynamic>{
  'height': instance.height,
  'offsetLeft': instance.offsetLeft,
  'offsetTop': instance.offsetTop,
  'pageLeft': instance.pageLeft,
  'pageTop': instance.pageTop,
  'scale': instance.scale,
  'width': instance.width,
};

SRWebviewWireframe _$SRWebviewWireframeFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRWebviewWireframe', json, ($checkedConvert) {
  final val = SRWebviewWireframe(
    id: $checkedConvert('id', (v) => (v as num).toInt()),
    x: $checkedConvert('x', (v) => (v as num).toInt()),
    y: $checkedConvert('y', (v) => (v as num).toInt()),
    width: $checkedConvert('width', (v) => (v as num).toInt()),
    height: $checkedConvert('height', (v) => (v as num).toInt()),
    clip: $checkedConvert(
      'clip',
      (v) =>
          v == null ? null : SRContentClip.fromJson(v as Map<String, dynamic>),
    ),
    shapeStyle: $checkedConvert(
      'shapeStyle',
      (v) =>
          v == null ? null : SRShapeStyle.fromJson(v as Map<String, dynamic>),
    ),
    border: $checkedConvert(
      'border',
      (v) =>
          v == null ? null : SRShapeBorder.fromJson(v as Map<String, dynamic>),
    ),
    slotId: $checkedConvert('slotId', (v) => v as String),
    isVisible: $checkedConvert('isVisible', (v) => v as bool?),
    permanentId: $checkedConvert('permanentId', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$SRWebviewWireframeToJson(SRWebviewWireframe instance) =>
    <String, dynamic>{
      'id': instance.id,
      'x': instance.x,
      'y': instance.y,
      'width': instance.width,
      'height': instance.height,
      'clip': ?instance.clip?.toJson(),
      'shapeStyle': ?instance.shapeStyle?.toJson(),
      'border': ?instance.border?.toJson(),
      'type': instance.type,
      'slotId': instance.slotId,
      'isVisible': ?instance.isVisible,
      'permanentId': ?instance.permanentId,
    };

SRWebviewWireframeUpdate _$SRWebviewWireframeUpdateFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SRWebviewWireframeUpdate', json, ($checkedConvert) {
  final val = SRWebviewWireframeUpdate(
    id: $checkedConvert('id', (v) => (v as num).toInt()),
    x: $checkedConvert('x', (v) => (v as num?)?.toInt()),
    y: $checkedConvert('y', (v) => (v as num?)?.toInt()),
    width: $checkedConvert('width', (v) => (v as num?)?.toInt()),
    height: $checkedConvert('height', (v) => (v as num?)?.toInt()),
    clip: $checkedConvert(
      'clip',
      (v) =>
          v == null ? null : SRContentClip.fromJson(v as Map<String, dynamic>),
    ),
    shapeStyle: $checkedConvert(
      'shapeStyle',
      (v) =>
          v == null ? null : SRShapeStyle.fromJson(v as Map<String, dynamic>),
    ),
    border: $checkedConvert(
      'border',
      (v) =>
          v == null ? null : SRShapeBorder.fromJson(v as Map<String, dynamic>),
    ),
    slotId: $checkedConvert('slotId', (v) => v as String),
    isVisible: $checkedConvert('isVisible', (v) => v as bool?),
  );
  return val;
});

Map<String, dynamic> _$SRWebviewWireframeUpdateToJson(
  SRWebviewWireframeUpdate instance,
) => <String, dynamic>{
  'id': instance.id,
  'x': ?instance.x,
  'y': ?instance.y,
  'width': ?instance.width,
  'height': ?instance.height,
  'clip': ?instance.clip?.toJson(),
  'shapeStyle': ?instance.shapeStyle?.toJson(),
  'border': ?instance.border?.toJson(),
  'type': instance.type,
  'slotId': instance.slotId,
  'isVisible': ?instance.isVisible,
};
