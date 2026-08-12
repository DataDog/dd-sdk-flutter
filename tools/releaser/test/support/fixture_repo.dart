// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:path/path.dart' as p;

/// A throwaway pubspec.yaml tree, mirroring the shapes that matter in
/// dd-sdk-flutter's real `packages/` layout (a federated group, several
/// singletons, an intentionally-unpublished support package, an example
/// app, and a package whose name merely *looks* federated). Discovery
/// tests run against this instead of the real tree so they don't depend
/// on -- or get broken by -- packages/ changing over time.
class FixtureRepo {
  final Directory root;

  FixtureRepo._(this.root);

  static Future<FixtureRepo> create() async {
    final root = await Directory.systemTemp.createTemp('releaser_test_');
    final repo = FixtureRepo._(root);

    repo._writePubspec(
      'packages/datadog_dio',
      name: 'datadog_dio',
      version: '2.3.0',
    );
    repo._writePubspec(
      'packages/datadog_dio/example',
      name: 'datadog_dio_example',
      publishTo: 'none',
    );

    repo._writePubspec(
      'packages/datadog_common_test',
      name: 'datadog_common_test',
      publishTo: 'none',
    );

    // Ends in a federation suffix but has no siblings -- must stay a
    // singleton under its own name, not get collapsed into a "lonely"
    // group of one.
    repo._writePubspec(
      'packages/lonely_ios',
      name: 'lonely_ios',
      version: '1.0.0',
    );

    const flutterPluginBase = 'packages/datadog_flutter_plugin';
    repo._writePubspec(
      '$flutterPluginBase/datadog_flutter_plugin_platform_interface',
      name: 'datadog_flutter_plugin_platform_interface',
      version: '1.0.0',
    );
    repo._writePubspec(
      '$flutterPluginBase/datadog_flutter_plugin_android',
      name: 'datadog_flutter_plugin_android',
      version: '1.0.0',
    );
    repo._writePubspec(
      '$flutterPluginBase/datadog_flutter_plugin_ios',
      name: 'datadog_flutter_plugin_ios',
      version: '1.0.0',
    );
    repo._writePubspec(
      '$flutterPluginBase/datadog_flutter_plugin_ios/example',
      name: 'datadog_flutter_plugin_ios_example',
      publishTo: 'none',
    );
    repo._writePubspec(
      '$flutterPluginBase/datadog_flutter_plugin',
      name: 'datadog_flutter_plugin',
      version: '4.0.0',
    );

    return repo;
  }

  void _writePubspec(
    String relativeDir, {
    required String name,
    String? version,
    String? publishTo,
  }) {
    final dir = Directory(p.join(root.path, relativeDir));
    dir.createSync(recursive: true);

    final buffer = StringBuffer('name: $name\n');
    if (version != null) buffer.writeln('version: $version');
    if (publishTo != null) buffer.writeln("publish_to: '$publishTo'");
    buffer.writeln('environment:\n  sdk: ^3.0.0');

    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync(buffer.toString());
  }

  Future<void> delete() => root.delete(recursive: true);
}
