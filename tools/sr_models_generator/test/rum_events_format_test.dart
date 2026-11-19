// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

/// Resolves the real mobile Session Replay schemas at the pinned
/// rum-events-format commit, and checks every type the generator will
/// produce.
///
/// The first run downloads the pinned commit into `.dart_tool/`; later runs
/// reuse it offline.
///
/// When moving the pin changes the types, this test fails with the
/// difference: check it against dd-sdk-ios' `SRDataModels.swift`, then
/// update the expectations here.
@Tags(['rum-events-format'])
library;

import 'package:path/path.dart' as p;
import 'package:sr_models_generator/sr_models_generator.dart';
import 'package:test/test.dart';

import 'support/package_root.dart';

void main() {
  late TypeRef root;
  late Map<String, Definition> definitions;

  setUpAll(() async {
    final package = await packageRoot();
    final config = GeneratorConfig.load(
      p.join(package, 'sr_models_generator.yaml'),
    );
    final checkout = await checkoutCommit(
      repository: config.repository,
      sha: config.commit,
      cacheDirectory: p.join(package, '.dart_tool', 'rum-events-format'),
    );
    final resolver = ModelResolver(
      SchemaLoader(checkout.directory),
      naming: config.naming,
    );
    root = resolver.resolveRoot(config.rootSchema);
    definitions = {for (final d in resolver.definitions) d.name: d};
  });

  test('the root type is SRSegment', () {
    expect(root, NamedType(definitions['SRSegment']!));
  });

  // Every type. The names are those of the hand-written
  // `packages/datadog_session_replay/lib/src/sr_data_models.dart` for the
  // types it has (through `type_renames`), and otherwise those of dd-sdk-ios'
  // `SRDataModels.swift`. They differ from dd-sdk-ios for:
  //
  //   dd-sdk-ios                                        here
  //   SRIncrementalSnapshotRecord.Data                  SRIncrementalSnapshotData
  //   ...Data.MutationData                              SRIncrementalMutationData
  //   ...Data.MutationData.Adds                         SRIncrementalAdd
  //   ...Data.MutationData.Removes                      SRIncrementalRemove
  //   ...Data.MutationData.Updates                      SRIncrementalUpdate
  //   ...Data.MutationData.Updates.<Kind>WireframeUpdate
  //                                                     SR<Kind>WireframeUpdate
  //   ...Data.PointerInteractionData                    SRPointerInteractionData
  //   ...Data.PointerInteractionData.PointerEventType   SRPointerEventType
  //   ...Data.PointerInteractionData.PointerType        SRPointerType
  //   ...Data.TouchData                                 SRTouchData
  //   ...Data.TouchData.Positions                       SRTouchDataPositions
  //   ...Data.ViewportResizeData                        SRViewportResizeData
  //   SRTextPosition.Alignment                          SRAlignment
  //   SRTextPosition.Alignment.Horizontal               SRHorizontalAlignment
  //   SRTextPosition.Alignment.Vertical                 SRVerticalAlignment
  //   SRTextPosition.Padding                            SRPadding
  //
  // The hand-written models also have `SRIdHolder`, one type for the
  // segment's application, session and view, which the schema declares as
  // three objects; `SRRecordType`, whose values are each record's `type`
  // here; and `SREnrichedRecord`, which is not in the schema.
  const classes = {
    'SRCompositionLayer',
    'SRCompositionLayerBrightnessBiasModifier',
    'SRCompositionLayerChild',
    'SRCompositionLayerClipModifier',
    'SRCompositionLayerColorMatrixModifier',
    'SRCompositionLayerGaussianBlurModifier',
    'SRCompositionLayerMaskImageModifier',
    'SRCompositionLayerOpacityModifier',
    'SRCompositionLayerSaturateModifier',
    'SRCompositionLayerShadowModifier',
    'SRCompositionLayerUpdate',
    'SRCompositionTree',
    'SRCompositionTreeMutationData',
    'SRContentClip',
    'SREmbeddedContentWireframe',
    'SREmbeddedContentWireframeUpdate',
    'SRFocusRecord',
    'SRFocusRecordData',
    'SRFullSnapshotRecord',
    'SRFullSnapshotRecordData',
    'SRImageWireframe',
    'SRImageWireframeUpdate',
    'SRIncrementalSnapshotRecord',
    'SRMetaRecord',
    'SRMetaRecordData',
    'SRIncrementalMutationData',
    'SRIncrementalAdd',
    'SRIncrementalRemove',
    'SRPlaceholderWireframe',
    'SRPlaceholderWireframeUpdate',
    'SRPointerInteractionData',
    'SRSegment',
    'SRSegmentApplication',
    'SRSegmentSession',
    'SRSegmentView',
    'SRShapeBorder',
    'SRShapeGradientPoint',
    'SRShapeGradientStop',
    'SRShapeLinearGradient',
    'SRShapeStyle',
    'SRShapeWireframe',
    'SRShapeWireframeUpdate',
    'SRTextPosition',
    'SRAlignment',
    'SRPadding',
    'SRTextStyle',
    'SRTextWireframe',
    'SRTextWireframeUpdate',
    'SRTouchData',
    'SRTouchDataPositions',
    'SRViewEndRecord',
    'SRViewportResizeData',
    'SRVisualViewportRecord',
    'SRVisualViewportRecordData',
    'SRWebviewWireframe',
    'SRWebviewWireframeUpdate',
  };

  const enums = {
    'SRCompositionLayerChildType',
    'SRCompositionLayerClipModifierFillRule',
    'SRCompositionLayerCompositeOperation',
    'SRCompositionLayerUpdateCompositeOperation',
    'SRPointerEventType',
    'SRPointerType',
    'SRSegmentSource',
    'SRHorizontalAlignment',
    'SRVerticalAlignment',
    'SRTextStyleTruncationMode',
  };

  // Union -> discriminator key and its value per variant, as dd-sdk-ios
  // decodes them.
  const unions = {
    'SRRecord': (
      'type',
      {
        10: 'SRFullSnapshotRecord',
        11: 'SRIncrementalSnapshotRecord',
        4: 'SRMetaRecord',
        6: 'SRFocusRecord',
        7: 'SRViewEndRecord',
        8: 'SRVisualViewportRecord',
      },
    ),
    'SRIncrementalSnapshotData': (
      'source',
      {
        0: 'SRIncrementalMutationData',
        2: 'SRTouchData',
        4: 'SRViewportResizeData',
        9: 'SRPointerInteractionData',
        10: 'SRCompositionTreeMutationData',
      },
    ),
    'SRWireframe': (
      'type',
      {
        'shape': 'SRShapeWireframe',
        'text': 'SRTextWireframe',
        'image': 'SRImageWireframe',
        'placeholder': 'SRPlaceholderWireframe',
        'webview': 'SRWebviewWireframe',
        'embedded_content': 'SREmbeddedContentWireframe',
      },
    ),
    'SRIncrementalUpdate': (
      'type',
      {
        'text': 'SRTextWireframeUpdate',
        'shape': 'SRShapeWireframeUpdate',
        'image': 'SRImageWireframeUpdate',
        'placeholder': 'SRPlaceholderWireframeUpdate',
        'webview': 'SRWebviewWireframeUpdate',
        'embedded_content': 'SREmbeddedContentWireframeUpdate',
      },
    ),
    'SRShapeGradient': ('type', {'linear': 'SRShapeLinearGradient'}),
    'SRCompositionLayerModifier': (
      'type',
      {
        'clip': 'SRCompositionLayerClipModifier',
        'opacity': 'SRCompositionLayerOpacityModifier',
        'colorMatrix': 'SRCompositionLayerColorMatrixModifier',
        'gaussianBlur': 'SRCompositionLayerGaussianBlurModifier',
        'shadow': 'SRCompositionLayerShadowModifier',
        'brightnessBias': 'SRCompositionLayerBrightnessBiasModifier',
        'saturate': 'SRCompositionLayerSaturateModifier',
        'maskImage': 'SRCompositionLayerMaskImageModifier',
      },
    ),
  };

  test('generates exactly the expected classes', () {
    expect({
      for (final d in definitions.values)
        if (d is ClassDefinition) d.name,
    }, classes);
  });

  test('generates exactly the expected enums', () {
    expect({
      for (final d in definitions.values)
        if (d is EnumDefinition) d.name,
    }, enums);
  });

  test('generates exactly the expected unions', () {
    expect({
      for (final d in definitions.values)
        if (d is UnionDefinition) d.name,
    }, unions.keys.toSet());
  });

  for (final MapEntry(key: name, value: (key, variants)) in unions.entries) {
    test('$name is told apart by "$key"', () {
      final union = definitions[name]! as UnionDefinition;
      expect(union.discriminatorKey, key);
      expect({
        for (final MapEntry(key: tag, value: variant) in union.variants.entries)
          tag: variant.name,
      }, variants);
    });
  }

  test('wireframes expose the fields every kind of wireframe has', () {
    final wireframe = definitions['SRWireframe']! as UnionDefinition;
    expect(wireframe.sharedFields.map((f) => f.dartName), [
      'id',
      'x',
      'y',
      'width',
      'height',
      'clip',
      'type',
      'permanentId',
    ]);
  });
}
