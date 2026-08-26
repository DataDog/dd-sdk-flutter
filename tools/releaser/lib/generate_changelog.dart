// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'command.dart';
import 'conventional_commits.dart';
import 'git_history.dart';
import 'helpers.dart';

final _githubIssueRefPattern = RegExp(r'^#(?<issue_number>\d+)$');

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
      final lastReleaseTag = await findLastReleaseTag(
        args.gitDir,
        package.name,
      );
      if (lastReleaseTag == null) {
        Logger.root.shout(
          '⚠️ Could not find last release! Hopefully this is a new package!.',
        );
        Logger.root.shout(
          '‼️ Changelogs cannot be generated for an initial release! Make sure you have what you need in there.',
        );
      } else {
        final commits = await commitMessagesSince(
          args.gitDir,
          pathspec: getPackageRoot(args, package),
          sinceSha: lastReleaseTag.tag.objectSha,
        );

        final changelogItems = _getChangelogItems(commits);
        logger.fine(
          'Found ${changelogItems.length} changelog items for ${package.name} version ${package.version}',
        );

        final versionChangelog = changelogItems.map((e) => '* $e').join('\n');

        final file = File(
          path.join(getPackageRoot(args, package), 'CHANGELOG.md'),
        );
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
                'ℹ️ ## Unreleased headers are no longer needed. Removing.',
              );
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
      'Verify the CHANGELOG.md changes for all packages and add changes from iOS and Android Native SDK updates.',
    );
    print(
      'For reference iOS SDK will be updated to ${args.iOSRelease} and Android SDK will be updated to ${args.androidRelease}.',
    );

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
          '❓ Not sure what you meant by that... stopping just in case.',
        );
        return false;
      }
    }

    return true;
  }
}

List<String> _getChangelogItems(List<String> commitMessages) {
  final items = <String>[];
  for (final commitMessage in commitMessages) {
    final commit = ConventionalCommit.parse(commitMessage);
    if (commit == null) continue;

    if (commit.type == 'fix' || commit.type == 'feat') {
      String changelogItem = '';
      if (commit.scope case final scopes?) {
        final scopeList = scopes.split(',').map((e) {
          final scope = e.trim();
          if (scopeAbbreviationMap[scope] case final scope?) {
            return scope;
          }
          return scope;
        });
        changelogItem = '[${scopeList.join(', ')}] ';
      }

      changelogItem += commit.description;
      if (!changelogItem.endsWith('.')) {
        // Commits frequently forget they're sentences.
        changelogItem += '.';
      }

      // refs: can carry more than GitHub issues (JIRA tickets, etc.) --
      // only build links for the ones that look like a GitHub issue.
      final githubIssueNumbers = commit.refs
          .map((r) => _githubIssueRefPattern.firstMatch(r))
          .nonNulls
          .map((m) => m.namedGroup('issue_number')!);
      if (githubIssueNumbers.isNotEmpty) {
        final seeStrings = githubIssueNumbers.map(
          (r) => '[#$r](${GenerateChangelogCommand.issuesLink}$r)',
        );
        changelogItem += ' See ${seeStrings.join(' ')}';
      }

      items.add(changelogItem);
    }
  }

  return items;
}
