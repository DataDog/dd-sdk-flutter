// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:collection/collection.dart';

import 'monitor_configuration.dart';

enum IssueSeverity { warning, error }

class Issue {
  final IssueSeverity severity;
  final CodeReference? codeReference;
  final String message;

  Issue(this.severity, this.codeReference, this.message);

  @override
  String toString() {
    String severityString;
    switch (severity) {
      case IssueSeverity.warning:
        severityString = 'WARNING';
        break;
      case IssueSeverity.error:
        severityString = 'ERROR';
        break;
    }

    final codeReferenceString = codeReference != null
        ? '${codeReference!.filePath}:${codeReference!.lineNo}'
        : 'unknown';
    return '$severityString: - $message ($codeReferenceString)';
  }
}

class IssueReporter {
  final List<CodeReference> _referenceStack = [];
  final List<Issue> _issues = [];

  List<Issue> get issues => UnmodifiableListView(_issues);

  void pushReference(CodeReference codeReference) {
    _referenceStack.add(codeReference);
  }

  void popReference() {
    _referenceStack.removeLast();
  }

  void clear() {
    _issues.clear();
    _referenceStack.clear();
  }

  void report(IssueSeverity severity, String message) {
    final codeRef = _referenceStack.isEmpty ? null : _referenceStack.last;

    _issues.add(Issue(severity, codeRef, message));
  }
}
