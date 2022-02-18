// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'monitor_configuration.dart';

enum IssueSeverity { warning, error }

typedef IssueReporter = void Function(
    IssueSeverity type, CodeReference codeReference, String message);

class Issue {
  final IssueSeverity severity;
  final CodeReference codeReference;
  final String message;

  Issue(this.severity, this.codeReference, this.message);
}
