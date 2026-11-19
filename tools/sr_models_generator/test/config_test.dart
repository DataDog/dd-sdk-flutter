// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sr_models_generator/sr_models_generator.dart';
import 'package:test/test.dart';

const _sha = '0123456789abcdef0123456789abcdef01234567';
const _otherSha = 'fedcba9876543210fedcba9876543210fedcba98';

const _valid =
    '''
# Header comment.
rum_events_format:
  repository: https://example.com/rum-events-format.git
  # The pinned commit.
  commit: $_sha  # trailing comment
root_schema: schemas/root-schema.json
output: ../out/models.dart
''';

void main() {
  final file = p.join('config', 'sr_models_generator.yaml');

  Matcher throwsConfigException(String message) => throwsA(
    isA<ConfigException>().having(
      (e) => e.message,
      'message',
      contains(message),
    ),
  );

  group('parse', () {
    test('reads every setting', () {
      final config = GeneratorConfig.parse(_valid, file: file);
      expect(config.file, file);
      expect(config.repository, 'https://example.com/rum-events-format.git');
      expect(config.commit, _sha);
      expect(config.rootSchema, 'schemas/root-schema.json');
    });

    test('uses the default naming when the file does not set it', () {
      final naming = GeneratorConfig.parse(_valid, file: file).naming;
      expect(naming.typePrefix, 'SR');
      expect(naming.stripFromTitles, ['Mobile']);
      expect(naming.renames, isEmpty);
    });

    test('reads the naming settings', () {
      final naming = GeneratorConfig.parse('''
$_valid
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
          () => GeneratorConfig.parse('$_valid\n$setting\n', file: file),
          throwsConfigException(message),
        );
      });
    }

    test('resolves the output relative to the configuration file', () {
      final config = GeneratorConfig.parse(_valid, file: file);
      expect(config.output, p.join('out', 'models.dart'));
    });

    test('fails on invalid YAML or a non-map document', () {
      expect(
        () => GeneratorConfig.parse('a: [', file: file),
        throwsConfigException('Invalid YAML'),
      );
      expect(
        () => GeneratorConfig.parse('- a', file: file),
        throwsConfigException('Expected a YAML map'),
      );
    });

    test('fails on missing or empty settings', () {
      for (final (key, message) in [
        ('repository', 'rum_events_format.repository'),
        ('commit', 'rum_events_format.commit'),
        ('root_schema', 'root_schema'),
        ('output', 'output'),
      ]) {
        final withoutKey = _valid
            .split('\n')
            .where((line) => !line.trimLeft().startsWith('$key:'))
            .join('\n');
        expect(
          () => GeneratorConfig.parse(withoutKey, file: file),
          throwsConfigException('"$message" must be a non-empty string'),
          reason: 'without $key',
        );
      }
      expect(
        () => GeneratorConfig.parse(
          _valid.replaceFirst('output: ../out/models.dart', 'output: " "'),
          file: file,
        ),
        throwsConfigException('"output" must be a non-empty string'),
      );
      expect(
        () => GeneratorConfig.parse('root_schema: x\noutput: y\n', file: file),
        throwsConfigException('"rum_events_format" must be a map'),
      );
    });

    test('requires the commit to be a full SHA', () {
      for (final commit in [
        'master',
        'v1.0.0',
        '748d7fe',
        _sha.toUpperCase(),
      ]) {
        expect(
          () => GeneratorConfig.parse(
            _valid.replaceFirst(_sha, commit),
            file: file,
          ),
          throwsConfigException('full 40-character commit SHA'),
          reason: commit,
        );
      }
    });
  });

  group('replaceCommit', () {
    test('changes only the commit, keeping comments and layout', () {
      final updated = GeneratorConfig.replaceCommit(
        _valid,
        _otherSha,
        file: file,
      );
      expect(updated, _valid.replaceFirst(_sha, _otherSha));
      expect(GeneratorConfig.parse(updated, file: file).commit, _otherSha);
    });

    test('rejects anything but a full SHA', () {
      expect(
        () => GeneratorConfig.replaceCommit(_valid, 'master', file: file),
        throwsConfigException('full 40-character commit SHA'),
      );
    });

    test('fails when there is not exactly one commit entry', () {
      expect(
        () => GeneratorConfig.replaceCommit(
          '$_valid\nother:\n  commit: $_sha\n',
          _otherSha,
          file: file,
        ),
        throwsConfigException('found 2'),
      );
    });

    test('fails when the edit does not change rum_events_format.commit', () {
      // The only indented "commit:" is under another key.
      const misplaced =
          '''
rum_events_format:
  repository: https://example.com/rum-events-format.git
  pinned: $_sha
other:
  commit: $_sha
root_schema: schemas/root-schema.json
output: out.dart
''';
      expect(
        () => GeneratorConfig.replaceCommit(misplaced, _otherSha, file: file),
        throwsA(isA<ConfigException>()),
      );
    });
  });

  group('load and writeCommit', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('sr_config_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('read and update the file on disk', () {
      final path = p.join(dir.path, 'sr_models_generator.yaml');
      File(path).writeAsStringSync(_valid);

      GeneratorConfig.load(path).writeCommit(_otherSha);

      expect(
        File(path).readAsStringSync(),
        _valid.replaceFirst(_sha, _otherSha),
      );
      expect(GeneratorConfig.load(path).commit, _otherSha);
    });

    test('load fails when the file does not exist', () {
      expect(
        () => GeneratorConfig.load(p.join(dir.path, 'missing.yaml')),
        throwsConfigException('not found'),
      );
    });
  });

  test('the repository configuration is valid', () {
    final config = GeneratorConfig.load('sr_models_generator.yaml');
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
    expect(config.rootSchema, 'schemas/session-replay-mobile-schema.json');
    expect(
      config.output,
      p.normalize(
        '../../packages/datadog_session_replay/lib/src/generated/sr_data_models.dart',
      ),
    );
  });
}
