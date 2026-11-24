// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

/// Resolves the real mobile Session Replay schemas at the pinned
/// rum-events-format commit, and checks how the generated unions tell their
/// variants apart, the keys of SREnrichedRecord, and that the official
/// samples round-trip.
///
/// The first run downloads the pinned commit into `.tmp/`; later runs
/// reuse it offline.
///
/// When moving the pin changes these, this test fails with the difference:
/// check it against dd-sdk-ios' `SRDataModels.swift`, then update the
/// expectations here.
@Tags(['rum-events-format'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sr_models_generator/sr_models_generator.dart';
import 'package:test/test.dart';

import 'support/package_root.dart';
import 'support/round_trip.dart';

void main() {
  late TypeRef root;
  late Map<String, Definition> definitions;
  late List<Definition> sorted;
  late String samples;

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
    sorted = resolver.definitions;
    definitions = {for (final d in sorted) d.name: d};
    samples = p.join(checkout.directory, 'samples', 'session-replay', 'mobile');
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

  group('the official mobile samples', () {
    // Every sample of samples/session-replay/mobile -> the differences its
    // round trip may have: keys that no mobile schema declares, which the
    // generated models drop. The samples still validate
    // because the schemas allow additional properties.
    const undeclaredStyleType = 'textStyle.type: missing';
    final differencesBySample = {
      'record/full-snapshot-record.json': [
        '\$.data.wireframes[0].$undeclaredStyleType',
      ],
      'record/full-snapshot-record-with-composition-tree.json': [
        '\$.data.wireframes[1].$undeclaredStyleType',
      ],
      'record/has-focus-record.json': <String>[],
      'record/incremental-snapshot-record.json': [
        '\$.data.adds[0].wireframe.$undeclaredStyleType',
        '\$.data.updates[0].$undeclaredStyleType',
      ],
      'record/incremental-snapshot-record-composition-tree-mutation.json':
          <String>[],
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
    late Map<String, RoundTripResult> results;

    setUpAll(() async {
      results = {
        for (final result
            in await roundTrip(const DartPrinter().printLibrary(sorted), [
              for (final sample in differencesBySample.keys)
                RoundTripCase(
                  sample,
                  sample.startsWith('segment/') ? 'SRSegment' : 'SRRecord',
                  jsonDecode(File(p.join(samples, sample)).readAsStringSync()),
                ),
            ]))
          result.name: result,
      };
    });

    test('are all listed here', () {
      final files = [
        for (final file in Directory(samples).listSync(recursive: true))
          if (file is File && file.path.endsWith('.json'))
            p.posix.joinAll(p.split(p.relative(file.path, from: samples))),
      ];
      expect(files, unorderedEquals(differencesBySample.keys));
    });

    for (final MapEntry(key: sample, value: differences)
        in differencesBySample.entries) {
      test('round-trip $sample', () {
        expect(results[sample]?.errors, unorderedEquals(differences));
      });
    }
  });

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

    test('round-trips real records', () async {
      Object? sample(String name) =>
          jsonDecode(File(p.join(samples, 'record', name)).readAsStringSync());
      final [result] = await roundTrip(
        const DartPrinter().printLibrary(sorted),
        [
          RoundTripCase('an envelope', 'SREnrichedRecord', {
            'records': [
              sample('metadata-record.json'),
              sample('has-focus-record.json'),
              sample('view-end-record.json'),
            ],
            'applicationID': 'application',
            'sessionID': 'session',
            'viewID': 'view',
          }),
        ],
      );
      expect(result.errors, isEmpty);
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
