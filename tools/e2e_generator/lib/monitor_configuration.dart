// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:collection/collection.dart';

import 'issue_reporter.dart';

enum MonitorType { logs, apm, rum, global }

class CodeReference {
  final String filePath;
  final int lineNo;
  final String testDescription;
  final String code;

  CodeReference(
    this.filePath,
    this.lineNo,
    this.testDescription, [
    this.code = 'unknown',
  ]);
}

class MonitorVariable {
  final String name;
  final String value;

  MonitorVariable({
    required this.name,
    required this.value,
  });

  static MonitorVariable? fromString(
      String line, CodeReference codeReference, IssueReporter issueReporter) {
    final variableRegex = RegExp(r'^\/\/\/\s+\$([a-zA-Z0-9_]+)\s*=\s*(.+)$');
    final match = variableRegex.allMatches(line);

    MonitorVariable? result;
    if (match.isNotEmpty) {
      final name = match.first.group(1)!;
      final value = match.first.group(2)!;
      result = MonitorVariable(name: name, value: value);
    } else {
      issueReporter.report(IssueSeverity.error,
          'Invalid variable definition - variables must be of the form "\$name = value".');
    }

    return result;
  }
}

class MonitorGroup {
  final List<MonitorVariable> variables;
  final List<MonitorConfiguration> monitors;
  final CodeReference codeReference;

  MonitorGroup({
    required this.variables,
    required this.monitors,
    required this.codeReference,
  });

  static MonitorGroup fromComment(String comment, CodeReference codeReference,
      IssueReporter issueReporter) {
    var monitors =
        MonitorConfiguration.fromComment(comment, codeReference, issueReporter);

    var groupVariables = <MonitorVariable>[];
    final globalMonitors =
        monitors.where((e) => e.type == MonitorType.global).toList();
    if (globalMonitors.isNotEmpty) {
      if (globalMonitors.length > 1) {
        issueReporter.report(IssueSeverity.error,
            'More than one global monitor definition. This is not supported');
      }
      monitors.removeWhere((e) => e.type == MonitorType.global);
      groupVariables = globalMonitors.first.variables;
    }

    return MonitorGroup(
      variables: groupVariables,
      monitors: monitors,
      codeReference: codeReference,
    );
  }
}

class MonitorConfiguration {
  final MonitorType type;
  final List<MonitorVariable> variables;
  final List<String> variants;
  final CodeReference codeReference;

  MonitorConfiguration({
    required this.type,
    required this.variants,
    required this.variables,
    required this.codeReference,
  });

  static List<MonitorConfiguration> fromComment(
    String comment,
    CodeReference codeReference,
    IssueReporter issueReporter,
  ) {
    issueReporter.pushReference(codeReference);

    final monitorRegionStartRegex = RegExp(
        r'^\/\/\/\s+```([a-zA-Z0-9]+)(\((?<variants>(?:[a-zA-Z0-9_]+\s*(?:,\s)?)+)\))?\s*$');
    final monitorRegionEndRegex = RegExp(r'^\/\/\/[\s ]+```$');

    final monitors = <MonitorConfiguration>[];
    var regionVariables = <MonitorVariable>[];

    var inMonitor = false;
    var ignoringMonitorBlock = false;
    MonitorType? monitorType;
    List<String> monitorVariants = [];

    final lines = comment.split('\n');
    for (var line in lines) {
      line = line.trim();
      final match = monitorRegionStartRegex.allMatches(line);
      if (match.isNotEmpty) {
        final typeString = match.first.group(1);
        monitorType = _monitorTypeFromString(typeString);

        if (monitorType != null) {
          inMonitor = true;
          final variants = match.first.namedGroup('variants');
          if (variants != null) {
            monitorVariants = variants.split(',').map((e) => e.trim()).toList();
          }
        } else {
          ignoringMonitorBlock = true;
          issueReporter.report(IssueSeverity.warning,
              'Invalid monitor type $typeString, ignoring monitor block');
        }
      } else if (monitorRegionEndRegex.allMatches(line).isNotEmpty) {
        if (inMonitor) {
          inMonitor = false;
          final monitor = MonitorConfiguration(
            type: monitorType!,
            variables: regionVariables,
            variants: monitorVariants,
            codeReference: codeReference,
          );
          regionVariables = [];
          monitorVariants = [];
          monitors.add(monitor);
        } else if (ignoringMonitorBlock) {
          ignoringMonitorBlock = false;
        } else {
          issueReporter.report(IssueSeverity.error,
              'Monitor end without any monitor start (did you forget a monitor type?)');
        }
      } else if (inMonitor && line != '///') {
        final variable =
            MonitorVariable.fromString(line, codeReference, issueReporter);
        if (variable != null) {
          regionVariables.add(variable);
        }
      }
    }

    if (inMonitor && !ignoringMonitorBlock) {
      issueReporter.report(
          IssueSeverity.error, 'Missing monitor block close (```).');
    }

    issueReporter.popReference();

    return monitors;
  }
}

MonitorType? _monitorTypeFromString(String? value) {
  if (value == null) {
    return null;
  }

  value = value.toLowerCase();
  return MonitorType.values
      .firstWhereOrNull((e) => e.toString() == 'MonitorType.$value');
}
