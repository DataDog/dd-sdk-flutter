// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// Covers the publish-prep-commit helpers new in P5: native SDK pinning
// (mirroring the discovery-driven native_sdk.dart matchers, but as
// rewriters -- see each function's doc comment), the pubspec
// dependency_overrides guard, and Podfile override removal.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:releaser/cocoapod_util.dart';
import 'package:releaser/gradle_util.dart';
import 'package:releaser/spm_util.dart';
import 'package:releaser/yaml_util.dart';

import 'support/test_temp.dart';

void main() {
  late Directory root;
  final logger = Logger('publish_prep_test');

  setUp(() async {
    root = await createTestTempDir('publish_prep_test_');
  });

  tearDown(() => root.delete(recursive: true));

  test(
    'pinIosPodspecVersion rewrites the Datadog dependency constraint',
    () async {
      final file = File(p.join(root.path, 'datadog_flutter_plugin_ios.podspec'))
        ..writeAsStringSync('''
Pod::Spec.new do |s|
  s.dependency 'DatadogCore', '~> 3'
end
''');

      await pinIosPodspecVersion(file, '3.16.0', logger, false);

      expect(
        file.readAsStringSync(),
        contains("s.dependency 'DatadogCore', '3.16.0'"),
      );
    },
  );

  test(
    'pinIosSpmVersion rewrites the version argument to an exact pin',
    () async {
      final file = File(p.join(root.path, 'Package.swift'))
        ..writeAsStringSync('''
let package = Package(
    dependencies: [
        .package(url: "https://github.com/Datadog/dd-sdk-ios.git", from: "3.0.0")
    ]
)
''');

      await pinIosSpmVersion(file, '3.16.0', logger, false);

      expect(file.readAsStringSync(), '''
let package = Package(
    dependencies: [
        .package(url: "https://github.com/Datadog/dd-sdk-ios.git", exact: "3.16.0")
    ]
)
''');
    },
  );

  test('pinAndroidGradleVersion rewrites ext.datadog_version', () async {
    final file = File(p.join(root.path, 'build.gradle'))
      ..writeAsStringSync('''
buildscript {
    ext.datadog_version = "3.11.0"
}
''');

    await pinAndroidGradleVersion(file, '3.13.1', logger, false);

    expect(file.readAsStringSync(), '''
buildscript {
    ext.datadog_version = "3.13.1"
}
''');
  });

  test('pubspecHasDependencyOverrides detects a committed override', () {
    final file = File(p.join(root.path, 'pubspec.yaml'))
      ..writeAsStringSync('''
name: datadog_dio
dependencies:
  collection: ^1.0.0

dependency_overrides:
  datadog_flutter_plugin:
    path: ../../datadog_flutter_plugin/datadog_flutter_plugin
''');

    expect(pubspecHasDependencyOverrides(file), isTrue);
  });

  test('pubspecHasDependencyOverrides is false with no override block', () {
    final file = File(p.join(root.path, 'pubspec.yaml'))
      ..writeAsStringSync('''
name: datadog_dio
dependencies:
  collection: ^1.0.0
''');

    expect(pubspecHasDependencyOverrides(file), isFalse);
  });

  test('pubspecHasDependencyOverrides is false for a missing file', () {
    final file = File(p.join(root.path, 'does_not_exist.yaml'));
    expect(pubspecHasDependencyOverrides(file), isFalse);
  });

  test('removePodfileOverrides strips the marked block only', () async {
    final file = File(p.join(root.path, 'Podfile'))
      ..writeAsStringSync('''
target 'Runner' do
  use_frameworks!

  # Datadog Pod Overrides
  pod 'DatadogCore', :git => 'https://github.com/DataDog/dd-sdk-ios', :branch => 'develop'
  pod 'DatadogRUM', :git => 'https://github.com/DataDog/dd-sdk-ios', :branch => 'develop'
  # End Datadog Pod Overrides
end
''');

    await removePodfileOverrides(file, logger, false);

    final contents = file.readAsStringSync();
    expect(contents, isNot(contains('Datadog Pod Overrides')));
    expect(contents, isNot(contains(':branch => \'develop\'')));
    expect(contents, contains("target 'Runner' do"));
    expect(contents, contains('use_frameworks!'));
    expect(contents, contains('end'));
  });

  test('removePodfileOverrides is a no-op with no override block', () async {
    const original = '''
target 'Runner' do
  use_frameworks!
end
''';
    final file = File(p.join(root.path, 'Podfile'))
      ..writeAsStringSync(original);

    await removePodfileOverrides(file, logger, false);

    expect(file.readAsStringSync(), original);
  });

  test(
    'removeSnapshotsMavenRepository strips only the snapshots block',
    () async {
      final file = File(p.join(root.path, 'build.gradle'))
        ..writeAsStringSync('''
allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url "https://central.sonatype.com/repository/maven-snapshots/"
        }
    }
}
''');

      await removeSnapshotsMavenRepository(file, logger, false);

      final contents = file.readAsStringSync();
      expect(contents, isNot(contains('maven-snapshots')));
      expect(contents, contains('google()'));
      expect(contents, contains('mavenCentral()'));
    },
  );

  test(
    'removeSnapshotsMavenRepository leaves other maven blocks alone',
    () async {
      const original = '''
buildscript {
    repositories {
        google()
        mavenCentral()
        maven {
            url "https://plugins.gradle.org/m2/"
        }
    }
}
''';
      final file = File(p.join(root.path, 'build.gradle'))
        ..writeAsStringSync(original);

      await removeSnapshotsMavenRepository(file, logger, false);

      expect(file.readAsStringSync(), original);
    },
  );

  test(
    'removeSnapshotsMavenRepository strips a single-line snapshots block',
    () async {
      final file = File(p.join(root.path, 'build.gradle'))
        ..writeAsStringSync('''
allprojects {
    repositories {
        google()
        maven { url "https://central.sonatype.com/repository/maven-snapshots/" }
    }
}
''');

      await removeSnapshotsMavenRepository(file, logger, false);

      final contents = file.readAsStringSync();
      expect(contents, isNot(contains('maven-snapshots')));
      expect(contents, contains('google()'));
    },
  );

  test(
    'removeSnapshotsMavenRepository is a no-op with no maven block',
    () async {
      const original = '''
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
''';
      final file = File(p.join(root.path, 'build.gradle'))
        ..writeAsStringSync(original);

      await removeSnapshotsMavenRepository(file, logger, false);

      expect(file.readAsStringSync(), original);
    },
  );

  test('removeSnapshotsMavenRepository does not mistake a nested block\'s '
      'closing brace for the maven block\'s own -- e.g. a JitPack entry\'s '
      'content { includeGroup ... }', () async {
    final file = File(p.join(root.path, 'build.gradle'))
      ..writeAsStringSync('''
rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
             url("https://jitpack.io")
             content {
                includeGroup "com.github.xgouchet.Elmyr"
             }
        }
        maven {
            url "https://central.sonatype.com/repository/maven-snapshots/"
        }
    }
}
''');

    await removeSnapshotsMavenRepository(file, logger, false);

    final contents = file.readAsStringSync();
    expect(contents, isNot(contains('maven-snapshots')));
    expect(contents, contains('url("https://jitpack.io")'));
    expect(contents, contains('includeGroup "com.github.xgouchet.Elmyr"'));
    // The JitPack block's own closing braces must both survive --
    // content's and maven's -- not just the ones the naive first-`}`
    // approach would have kept.
    expect('{'.allMatches(contents).length, '}'.allMatches(contents).length);
  });

  test('pinning an Android SDK version also strips a snapshots block in the '
      'same file, in one pass', () async {
    final file = File(p.join(root.path, 'build.gradle'))
      ..writeAsStringSync('''
buildscript {
    ext.datadog_version = "3+"
}

rootProject.allprojects {
    repositories {
        google()
        maven {
            url "https://central.sonatype.com/repository/maven-snapshots/"
        }
    }
}
''');

    await pinAndroidGradleVersion(file, '3.14.0', logger, false);
    await removeSnapshotsMavenRepository(file, logger, false);

    final contents = file.readAsStringSync();
    expect(contents, contains('ext.datadog_version = "3.14.0"'));
    expect(contents, isNot(contains('maven-snapshots')));
    expect(contents, contains('google()'));
  });
}
