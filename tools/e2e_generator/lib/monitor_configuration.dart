// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:collection/collection.dart';

import 'issue_reporter.dart';

enum MonitorType { logs, apm, rum }

class CodeReference {
  final String filePath;
  final int lineNo;
  final String testDescription;

  CodeReference(this.filePath, this.lineNo, this.testDescription);
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
      issueReporter(IssueSeverity.error, codeReference,
          'Invalid variable definition - variables must be of the form "\$name = value".');
    }

    return result;
  }
}

class MonitorConfiguration {
  final MonitorType type;
  final List<MonitorVariable> variables;
  final CodeReference codeReference;

  MonitorConfiguration({
    required this.type,
    required this.variables,
    required this.codeReference,
  });

  static List<MonitorConfiguration> fromComment(
    String comment,
    CodeReference codeReference,
    IssueReporter issueReporter,
  ) {
    final monitorRegionStartRegex = RegExp(r'^\/\/\/\s+```([a-zA-Z0-9]+)\s*$');
    final monitorRegionEndRegex = RegExp(r'^\/\/\/[\s ]+```$');

    final monitors = <MonitorConfiguration>[];
    var regionVariables = <MonitorVariable>[];

    var inMonitor = false;
    var ignoringMonitorBlock = false;
    MonitorType? monitorType;

    final lines = comment.split('\n');
    for (var line in lines) {
      line = line.trim();
      final match = monitorRegionStartRegex.allMatches(line);
      if (match.isNotEmpty) {
        final typeString = match.first.group(1);
        monitorType = _monitorTypeFromString(typeString);

        if (monitorType != null) {
          inMonitor = true;
        } else {
          ignoringMonitorBlock = true;
          issueReporter(IssueSeverity.warning, codeReference,
              'Invalid monitor type $typeString, ignoring monitor block');
        }
      } else if (monitorRegionEndRegex.allMatches(line).isNotEmpty) {
        if (inMonitor) {
          inMonitor = false;
          final monitor = MonitorConfiguration(
            type: monitorType!,
            variables: regionVariables,
            codeReference: codeReference,
          );
          regionVariables = [];
          monitors.add(monitor);
        } else if (ignoringMonitorBlock) {
          ignoringMonitorBlock = false;
        } else {
          issueReporter(IssueSeverity.error, codeReference,
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
      issueReporter(IssueSeverity.error, codeReference,
          'Missing monitor block close (```).');
    }

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
