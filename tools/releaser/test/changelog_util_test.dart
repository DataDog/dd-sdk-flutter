// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:releaser/changelog_util.dart';
import 'package:test/test.dart';

import 'support/test_temp.dart';

void main() {
  late Directory root;
  final logger = Logger('changelog_util_test');

  setUp(() async {
    root = await createTestTempDir('changelog_util_test_');
  });

  tearDown(() => root.delete(recursive: true));

  group('prependChangelogSection', () {
    test('inserts a new section above existing content', () async {
      final file = File(p.join(root.path, 'CHANGELOG.md'))
        ..writeAsStringSync('## 2.2.0\n\n* Old entry.\n');

      await prependChangelogSection(
        file,
        '2.3.0',
        '### Features\n\n- New thing.',
        logger,
        false,
      );

      final contents = file.readAsStringSync();
      expect(
        contents,
        startsWith('## 2.3.0\n\n### Features\n\n- New thing.\n'),
      );
      expect(contents, contains('## 2.2.0'));
      expect(contents, contains('* Old entry.'));
    });

    test(
      'merges into an existing section instead of duplicating the heading',
      () async {
        final file = File(p.join(root.path, 'CHANGELOG.md'))
          ..writeAsStringSync(
            '## 2.1.0\n\n* Support grpc 5.x.\n\n## 2.0.0\n\n* Old entry.\n',
          );

        await prependChangelogSection(
          file,
          '2.1.0',
          '### Features\n\n- New thing.',
          logger,
          false,
        );

        final contents = file.readAsStringSync();
        expect(
          contents,
          '## 2.1.0\n\n### Features\n\n- New thing.\n\n'
          '* Support grpc 5.x.\n\n## 2.0.0\n\n* Old entry.\n',
        );
        expect('## 2.1.0'.allMatches(contents).length, 1);
      },
    );

    test('inserts a new section below a leading # title', () async {
      final file = File(p.join(root.path, 'CHANGELOG.md'))
        ..writeAsStringSync('# Changelog\n\n## 2.2.0\n\n* Old entry.\n');

      await prependChangelogSection(
        file,
        '2.3.0',
        '### Features\n\n- New thing.',
        logger,
        false,
      );

      final contents = file.readAsStringSync();
      expect(
        contents,
        '# Changelog\n\n## 2.3.0\n\n### Features\n\n- New thing.\n\n'
        '## 2.2.0\n\n* Old entry.\n',
      );
    });

    test('writes the section directly into an empty file', () async {
      final file = File(p.join(root.path, 'CHANGELOG.md'))
        ..writeAsStringSync('');

      await prependChangelogSection(
        file,
        '1.0.0',
        '- First release.',
        logger,
        false,
      );

      expect(file.readAsStringSync(), '## 1.0.0\n\n- First release.\n');
    });

    test('creates the file when it does not exist yet', () async {
      final file = File(p.join(root.path, 'CHANGELOG.md'));
      expect(file.existsSync(), isFalse);

      await prependChangelogSection(
        file,
        '1.0.0',
        '- First release.',
        logger,
        false,
      );

      expect(file.readAsStringSync(), '## 1.0.0\n\n- First release.\n');
    });

    test('a missing file is left alone on a dry run', () async {
      final file = File(p.join(root.path, 'CHANGELOG.md'));

      await prependChangelogSection(
        file,
        '1.0.0',
        '- First release.',
        logger,
        true,
      );

      expect(file.existsSync(), isFalse);
    });

    test('dry run leaves the file untouched', () async {
      final file = File(p.join(root.path, 'CHANGELOG.md'))
        ..writeAsStringSync('## 2.2.0\n\n* Old entry.\n');

      await prependChangelogSection(
        file,
        '2.3.0',
        '- New thing.',
        logger,
        true,
      );

      expect(file.readAsStringSync(), '## 2.2.0\n\n* Old entry.\n');
    });
  });

  group('extractChangelogSection', () {
    late File changelogFile;

    setUp(() {
      changelogFile = File(p.join(root.path, 'CHANGELOG.md'));
    });

    test('extracts the body between a heading and the next one', () async {
      await changelogFile.writeAsString(
        '# Changelog\n'
        '\n'
        '## 2.3.0\n'
        '\n'
        '### Changed\n'
        '- Did a thing\n'
        '\n'
        '## 2.2.0\n'
        '\n'
        '- Older entry\n',
      );

      expect(
        extractChangelogSection(changelogFile, '2.3.0'),
        '### Changed\n- Did a thing',
      );
    });

    test('extracts the last section through end of file', () async {
      await changelogFile.writeAsString('## 2.2.0\n\n- Only entry\n');

      expect(extractChangelogSection(changelogFile, '2.2.0'), '- Only entry');
    });

    test('returns null when the version heading is not present', () async {
      await changelogFile.writeAsString('## 2.2.0\n\n- Older entry\n');

      expect(extractChangelogSection(changelogFile, '9.9.9'), isNull);
    });

    test('returns null when the file does not exist', () {
      expect(extractChangelogSection(changelogFile, '2.2.0'), isNull);
    });
  });
}
