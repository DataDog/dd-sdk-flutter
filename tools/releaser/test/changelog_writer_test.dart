// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:releaser/changelog_writer.dart';

void main() {
  late Directory root;
  final logger = Logger('changelog_writer_test');

  setUp(() async {
    root = await Directory.systemTemp.createTemp('changelog_writer_test_');
  });

  tearDown(() => root.delete(recursive: true));

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
    expect(contents, startsWith('## 2.3.0\n\n### Features\n\n- New thing.\n'));
    expect(contents, contains('## 2.2.0'));
    expect(contents, contains('* Old entry.'));
  });

  test('writes the section directly into an empty file', () async {
    final file = File(p.join(root.path, 'CHANGELOG.md'))..writeAsStringSync('');

    await prependChangelogSection(
      file,
      '1.0.0',
      '- First release.',
      logger,
      false,
    );

    expect(file.readAsStringSync(), '## 1.0.0\n\n- First release.\n');
  });

  test('dry run leaves the file untouched', () async {
    final file = File(p.join(root.path, 'CHANGELOG.md'))
      ..writeAsStringSync('## 2.2.0\n\n* Old entry.\n');

    await prependChangelogSection(file, '2.3.0', '- New thing.', logger, true);

    expect(file.readAsStringSync(), '## 2.2.0\n\n* Old entry.\n');
  });
}
