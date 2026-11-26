// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sr_models_generator/sr_models_generator.dart';
import 'package:test/test.dart';

import 'support/package_root.dart';

void main() {
  const sha = '0123456789abcdef0123456789abcdef01234567';
  const otherSha = 'fedcba9876543210fedcba9876543210fedcba98';
  const valid =
      '''
# Header comment.
rum_events_format:
  repository: https://example.com/rum-events-format.git
  # The pinned commit.
  commit: $sha  # trailing comment
root_schemas:
  - schemas/root-schema.json
output: ../out/models.dart
''';
  final file = p.join('config', 'sr_models_generator.yaml');

  Matcher throwsConfigException(String message) => throwsA(
    isA<ConfigException>().having(
      (e) => e.message,
      'message',
      contains(message),
    ),
  );

  /// [valid] without the line that sets [key].
  String without(String key) => valid
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('$key:'))
      .join('\n');

  group('parse', () {
    test('reads every setting', () {
      final config = GeneratorConfig.parse(valid, file: file);
      expect(config.file, file);
      expect(config.repository, 'https://example.com/rum-events-format.git');
      expect(config.commit, sha);
      expect(config.rootSchemas, ['schemas/root-schema.json']);
      expect(config.localSchemas, isNull);
      expect(config.schemaMounts, isEmpty);
    });

    test('uses the default naming when the file does not set it', () {
      final naming = GeneratorConfig.parse(valid, file: file).naming;
      expect(naming.typePrefix, 'SR');
      expect(naming.stripFromTitles, ['Mobile']);
      expect(naming.renames, isEmpty);
    });

    test('reads the naming settings', () {
      final naming = GeneratorConfig.parse('''
$valid
type_prefix: DD
strip_from_titles: [Mobile, Common]
type_renames:
  SRWireframeClip: SRContentClip
  "a.json#/properties/b": SRB
''', file: file).naming;
      expect(naming.typePrefix, 'DD');
      expect(naming.stripFromTitles, ['Mobile', 'Common']);
      expect(naming.renames, {
        'SRWireframeClip': 'SRContentClip',
        'a.json#/properties/b': 'SRB',
      });
    });

    test('resolves the output relative to the configuration file', () {
      final config = GeneratorConfig.parse(valid, file: file);
      expect(config.output, p.join('out', 'models.dart'));
    });

    test('reads the samples, resolving their output against the file', () {
      final config = GeneratorConfig.parse(
        '${valid}samples:\n  directory: samples/mobile\n  output: gen.dart\n',
        file: file,
      );
      expect(config.samples?.directory, 'samples/mobile');
      expect(config.samples?.output, p.join('config', 'gen.dart'));
    });

    test('has no samples when the file does not set them', () {
      expect(GeneratorConfig.parse(valid, file: file).samples, isNull);
    });

    // Description -> (configuration, the error it gives).
    final invalid = {
      'invalid YAML': ('a: [', 'Expected node content'),
      'a document that is not a map': ('- a', 'Not a map'),
      'an unknown setting': ('${valid}type_prefx: DD\n', 'Unrecognized keys'),
      'an unknown rum_events_format setting': (
        valid.replaceFirst('  # The pinned commit.', '  branch: master'),
        'Unrecognized keys: [branch]',
      ),
      'a missing rum_events_format': (
        'root_schemas: [x]\noutput: y\n',
        'Required keys are missing: rum_events_format.',
      ),
      'a missing repository': (
        without('repository'),
        'Required keys are missing: repository.',
      ),
      'a missing commit': (
        without('commit'),
        'Required keys are missing: commit.',
      ),
      'missing root_schemas': (
        without(
          'root_schemas',
        ).replaceFirst('  - schemas/root-schema.json\n', ''),
        'Required keys are missing: root_schemas.',
      ),
      'empty root_schemas': (
        valid.replaceFirst(
          'root_schemas:\n  - schemas/root-schema.json',
          'root_schemas: []',
        ),
        '"root_schemas". Must not be empty.',
      ),
      'a root_schemas that is not a list': (
        valid.replaceFirst(
          'root_schemas:\n  - schemas/root-schema.json',
          'root_schemas: schemas/root-schema.json',
        ),
        'Unsupported value for "root_schemas"',
      ),
      'a missing output': (
        without('output'),
        'Required keys are missing: output.',
      ),
      'a blank output': (
        valid.replaceFirst('output: ../out/models.dart', 'output: " "'),
        '"output". Must not be blank.',
      ),
      'a blank local_schemas': (
        '${valid}local_schemas: " "\n',
        '"local_schemas". Must not be blank.',
      ),
      'a local_schemas that does not exist': (
        '${valid}local_schemas: missing\n',
        '"local_schemas" is not a directory',
      ),
      'a blank type_prefix': (
        '${valid}type_prefix: ""\n',
        '"type_prefix". Must not be blank.',
      ),
      'a type_prefix that is not a string': (
        '${valid}type_prefix: [SR]\n',
        'Unsupported value for "type_prefix"',
      ),
      'a blank strip_from_titles prefix': (
        '${valid}strip_from_titles: [Mobile, ""]\n',
        '"strip_from_titles". Must not be blank.',
      ),
      'a blank type_renames name': (
        '${valid}type_renames: {SRA: ""}\n',
        '"type_renames". Must not be blank.',
      ),
      'samples without an output': (
        '${valid}samples:\n  directory: samples\n',
        'Required keys are missing: output.',
      ),
      'an unknown samples setting': (
        '${valid}samples:\n  directory: a\n  output: b\n  files: c\n',
        'Unrecognized keys: [files]',
      ),
      'a blank samples directory': (
        '${valid}samples:\n  directory: " "\n  output: b\n',
        '"directory". Must not be blank.',
      ),
      'type_renames that is not a map': (
        '${valid}type_renames: [SRA]\n',
        'Unsupported value for "type_renames"',
      ),
    };
    for (final MapEntry(key: description, value: (source, message))
        in invalid.entries) {
      test('fails on $description', () {
        expect(
          () => GeneratorConfig.parse(source, file: file),
          throwsConfigException(message),
        );
      });
    }

    for (final commit in ['master', 'v1.0.0', '748d7fe', sha.toUpperCase()]) {
      test('fails when the commit is "$commit", not a full SHA', () {
        expect(
          () => GeneratorConfig.parse(
            valid.replaceFirst(sha, commit),
            file: file,
          ),
          throwsConfigException(
            '"commit". Must be a full 40-character commit SHA.',
          ),
        );
      });
    }
  });

  group('replaceCommit', () {
    test('changes only the commit, keeping comments and layout', () {
      final updated = GeneratorConfig.replaceCommit(
        valid,
        otherSha,
        file: file,
      );
      expect(updated, valid.replaceFirst(sha, otherSha));
      expect(GeneratorConfig.parse(updated, file: file).commit, otherSha);
    });

    for (final quote in ['"', "'"]) {
      test('replaces a commit between $quote quotes', () {
        final quoted = valid.replaceFirst(sha, '$quote$sha$quote');
        final updated = GeneratorConfig.replaceCommit(
          quoted,
          otherSha,
          file: file,
        );
        expect(GeneratorConfig.parse(updated, file: file).commit, otherSha);
      });
    }

    test('rejects anything but a full SHA', () {
      expect(
        () => GeneratorConfig.replaceCommit(valid, 'master', file: file),
        throwsConfigException('full 40-character commit SHA'),
      );
    });
  });

  group('load and writeCommit', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('sr_config_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('read and update the file on disk', () {
      final path = p.join(dir.path, 'sr_models_generator.yaml');
      File(path).writeAsStringSync(valid);

      GeneratorConfig.load(path).writeCommit(otherSha);

      expect(File(path).readAsStringSync(), valid.replaceFirst(sha, otherSha));
      expect(GeneratorConfig.load(path).commit, otherSha);
    });

    test('mounts local_schemas, relative to the file, as "flutter"', () {
      Directory(p.join(dir.path, 'schemas')).createSync();
      final path = p.join(dir.path, 'sr_models_generator.yaml');
      File(path).writeAsStringSync('$valid\nlocal_schemas: schemas\n');

      final config = GeneratorConfig.load(path);

      expect(config.localSchemas, p.join(dir.path, 'schemas'));
      expect(config.schemaMounts, {'flutter': p.join(dir.path, 'schemas')});
    });

    test('load fails when the file does not exist', () {
      expect(
        () => GeneratorConfig.load(p.join(dir.path, 'missing.yaml')),
        throwsConfigException('not found'),
      );
    });
  });

  test('the repository configuration is valid', () async {
    final root = await packageRoot();
    final config = GeneratorConfig.load(
      p.join(root, 'sr_models_generator.yaml'),
    );
    expect(config.naming.typePrefix, 'SR');
    expect(config.naming.stripFromTitles, ['Mobile']);
    expect(config.naming.renames, {
      'SRWireframeClip': 'SRContentClip',
      'SRTextPositionAlignment': 'SRAlignment',
      'SRAlignmentHorizontal': 'SRHorizontalAlignment',
      'SRAlignmentVertical': 'SRVerticalAlignment',
      'SRTextPositionPadding': 'SRPadding',
      'SRPointerInteractionDataPointerEventType': 'SRPointerEventType',
      'SRPointerInteractionDataPointerType': 'SRPointerType',
      'SRIncrementalData': 'SRIncrementalSnapshotData',
      'SRMutationData': 'SRIncrementalMutationData',
      'SRIncrementalMutationDataAdds': 'SRIncrementalAdd',
      'SRIncrementalMutationDataRemoves': 'SRIncrementalRemove',
      'SRWireframeUpdateMutation': 'SRIncrementalUpdate',
    });
    expect(
      config.repository,
      'https://github.com/DataDog/rum-events-format.git',
    );
    expect(config.rootSchemas, [
      'schemas/session-replay-mobile-schema.json',
      'flutter/enriched-record-schema.json',
    ]);
    expect(config.localSchemas, p.join(root, 'schemas'));
    expect(config.schemaMounts, {'flutter': p.join(root, 'schemas')});
    expect(
      config.output,
      p.normalize(
        p.join(
          root,
          '../../packages/datadog_session_replay/lib/src/generated/sr_data_models.dart',
        ),
      ),
    );
    expect(config.samples?.directory, 'samples/session-replay/mobile');
    expect(
      config.samples?.output,
      p.normalize(
        p.join(
          root,
          '../../packages/datadog_session_replay/test/generated/sr_samples.dart',
        ),
      ),
    );
  });
}
