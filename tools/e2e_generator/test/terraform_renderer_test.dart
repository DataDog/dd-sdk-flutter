// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:e2e_generator/issue_reporter.dart';
import 'package:e2e_generator/monitor_configuration.dart';
import 'package:e2e_generator/terraform_renderer.dart';
import 'package:test/test.dart';

void main() {
  final mockCodeReference = CodeReference('fake_path', 133, 'Test Description');

  void nullIssueReporter(
      IssueSeverity severity, CodeReference codeReference, String message) {}

  test('rendering variable with no default', () {
    final template =
        MonitorTemplate('argument = \${{argument_value}} # comment');

    final variable =
        MonitorVariable(name: 'argument_value', value: 'fake value');
    final configuration = MonitorConfiguration(
      type: MonitorType.logs,
      variables: [variable],
      codeReference: mockCodeReference,
    );

    final result = template.render(configuration, nullIssueReporter);

    expect(result, 'argument = fake value # comment\n');
  });

  test('rendering missing variable with default renders default', () {
    final template = MonitorTemplate(
        'argument = \${{argument_value:-default value}} # comment');

    final configuration = MonitorConfiguration(
      type: MonitorType.logs,
      variables: [],
      codeReference: mockCodeReference,
    );

    final result = template.render(configuration, nullIssueReporter);

    expect(result, 'argument = default value # comment\n');
  });

  test('rendering variable with default renders user value', () {
    final template = MonitorTemplate(
        'argument = \${{argument_value:-default value}} # comment');

    final variable =
        MonitorVariable(name: 'argument_value', value: 'provided user value');
    final configuration = MonitorConfiguration(
      type: MonitorType.logs,
      variables: [variable],
      codeReference: mockCodeReference,
    );

    final result = template.render(configuration, nullIssueReporter);

    expect(result, 'argument = provided user value # comment\n');
  });

  test('rendering multiple templates evaluates all values', () {
    final template =
        MonitorTemplate(r'''resource "datadog_monitor" ${{monitor_id}} {
  argument1 = ${{argument1_value}} # comment
  argument2 = ${{argument2_value:-"default value for argument 2"}}
}''');

    final var1 = MonitorVariable(name: 'monitor_id', value: 'user monitor id');
    final var2 =
        MonitorVariable(name: 'argument1_value', value: 'my argument variable');
    final configuration = MonitorConfiguration(
      type: MonitorType.logs,
      variables: [var1, var2],
      codeReference: mockCodeReference,
    );

    final expectedResult = r'''resource "datadog_monitor" user monitor id {
  argument1 = my argument variable # comment
  argument2 = "default value for argument 2"
}
''';

    final result = template.render(configuration, nullIssueReporter);
    expect(result, expectedResult);
  });

  test('rendering variable with no value reports error', () {
    final template =
        MonitorTemplate('argument = \${{argument_value}} # comment');

    final configuration = MonitorConfiguration(
      type: MonitorType.logs,
      variables: [],
      codeReference: mockCodeReference,
    );

    var issues = <Issue>[];
    void reporter(IssueSeverity severity, CodeReference ref, String message) {
      issues.add(Issue(severity, ref, message));
    }

    template.render(configuration, reporter);

    expect(issues.length, 1);
    expect(issues[0].severity, IssueSeverity.error);
  });

  test('extra variable with no substitution reports warning', () {
    final template =
        MonitorTemplate('argument = \${{argument1_value}} # comment');

    final var1 =
        MonitorVariable(name: 'argument1_value', value: 'argument variable');
    final var2 = MonitorVariable(
        name: 'argument2_value', value: 'extra argument variable');
    final configuration = MonitorConfiguration(
      type: MonitorType.logs,
      variables: [var1, var2],
      codeReference: mockCodeReference,
    );

    var issues = <Issue>[];
    void reporter(IssueSeverity severity, CodeReference ref, String message) {
      issues.add(Issue(severity, ref, message));
    }

    template.render(configuration, reporter);

    expect(issues.length, 1);
    expect(issues[0].severity, IssueSeverity.warning);
  });
}
