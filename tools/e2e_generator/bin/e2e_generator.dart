// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'dart:io';

import 'package:analyzer/dart/analysis/context_builder.dart';
import 'package:analyzer/dart/analysis/context_locator.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:args/args.dart';
import 'package:e2e_generator/e2e_comment_extractor_visitor.dart';
import 'package:e2e_generator/issue_reporter.dart';
import 'package:e2e_generator/monitor_configuration.dart';
import 'package:e2e_generator/terraform_renderer.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

Future<List<MonitorConfiguration>> _processDartFiles(
    String inputPath, IssueReporter issueReporter, Logger logger) async {
  logger.info('Processing files in $inputPath');

  inputPath = path.normalize(path.absolute(inputPath));

  final locator = ContextLocator();
  final builder = ContextBuilder();

  final context = builder.createContext(
      contextRoot: locator.locateRoots(includedPaths: [inputPath]).first);

  final monitors = <MonitorConfiguration>[];

  var inputDir = Directory(inputPath);
  for (var filePath in inputDir.listSync(recursive: true)) {
    if (filePath.path.endsWith('.dart')) {
      final result =
          await context.currentSession.getResolvedUnit(filePath.absolute.path);

      if (result is ResolvedUnitResult && result.exists) {
        final visitor = E2ECommentExtractorVisitor(result, issueReporter);

        logger.fine('Processing ${result.uri}');

        visitor.visitCompilationUnit(result.unit);

        var newMonitors = visitor.monitors;
        for (final monitor in newMonitors) {
          logger.fine(
              'Found test: ${monitor.codeReference.testDescription} in file ${monitor.codeReference.filePath}:${monitor.codeReference.lineNo}');
        }
        monitors.addAll(newMonitors);
      }
    }
  }

  return monitors;
}

void main(List<String> args) async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    print(record.message);
  });

  final argParser = ArgParser()
    ..addOption('out',
        abbr: 'o', help: 'Output file name', defaultsTo: 'main.tf')
    ..addFlag('verbose', abbr: 'v', defaultsTo: false);

  final argResults = argParser.parse(args);
  if (argResults.rest.isEmpty) {
    print('Missing directory for processing.');
    print('Usage: dart ./bin/e2e_generator.dart [options] path/to/dart');
    return;
  }

  var inputPath = argResults.rest[0];
  if (argResults['verbose']) {
    Logger.root.level = Level.FINEST;
  }

  final outputPath = argResults['out'];

  final logger = Logger('E2E Generator');

  final issues = <Issue>[];
  void issueReporter(
      IssueSeverity severity, CodeReference reference, String message) {
    issues.add(Issue(severity, reference, message));
  }

  var monitors = await _processDartFiles(inputPath, issueReporter, logger);
  if (_printErrors(issues)) {
    print('\nExiting because of errors...');
    return;
  }
  issues.clear();

  logger.info('Generating terraform file...');
  var tfGenerator = await TerraformRenderer.fromTemplatePath('lib/templates');
  if (tfGenerator == null) {
    print(
        'Failed to load terraform templates (is your current working directory wrong?)');
    return;
  }
  var terraformOutput = tfGenerator.render(outputPath, monitors, issueReporter);
  if (_printErrors(issues)) {
    print('\nExiting because of errors...');
  }

  logger.info('Writing $outputPath');
  await File(outputPath).writeAsString(terraformOutput);
}

bool _printErrors(List<Issue> issues) {
  bool shouldExit = false;
  if (issues.isNotEmpty) {
    print('Parsing completed with issues:');
    for (var issue in issues) {
      print('  $issue');
      if (issue.severity == IssueSeverity.error) {
        shouldExit = true;
      }
    }
  }
  return shouldExit;
}
