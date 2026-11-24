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

    final invalidNaming = {
      'type_prefix: ""': '"type_prefix" must be a non-empty string',
      'type_prefix: [SR]': '"type_prefix" must be a non-empty string',
      'strip_from_titles: Mobile':
          '"strip_from_titles" must be a list of non-empty strings',
      'strip_from_titles: [Mobile, ""]':
          '"strip_from_titles" must be a list of non-empty strings',
      'type_renames: [SRA]':
          '"type_renames" must map non-empty strings to non-empty strings',
      'type_renames: {SRA: ""}':
          '"type_renames" must map non-empty strings to non-empty strings',
      'type_renames: {SRA: [SRB]}':
          '"type_renames" must map non-empty strings to non-empty strings',
    };
    for (final MapEntry(key: setting, value: message)
        in invalidNaming.entries) {
      test('fails on $setting', () {
        expect(
          () => GeneratorConfig.parse('$valid\n$setting\n', file: file),
          throwsConfigException(message),
        );
      });
    }

    test('resolves the output relative to the configuration file', () {
      final config = GeneratorConfig.parse(valid, file: file);
      expect(config.output, p.join('out', 'models.dart'));
    });

    // Description -> (configuration, the error it gives).
    final invalidFiles = {
      'invalid YAML': ('a: [', 'Invalid YAML'),
      'a document that is not a map': ('- a', 'Expected a YAML map'),
      'a missing repository': (
        without('repository'),
        '"rum_events_format.repository" must be a non-empty string',
      ),
      'a missing commit': (
        without('commit'),
        '"rum_events_format.commit" must be a non-empty string',
      ),
      'missing root_schemas': (
        without(
          'root_schemas',
        ).replaceFirst('  - schemas/root-schema.json\n', ''),
        '"root_schemas" must be a non-empty list of non-empty strings',
      ),
      'empty root_schemas': (
        valid.replaceFirst(
          'root_schemas:\n  - schemas/root-schema.json',
          'root_schemas: []',
        ),
        '"root_schemas" must be a non-empty list of non-empty strings',
      ),
      'a root_schemas that is not a list': (
        valid.replaceFirst(
          'root_schemas:\n  - schemas/root-schema.json',
          'root_schemas: schemas/root-schema.json',
        ),
        '"root_schemas" must be a list of non-empty strings',
      ),
      'a blank local_schemas': (
        '$valid\nlocal_schemas: " "\n',
        '"local_schemas" must be a non-empty string',
      ),
      'a local_schemas that does not exist': (
        '$valid\nlocal_schemas: missing\n',
        '"local_schemas" is not a directory',
      ),
      'a missing output': (
        without('output'),
        '"output" must be a non-empty string',
      ),
      'a blank output': (
        valid.replaceFirst('output: ../out/models.dart', 'output: " "'),
        '"output" must be a non-empty string',
      ),
      'a missing rum_events_format': (
        'root_schemas: [x]\noutput: y\n',
        '"rum_events_format" must be a map',
      ),
    };
    for (final MapEntry(key: description, value: (source, message))
        in invalidFiles.entries) {
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
          throwsConfigException('full 40-character commit SHA'),
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
  });
}
