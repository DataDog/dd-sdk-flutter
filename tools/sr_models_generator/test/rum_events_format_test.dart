// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

/// Resolves the real mobile Session Replay schemas at the pinned
/// rum-events-format commit, and checks how the generated unions tell their
/// variants apart and the keys of SREnrichedRecord.
///
/// The first run downloads the pinned commit into `.tmp/`; later runs
/// reuse it offline.
///
/// When moving the pin changes these, this test fails with the difference:
/// check it against dd-sdk-ios' `SRDataModels.swift`, then update the
/// expectations here.
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
      cacheDirectory: p.join(package, '.tmp', 'rum-events-format'),
    );
    final resolver = ModelResolver(
      SchemaLoader(checkout.directory, mounts: config.schemaMounts),
      naming: config.naming,
    );
    root = resolver.resolveRoots(config.rootSchemas).first;
    definitions = {for (final d in resolver.definitions) d.name: d};
  });

  /// The union named [name].
  UnionDefinition unionNamed(String name) => switch (definitions[name]) {
    final UnionDefinition union => union,
    final other => throw StateError('$name is not a union: $other'),
  };

  test('the root type is SRSegment', () {
    expect(
      root,
      isA<NamedType>().having((t) => t.definition.name, 'name', 'SRSegment'),
    );
  });

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

  for (final MapEntry(key: name, value: (key, variants)) in unions.entries) {
    test('$name is told apart by "$key"', () {
      final union = unionNamed(name);
      expect(union.discriminatorKey, key);
      expect({
        for (final MapEntry(key: tag, value: variant) in union.variants.entries)
          tag: variant.name,
      }, variants);
    });
  }

  group('SREnrichedRecord', () {
    test('has the keys the iOS and Android code read', () {
      final envelope = switch (definitions['SREnrichedRecord']) {
        final ClassDefinition envelope => envelope,
        final other => throw StateError('Not a class: $other'),
      };
      expect(envelope.location, 'flutter/enriched-record-schema.json');
      expect(
        [
          for (final field in envelope.fields)
            (field.jsonKey, field.dartName, '${field.type}', field.isRequired),
        ],
        [
          ('records', 'records', 'List<SRRecord>', true),
          ('applicationID', 'applicationID', 'string', true),
          ('sessionID', 'sessionID', 'string', true),
          ('viewID', 'viewID', 'string', true),
        ],
      );
    });
  });

  test('wireframes expose the fields every kind of wireframe has', () {
    final wireframe = unionNamed('SRWireframe');
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
