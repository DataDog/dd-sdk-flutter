// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

// A local dev tool for the LLM changelog pipeline (`lib/llm/`): runs it for
// real, against a real AI Gateway token, for one package -- the fast path
// for iterating on the prompts in `lib/llm/changelog.dart` and eyeballing
// real output. Not wired into CI or any other entry point.
//
// Usage: AI_GATEWAY_TOKEN=$(ddtool auth token rapid-ai-platform
// --datacenter us1.ddbuild.io) dart run bin/preview_changelog.dart
// --repo-root=/path/to/dd-sdk-flutter --package=datadog_flutter_plugin

import 'dart:io';

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:releaser/github_cmd_wrapper.dart';
import 'package:releaser/helpers.dart';
import 'package:releaser/llm/ai_gateway.dart';
import 'package:releaser/llm/changelog.dart';
import 'package:releaser/llm/costs.dart';
import 'package:releaser/release_plan.dart';

final _log = Logger('preview_changelog');

Future<void> main(List<String> arguments) async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((r) => print('${r.level.name}: ${r.message}'));

  final argParser = ArgParser()
    ..addOption('repo-root', mandatory: true)
    ..addOption('package', mandatory: true);
  final args = argParser.parse(arguments);

  final gitDir = await getGitDir(args['repo-root'] as String);
  if (gitDir == null) {
    exitCode = 1;
    return;
  }

  final currentBranch = (await gitDir.currentBranch()).branchName;
  final plan = await computeReleasePlan(
    RunContext(
      repoRoot: gitDir.path,
      trigger: resolveTriggerContext(currentBranch),
      currentBranch: currentBranch,
      requestedPackages: [args['package'] as String],
    ),
  );
  final packagePlan = plan.packages.singleWhere(
    (p) => p.package.name == args['package'],
  );

  final costTracker = LlmCostTracker();
  final entries = await generateChangelogForPackage(
    HttpAiGatewayClient.fromEnvironment(),
    packagePlan,
    github: GithubCommandWrapper(gitDir.path),
    logger: _log,
    costTracker: costTracker,
  );

  print('## ${packagePlan.newVersion}\n');
  print(renderChangelogSection(entries));

  print('\n--- LLM cost summary ---\n');
  costTracker.printSummary(_log);
}
