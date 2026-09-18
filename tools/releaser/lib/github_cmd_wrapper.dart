// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';

import 'process_helper.dart';

part 'github_cmd_wrapper.g.dart';

@JsonSerializable()
class GHRelease {
  final bool isLatest;
  final String name;
  final String tagName;

  GHRelease({
    required this.isLatest,
    required this.name,
    required this.tagName,
  });

  factory GHRelease.fromJson(Map<String, dynamic> json) =>
      _$GHReleaseFromJson(json);
  Map<String, dynamic> toJson() => _$GHReleaseToJson(this);
}

/// Wraps the `gh` command line tool for performing operations with Github
class GithubCommandWrapper {
  final String cwd;

  const GithubCommandWrapper(this.cwd);

  Future<bool> checkAuth(Logger logger) async {
    final exitCode = await runProcess(
      'gh',
      ['auth', 'status'],
      workingDirectory: cwd,
      stdout: (line) => logger.info(line),
      stderr: (line) => logger.shout(line),
    );

    return exitCode == 0;
  }

  Future<List<GHRelease>> fetchReleases(Logger logger, String repoSlug) async {
    final buffer = StringBuffer();
    final exitCode = await runProcess(
      'gh',
      [
        'release',
        'list',
        '--repo',
        repoSlug,
        '--json',
        'name,isLatest,tagName'
      ],
      workingDirectory: cwd,
      stdout: (line) => buffer.write(line),
      stderr: (line) => logger.shout(line),
    );

    if (exitCode != 0) {
      throw Exception('gh returned exit code $exitCode.');
    }

    final json = jsonDecode(buffer.toString()) as List;
    final releases = json.map((e) => GHRelease.fromJson(e)).toList();
    return releases;
  }

  Future<GHRelease> getLatestRelease(Logger logger, String repoSlug) async {
    final releases = await fetchReleases(logger, repoSlug);
    return releases.firstWhere((e) => e.isLatest);
  }

  Future<GHRelease?> getReleaseByTagName(
      Logger logger, String repoSlug, String tagName) async {
    final releases = await fetchReleases(logger, repoSlug);
    return releases.firstWhereOrNull((e) => e.tagName == tagName);
  }

  Future<void> createRelease(Logger logger, String tag, String name,
      String changelog, bool isPrerelease) async {
    final buffer = StringBuffer();
    final exitCode = await runProcess(
      'gh',
      [
        'release',
        'create',
        tag,
        '--title',
        name,
        '--notes',
        changelog,
        '--draft',
        if (isPrerelease) '--prerelease'
      ],
      workingDirectory: cwd,
      stdout: (line) => buffer.write(line),
      stderr: (line) => logger.shout(line),
    );

    if (exitCode != 0) {
      throw Exception('gh returned exit code $exitCode.');
    }
  }
}
