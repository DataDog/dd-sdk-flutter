// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:releaser/manifest.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('manifest_test_');
  });

  tearDown(() => root.delete(recursive: true));

  test('round-trips through .release/manifest.json', () async {
    final manifest = ReleaseManifest(
      contentCommit: 'abc123',
      packages: [
        ManifestPackageEntry(
          package: 'datadog_dio',
          fromVersion: '2.2.0',
          toVersion: '2.3.0',
          sourceBranch: 'develop',
          prerelease: false,
        ),
        ManifestPackageEntry(
          package: 'datadog_flutter_plugin_ios',
          fromVersion: '1.0.0',
          toVersion: '2.0.0-beta.1',
          sourceBranch: 'v4',
          prerelease: true,
        ),
      ],
    );

    await writeManifest(root.path, manifest);

    final file = File(p.join(root.path, '.release', 'manifest.json'));
    expect(file.existsSync(), isTrue);

    final read = await readManifest(root.path);
    expect(read.contentCommit, 'abc123');
    expect(read.packages, hasLength(2));
    expect(read.packages[0].package, 'datadog_dio');
    expect(read.packages[0].toVersion, '2.3.0');
    expect(read.packages[0].prerelease, isFalse);
    expect(read.packages[1].prerelease, isTrue);
  });

  test(
    'contentCommit round-trips as null for a patch-trigger manifest',
    () async {
      final manifest = ReleaseManifest(
        contentCommit: null,
        packages: [
          ManifestPackageEntry(
            package: 'datadog_dio',
            fromVersion: '2.2.0',
            toVersion: '2.2.1',
            sourceBranch: 'release/datadog_dio/v2.2.x',
            prerelease: false,
          ),
        ],
      );

      await writeManifest(root.path, manifest);

      final read = await readManifest(root.path);
      expect(read.contentCommit, isNull);
    },
  );

  test('manifestPath is under .release/ at the repo root', () {
    expect(manifestPath('/repo'), p.join('/repo', '.release', 'manifest.json'));
  });
}
