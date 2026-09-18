// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:io';

import 'package:git/git.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:version/version.dart';

import 'command.dart';
import 'helpers.dart';

// Maps common scope abbreviations that are added to conventional commits to more human
// readable versions.
final scopeAbbreviationMap = <String, String>{
  'ios': 'iOS',
  'android': 'Android',
  'web': 'Web',
  'sr': 'Session Replay',
  'desk': 'Desktop',
  'win': 'Windows',
  'mac': 'macOS',
  'linux': 'Linux',
};

class GenerateChangelogCommand extends Command {
  static const issuesLink = 'https://github.com/DataDog/dd-sdk-flutter/issues/';

  @override
  Future<bool> run(CommandArguments args, Logger logger) async {
    for (final package in args.packages) {
      final lastReleaseSha = await _findLastReleaseSha(logger, args, package);
      if (lastReleaseSha == null) {
        Logger.root.shout(
            '⚠️ Could not find last release! Hopefully this is a new package!.');
        Logger.root.shout(
            '‼️ Changelogs cannot be generated for an initial release! Make sure you have what you need in there.');
      } else {
        final commits =
            await _getCommits(args, package, '$lastReleaseSha..HEAD');

        final changelogItems = _getChangelogItems(commits);
        logger.fine(
            'Found ${changelogItems.length} changelog items for ${package.name} version ${package.version}');

        final versionChangelog = changelogItems.map((e) => '* $e').join('\n');

        final file =
            File(path.join(getPackageRoot(args, package), 'CHANGELOG.md'));
        if (!file.existsSync()) {
          Logger.root.shout('❌ Could not find file CHANGELOG.md for package.');
          return false;
        }

        bool didWriteChangelog = false;
        await transformFile(file, logger, args.dryRun, (line) {
          if (didWriteChangelog) return line;

          if (line.startsWith('##')) {
            String? oldLine = line;
            if (line == '## Unreleased') {
              logger.info(
                  'ℹ️ ## Unreleased headers are no longer needed. Removing.');
              oldLine = null;
            }

            line = '## ${package.version}\n\n$versionChangelog\n';
            if (oldLine != null) {
              line += '\n$oldLine';
            }
            didWriteChangelog = true;
          }
          return line;
        });
      }
    }

    print(
        'Verify the CHANGELOG.md changes for all packages and add changes from iOS and Android Native SDK updates.');
    print(
        'For reference iOS SDK will be updated to ${args.iOSRelease} and Android SDK will be updated to ${args.androidRelease}.');

    return _waitForConfirmation(logger);
  }

  bool _waitForConfirmation(Logger logger) {
    print('Ready to continue? ([Y]es, [N]o): ');

    final input = stdin.readLineSync();
    if (input != null && input.isNotEmpty) {
      final firstChar = input[0].toLowerCase();
      if (firstChar == 'y') {
        return true;
      } else if (firstChar == 'n') {
        logger.shout('😳 Oh, I\'m glad we stopped then!');
        return false;
      } else {
        logger.shout(
            '❓ Not sure what you meant by that... stopping just in case.');
        return false;
      }
    }

    return true;
  }

  Future<String?> _findLastReleaseSha(
      Logger logger, CommandArguments args, PackageRelease package) async {
    final packageTags = await args.gitDir
        .tags()
        .where((t) => t.tag.startsWith('${package.name}/'))
        .toList();

    Version? _getVersion(Tag tag) {
      Version? v;
      try {
        final versionString = tag.tag.split('/').last.replaceFirst('v', '');
        v = Version.parse(versionString);
      } catch (_) {
        // Nothing to do
      }
      return v;
    }

    packageTags.sort((a, b) {
      Version? versionA = _getVersion(a);
      Version? versionB = _getVersion(b);
      if (versionA == null) return -1;
      if (versionB == null) return 1;

      return versionA.compareTo(versionB);
    });

    if (packageTags.isEmpty) return null;

    final lastTag = packageTags.last;

    logger.fine('Found tag ${lastTag.tag} with sha ${lastTag.objectSha}');

    return packageTags.last.objectSha;
  }

  Future<List<String>> _getCommits(
      CommandArguments args, PackageRelease package, String commitRange) async {
    final packageRoot = getPackageRoot(args, package);
    final result = await args.gitDir.runCommand([
      '--no-pager',
      'log',
      commitRange,
      '--pretty=format:%H|||%an <%aE>|||%ai|||%B||||',
      '--',
      packageRoot
    ]);

    final rawCommits = (result.stdout as String)
        .split('||||\n')
        .where((e) => e.trim().isNotEmpty)
        .toList();

    return rawCommits.map((c) {
      final parts = c.split('|||');
      return parts[3].trim();
    }).toList();
  }
}

List<String> _getChangelogItems(List<String> commitMessages) {
  RegExp conventionalCommitPattern =
      RegExp(r'(?<type>\w*)(\((?<scope>.*)\))?(?<breaking>!)?: (?<rest>.*)');
  RegExp githubIssueMention = RegExp(r'\#(?<issue_number>\d+)');

  final items = <String>[];
  for (final commitMessage in commitMessages) {
    final lines = commitMessage.split('\n');
    final summaryLine = lines[0];
    final match = conventionalCommitPattern.firstMatch(summaryLine);
    if (match != null) {
      final type = match.namedGroup('type');
      if (type == 'fix' || type == 'feat') {
        String changelogItem = '';
        if (match.namedGroup('scope') case final scopes?) {
          final scopeList = scopes.split(',').map((e) {
            final scope = e.trim();
            if (scopeAbbreviationMap[scope] case final scope?) {
              return scope;
            }
            return scope;
          });
          changelogItem = '[${scopeList.join(', ')}] ';
        }

        changelogItem += match.namedGroup('rest')!;
        if (!changelogItem.endsWith('.')) {
          // Commits frequently forget they're sentences.
          changelogItem += '.';
        }

        // Check to see if there are any Github issues referenced
        final refLines = lines.where((l) => l.startsWith('refs:'));
        var githubRefs = <String>[];
        for (var refLine in refLines) {
          for (var match in githubIssueMention.allMatches(refLine)) {
            githubRefs.add(match.namedGroup('issue_number')!);
          }
        }
        if (githubRefs.isNotEmpty) {
          final seeStrings = githubRefs
              .map((r) => '[#$r](${GenerateChangelogCommand.issuesLink}$r)');
          changelogItem += ' See ${seeStrings.join(' ')}';
        }

        items.add(changelogItem);
      }
    }
  }

  return items;
}
