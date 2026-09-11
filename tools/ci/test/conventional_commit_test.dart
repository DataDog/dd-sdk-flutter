// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:ci_helpers/conventional_commit.dart';
import 'package:test/test.dart';

void main() {
  group('isConventionalCommitSubject', () {
    test('accepts Conventional Commit subjects', () {
      expect(isConventionalCommitSubject('feat: add a feature'), isTrue);
      expect(isConventionalCommitSubject('fix(web): avoid a crash'), isTrue);
      expect(
        isConventionalCommitSubject('feat(flags)!: change the API'),
        isTrue,
      );
      expect(
        isConventionalCommitSubject('build-tool: update the image'),
        isTrue,
      );
    });

    test('rejects non-Conventional Commit subjects', () {
      expect(isConventionalCommitSubject('[FFL-3028] Add a provider'), isFalse);
      expect(isConventionalCommitSubject('Add a provider'), isFalse);
      expect(isConventionalCommitSubject('FEAT: add a provider'), isFalse);
      expect(isConventionalCommitSubject('feat:add a provider'), isFalse);
      expect(isConventionalCommitSubject('feat(): add a provider'), isFalse);
      expect(isConventionalCommitSubject('feat: '), isFalse);
    });
  });
}
