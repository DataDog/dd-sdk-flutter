// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:releaser/helpers.dart';
import 'package:releaser/release_plan.dart';

final _log = Logger('preview_release');

Future<void> main(List<String> arguments) async {
  Logger.root.onRecord.listen((record) {
    if (record.level >= Level.WARNING) {
      stderr.writeln(record.message);
    } else {
      print(record.message);
    }
  });

  final argParser = ArgParser()
    ..addOption(
      'packages',
      help:
          'Comma-separated package names. Omit for --all behaviour: every '
          'package with pending commits.',
    )
    ..addFlag(
      'include-federated',
      help:
          'Naming a member of a federated group in --packages widens '
          'selection to every member of that group. Each extra sibling '
          'still only ships if independently eligible (qualifying '
          'commits, or a forced native SDK update) -- this does not force '
          'them in the way --packages itself does.',
      defaultsTo: false,
    )
    ..addOption(
      'bump-type',
      help:
          'Override the computed bump (major/minor/patch). Requires '
          '--packages; invalid on a patch or pre-release branch.',
    )
    ..addOption(
      'ios-sdk-version',
      help: 'Pin dd-sdk-ios to this version instead of the default.',
    )
    ..addOption(
      'android-sdk-version',
      help: 'Pin dd-sdk-android to this version instead of the default.',
    )
    ..addOption(
      'cpp-version',
      help: 'Pin dd-sdk-cpp to this version instead of the default.',
    )
    ..addOption(
      'prerelease-label',
      help:
          'Required the first time a label (e.g. "beta") is used against '
          'a given target version on a pre-release branch.',
    )
    ..addOption(
      'trigger',
      allowed: ['auto', 'mainline', 'patch', 'prerelease'],
      defaultsTo: 'auto',
      help:
          'Which trigger context to plan for. "auto" detects patch from '
          'the current branch name, defaulting to mainline otherwise.',
    )
    ..addOption(
      'repo-root',
      help: 'Repo root to plan from. Defaults to the current directory.',
    )
    ..addFlag(
      'verbose',
      help: 'Also list each package\'s contributing commits.',
      defaultsTo: false,
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Print this help.');

  final ArgResults args;
  try {
    args = argParser.parse(arguments);
  } on FormatException catch (e) {
    _log.shout('❌ ${e.message}\n\n${argParser.usage}');
    exitCode = 1;
    return;
  }

  if (args['help'] as bool) {
    print(argParser.usage);
    return;
  }

  Logger.root.level = (args['verbose'] as bool) ? Level.FINEST : Level.INFO;

  final gitDir = await getGitDir(args['repo-root'] as String?);
  if (gitDir == null) {
    exitCode = 1;
    return;
  }

  final currentBranch = (await gitDir.currentBranch()).branchName;
  final trigger =
      TriggerContext.parse(args['trigger'] as String) ??
      resolveTriggerContext(currentBranch);

  final requestedPackages =
      (args['packages'] as String?)
          ?.split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList() ??
      const <String>[];

  final ctx = RunContext(
    repoRoot: gitDir.path,
    trigger: trigger,
    currentBranch: currentBranch,
    requestedPackages: requestedPackages,
    includeFederated: args['include-federated'] as bool,
    bumpTypeOverride: args['bump-type'] as String?,
    prereleaseLabel: args['prerelease-label'] as String?,
    iosSdkVersionOverride: args['ios-sdk-version'] as String?,
    androidSdkVersionOverride: args['android-sdk-version'] as String?,
    cppVersionOverride: args['cpp-version'] as String?,
  );

  final ReleasePlan plan;
  try {
    plan = await computeReleasePlan(ctx);
  } on StateError catch (e) {
    _log.shout('❌ ${e.message}');
    exitCode = 1;
    return;
  }

  _printPlan(plan);
}

void _printPlan(ReleasePlan plan) {
  if (plan.packages.isEmpty) {
    _log.info('No packages would release from this run.');
    return;
  }

  final rows = plan.packages.map(_PlanRow.from).toList();

  final nameWidth = [
    'Package'.length,
    ...rows.map((r) => r.name.length),
  ].reduce((a, b) => a > b ? a : b);
  final versionsWidth = [
    'Current → New'.length,
    ...rows.map((r) => r.versions.length),
  ].reduce((a, b) => a > b ? a : b);

  _log.info(
    '${'Package'.padRight(nameWidth + 2)}'
    '${'Current → New'.padRight(versionsWidth + 2)}'
    'Bump',
  );

  for (final row in rows) {
    final bumpLabel = row.isMajor ? '${row.bump} ⚠' : row.bump;
    final nativeSuffix = row.nativeSdkSummary.isEmpty
        ? ''
        : '  ${row.nativeSdkSummary}';
    _log.info(
      '${row.name.padRight(nameWidth + 2)}'
      '${row.versions.padRight(versionsWidth + 2)}'
      '$bumpLabel$nativeSuffix',
    );

    for (final commit in row.plan.contributingCommits) {
      final flag = commit.isBreaking ? '  [BREAKING]' : '';
      _log.fine('    ${commit.type}: ${commit.description}$flag');
    }

    for (final warning in row.plan.warnings) {
      _log.warning('  ⚠️ $warning');
    }
  }

  final majorPackages = rows
      .where((r) => r.isMajor)
      .map((r) => r.name)
      .toList();
  if (majorPackages.isNotEmpty) {
    _log.info(
      '\n⚠ ${majorPackages.length} package${majorPackages.length == 1 ? '' : 's'} '
      'with a MAJOR version bump: ${majorPackages.join(', ')}',
    );
  }
}

class _PlanRow {
  final PackagePlan plan;
  final String name;
  final String versions;
  final String bump;
  final bool isMajor;
  final String nativeSdkSummary;

  _PlanRow({
    required this.plan,
    required this.name,
    required this.versions,
    required this.bump,
    required this.isMajor,
    required this.nativeSdkSummary,
  });

  factory _PlanRow.from(PackagePlan plan) {
    final level = plan.bumpLevel;
    // Null only ever means "never stably released" here -- computePackagePlan
    // excludes anything else with nothing to report before a plan is built.
    final bumpLabel = level == null ? 'first release' : level.name;

    final nativeSdkSummary = [
      ...plan.nativeSdkDeltas
          .where((d) => d.targetVersion != null)
          .map((d) => d.toString()),
      ...plan.nativeDependencyChanges.map((c) => c.toString()),
    ].join(', ');

    return _PlanRow(
      plan: plan,
      name: plan.package.name,
      versions: '${plan.currentVersion} → ${plan.newVersion}',
      bump: bumpLabel,
      isMajor: level?.name == 'major',
      nativeSdkSummary: nativeSdkSummary.isEmpty ? '' : '($nativeSdkSummary)',
    );
  }
}
