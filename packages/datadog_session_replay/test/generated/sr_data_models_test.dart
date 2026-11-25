// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:convert';

import 'package:datadog_session_replay/src/generated/sr_data_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sr_samples.dart';

/// [json], a JSON object.
Map<String, dynamic> decoded(String json) => switch (jsonDecode(json)) {
  final Map<String, dynamic> object => object,
  final other => throw FormatException('Not a JSON object: $other'),
};

/// [model] encoded to JSON text and decoded back, as the native code reads
/// it.
Map<String, dynamic> encoded(Object model) => decoded(jsonEncode(model));

/// The paths of the keys of [before] that [after] does not have, or has
/// with another value.
List<String> differences(Object? before, Object? after, [String path = r'$']) {
  if (before is Map && after is Map) {
    return [
      for (final MapEntry(:key, :value) in before.entries)
        if (after.containsKey(key))
          ...differences(value, after[key], '$path.$key')
        else
          '$path.$key: missing',
    ];
  }
  if (before is List && after is List && before.length == after.length) {
    return [
      for (var i = 0; i < before.length; i++)
        ...differences(before[i], after[i], '$path[$i]'),
    ];
  }
  return before == after ? [] : ['$path: $before -> $after'];
}

void main() {
  // The fields every wireframe requires.
  const frame = {'id': 1, 'x': 2, 'y': 3, 'width': 4, 'height': 5};

  group('the official mobile samples', () {
    // Sample -> the keys its round trip drops: keys no mobile schema
    // declares, which the samples may still have because the schemas allow
    // additional properties.
    const undeclaredStyleType = 'textStyle.type: missing';
    final dropped = {
      'record/full-snapshot-record-with-composition-tree.json': [
        '\$.data.wireframes[1].$undeclaredStyleType',
      ],
      'record/full-snapshot-record.json': [
        '\$.data.wireframes[0].$undeclaredStyleType',
      ],
      'record/has-focus-record.json': <String>[],
      'record/incremental-snapshot-record-composition-tree-mutation.json':
          <String>[],
      'record/incremental-snapshot-record.json': [
        '\$.data.adds[0].wireframe.$undeclaredStyleType',
        '\$.data.updates[0].$undeclaredStyleType',
      ],
      'record/metadata-record.json': <String>[],
      'record/view-end-record.json': <String>[],
      'segment/segment.json': [
        // The schema calls it has_full_snapshot.
        r'$.has_full_snapshot_record: missing',
        // Only in the browser segment schema.
        r'$.creation_reason: missing',
        '\$.records[0].data.wireframes[1].$undeclaredStyleType',
        '\$.records[1].data.adds[0].wireframe.$undeclaredStyleType',
        '\$.records[1].data.updates[0].$undeclaredStyleType',
      ],
    };

    test('are all listed here', () {
      expect(dropped.keys, unorderedEquals(srSamples.keys));
    });

    for (final MapEntry(key: sample, value: json) in srSamples.entries) {
      test('round-trip $sample', () {
        final original = decoded(json);
        final Object model = sample.startsWith('segment/')
            ? SRSegment.fromJson(original)
            : SRRecord.fromJson(original);
        expect(
          differences(original, encoded(model)),
          unorderedEquals(dropped[sample] ?? const <String>[]),
        );
      });
    }
  });

  group('unions', () {
    final decoders = <String, Object Function(Map<String, dynamic>)>{
      'SRRecord': SRRecord.fromJson,
      'SRIncrementalSnapshotData': SRIncrementalSnapshotData.fromJson,
      'SRWireframe': SRWireframe.fromJson,
      'SRIncrementalUpdate': SRIncrementalUpdate.fromJson,
      'SRShapeGradient': SRShapeGradient.fromJson,
      'SRCompositionLayerModifier': SRCompositionLayerModifier.fromJson,
    };

    // Union -> the smallest JSON of each of its variants, with the
    // discriminator dd-sdk-ios decodes them by, and the variant it is.
    final variants = <(String, Map<String, dynamic>, TypeMatcher<Object>)>[
      (
        'SRRecord',
        {
          'timestamp': 1,
          'type': 4,
          'data': {'width': 1, 'height': 1},
        },
        isA<SRMetaRecord>(),
      ),
      (
        'SRRecord',
        {
          'timestamp': 1,
          'type': 6,
          'data': {'has_focus': true},
        },
        isA<SRFocusRecord>(),
      ),
      ('SRRecord', {'timestamp': 1, 'type': 7}, isA<SRViewEndRecord>()),
      (
        'SRRecord',
        {
          'timestamp': 1,
          'type': 8,
          'data': {
            'height': 0.5,
            'offsetLeft': 0.5,
            'offsetTop': 0.5,
            'pageLeft': 0.5,
            'pageTop': 0.5,
            'scale': 0.5,
            'width': 0.5,
          },
        },
        isA<SRVisualViewportRecord>(),
      ),
      (
        'SRRecord',
        {
          'timestamp': 1,
          'type': 10,
          'data': {'wireframes': <Object?>[]},
        },
        isA<SRFullSnapshotRecord>(),
      ),
      (
        'SRRecord',
        {
          'timestamp': 1,
          'type': 11,
          'data': {'source': 2},
        },
        isA<SRIncrementalSnapshotRecord>(),
      ),
      (
        'SRIncrementalSnapshotData',
        {
          'source': 0,
          'adds': <Object?>[],
          'removes': <Object?>[],
          'updates': <Object?>[],
        },
        isA<SRIncrementalMutationData>(),
      ),
      ('SRIncrementalSnapshotData', {'source': 2}, isA<SRTouchData>()),
      (
        'SRIncrementalSnapshotData',
        {'source': 4, 'width': 1, 'height': 1},
        isA<SRViewportResizeData>(),
      ),
      (
        'SRIncrementalSnapshotData',
        {
          'source': 9,
          'pointerEventType': 'down',
          'pointerType': 'touch',
          'pointerId': 1,
          'x': 0.5,
          'y': 0.5,
        },
        isA<SRPointerInteractionData>(),
      ),
      (
        'SRIncrementalSnapshotData',
        {'source': 10},
        isA<SRCompositionTreeMutationData>(),
      ),
      ('SRWireframe', {...frame, 'type': 'shape'}, isA<SRShapeWireframe>()),
      (
        'SRWireframe',
        {
          ...frame,
          'type': 'text',
          'text': 'a',
          'textStyle': {'family': 'a', 'size': 1, 'color': 'a'},
        },
        isA<SRTextWireframe>(),
      ),
      ('SRWireframe', {...frame, 'type': 'image'}, isA<SRImageWireframe>()),
      (
        'SRWireframe',
        {...frame, 'type': 'placeholder'},
        isA<SRPlaceholderWireframe>(),
      ),
      (
        'SRWireframe',
        {...frame, 'type': 'webview', 'slotId': 'a'},
        isA<SRWebviewWireframe>(),
      ),
      (
        'SRWireframe',
        {...frame, 'type': 'embedded_content', 'slotId': 'a'},
        isA<SREmbeddedContentWireframe>(),
      ),
      (
        'SRIncrementalUpdate',
        {'id': 1, 'type': 'shape'},
        isA<SRShapeWireframeUpdate>(),
      ),
      (
        'SRIncrementalUpdate',
        {'id': 1, 'type': 'text'},
        isA<SRTextWireframeUpdate>(),
      ),
      (
        'SRIncrementalUpdate',
        {'id': 1, 'type': 'image'},
        isA<SRImageWireframeUpdate>(),
      ),
      (
        'SRIncrementalUpdate',
        {'id': 1, 'type': 'placeholder'},
        isA<SRPlaceholderWireframeUpdate>(),
      ),
      (
        'SRIncrementalUpdate',
        {'id': 1, 'type': 'webview', 'slotId': 'a'},
        isA<SRWebviewWireframeUpdate>(),
      ),
      (
        'SRIncrementalUpdate',
        {'id': 1, 'type': 'embedded_content', 'slotId': 'a'},
        isA<SREmbeddedContentWireframeUpdate>(),
      ),
      (
        'SRShapeGradient',
        {
          'type': 'linear',
          'stops': <Object?>[],
          'startPoint': {'x': 0.5, 'y': 0.5},
          'endPoint': {'x': 0.5, 'y': 0.5},
        },
        isA<SRShapeLinearGradient>(),
      ),
      (
        'SRCompositionLayerModifier',
        {'type': 'clip', 'path': 'a'},
        isA<SRCompositionLayerClipModifier>(),
      ),
      (
        'SRCompositionLayerModifier',
        {'type': 'opacity', 'value': 0.5},
        isA<SRCompositionLayerOpacityModifier>(),
      ),
      (
        'SRCompositionLayerModifier',
        {'type': 'colorMatrix', 'matrix': <Object?>[]},
        isA<SRCompositionLayerColorMatrixModifier>(),
      ),
      (
        'SRCompositionLayerModifier',
        {'type': 'gaussianBlur', 'radius': 0.5},
        isA<SRCompositionLayerGaussianBlurModifier>(),
      ),
      (
        'SRCompositionLayerModifier',
        {
          'type': 'shadow',
          'color': 'a',
          'offsetX': 0.5,
          'offsetY': 0.5,
          'radius': 0.5,
        },
        isA<SRCompositionLayerShadowModifier>(),
      ),
      (
        'SRCompositionLayerModifier',
        {'type': 'brightnessBias', 'value': 0.5},
        isA<SRCompositionLayerBrightnessBiasModifier>(),
      ),
      (
        'SRCompositionLayerModifier',
        {'type': 'saturate', 'value': 0.5},
        isA<SRCompositionLayerSaturateModifier>(),
      ),
      (
        'SRCompositionLayerModifier',
        {'type': 'maskImage', 'resourceId': 'a'},
        isA<SRCompositionLayerMaskImageModifier>(),
      ),
    ];

    for (final (union, json, variant) in variants) {
      final discriminator = json['type'] ?? json['source'];
      test('$union decodes $discriminator and writes it back', () {
        final decode = decoders[union];
        expect(decode, isNotNull, reason: 'No decoder for $union');
        if (decode == null) return;
        final model = decode(json);
        expect(model, variant);
        expect(encoded(model), json);
      });
    }

    test('fail on an unknown discriminator', () {
      expect(
        () => SRWireframe.fromJson({...frame, 'type': 'triangle'}),
        throwsFormatException,
      );
    });

    test('expose the fields every kind of wireframe has', () {
      final wireframe = SRWireframe.fromJson({...frame, 'type': 'shape'});
      expect(
        [
          wireframe.id,
          wireframe.x,
          wireframe.y,
          wireframe.width,
          wireframe.height,
          wireframe.clip,
          wireframe.type,
          wireframe.permanentId,
        ],
        [1, 2, 3, 4, 5, null, 'shape', null],
      );
    });
  });

  test('SREnrichedRecord has the keys the iOS and Android code read', () {
    const record = SREnrichedRecord(
      records: [SRViewEndRecord(timestamp: 1)],
      applicationID: 'application',
      sessionID: 'session',
      viewID: 'view',
    );
    final json = encoded(record);
    expect(json, {
      'records': [
        {'timestamp': 1, 'type': 7},
      ],
      'applicationID': 'application',
      'sessionID': 'session',
      'viewID': 'view',
    });
    expect(SREnrichedRecord.fromJson(json), record);
  });
}
