// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:e2e_generator/issue_reporter.dart';
import 'package:e2e_generator/monitor_configuration.dart';
import 'package:e2e_generator/terraform_renderer.dart';
import 'package:test/test.dart';

void main() {
  final mockCodeReference = CodeReference('fake_path', 133, 'Test Description');
  final issueReporter = IssueReporter();

  setUp(() {
    issueReporter.clear();
  });

  test('rendering variable with no default', () {
    final template =
        MonitorTemplate('argument = \${{argument_value}} # comment');

    final variable =
        MonitorVariable(name: 'argument_value', value: 'fake value');
    final configuration = MonitorConfiguration(
      type: MonitorType.logs,
      shouldIgnore: false,
      variables: [variable],
      variants: [],
      codeReference: mockCodeReference,
    );

    final result = template.render(configuration, [], issueReporter);

    expect(result, 'argument = fake value # comment\n');
  });

  test('rendering missing variable with default renders default', () {
    final template = MonitorTemplate(
        'argument = \${{argument_value:-default value}} # comment');

    final configuration = MonitorConfiguration(
      type: MonitorType.logs,
      shouldIgnore: false,
      variables: [],
      variants: [],
      codeReference: mockCodeReference,
    );

    final result = template.render(configuration, [], issueReporter);

    expect(result, 'argument = default value # comment\n');
  });

  test('rendering variable with default renders user value', () {
    final template = MonitorTemplate(
        'argument = \${{argument_value:-default value}} # comment');

    final variable =
        MonitorVariable(name: 'argument_value', value: 'provided user value');
    final configuration = MonitorConfiguration(
      type: MonitorType.logs,
      shouldIgnore: false,
      variables: [variable],
      variants: [],
      codeReference: mockCodeReference,
    );

    final result = template.render(configuration, [], issueReporter);

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
      shouldIgnore: false,
      variables: [var1, var2],
      variants: [],
      codeReference: mockCodeReference,
    );

    final expectedResult = r'''resource "datadog_monitor" user monitor id {
  argument1 = my argument variable # comment
  argument2 = "default value for argument 2"
}
''';

    final result = template.render(configuration, [], issueReporter);
    expect(result, expectedResult);
  });

  test('rendering template with variants renders multiple templates', () {
    final template =
        MonitorTemplate(r'''resource "datadog_monitor" ${{monitor_id}} {
  argument1 = ${{argument1_value}} # comment
}''');

    final var1 = MonitorVariable(
        name: 'monitor_id', value: 'user monitor id \${{variant}}');
    final var2 = MonitorVariable(
        name: 'argument1_value', value: 'my argument \${{variant}}');
    final configuration = MonitorConfiguration(
      type: MonitorType.logs,
      shouldIgnore: false,
      variables: [var1, var2],
      variants: ['ios', 'web'],
      codeReference: mockCodeReference,
    );

    final expectedResult = r'''resource "datadog_monitor" user monitor id ios {
  argument1 = my argument ios # comment
}

resource "datadog_monitor" user monitor id web {
  argument1 = my argument web # comment
}''';

    final result = template.render(configuration, [], issueReporter).trim();
    expect(result, expectedResult);
  });

  test('rendering variable with no value reports error', () {
    final template =
        MonitorTemplate('argument = \${{argument_value}} # comment');

    final configuration = MonitorConfiguration(
      type: MonitorType.logs,
      shouldIgnore: false,
      variables: [],
      variants: [],
      codeReference: mockCodeReference,
    );

    template.render(configuration, [], issueReporter);

    expect(issueReporter.issues.length, 1);
    expect(issueReporter.issues[0].severity, IssueSeverity.error);
  });

  test('rendering variable with variant with no variants reports error', () {
    final template =
        MonitorTemplate('argument = \${{argument_value}} # comment');

    final configuration = MonitorConfiguration(
      type: MonitorType.logs,
      shouldIgnore: false,
      variables: [
        MonitorVariable(
            name: 'argument_value', value: 'test value with \${{variant}}')
      ],
      variants: [],
      codeReference: mockCodeReference,
    );

    template.render(configuration, [], issueReporter);

    expect(issueReporter.issues.length, 1);
    expect(issueReporter.issues[0].severity, IssueSeverity.error);
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
      shouldIgnore: false,
      variables: [var1, var2],
      variants: [],
      codeReference: mockCodeReference,
    );

    template.render(configuration, [], issueReporter);

    expect(issueReporter.issues.length, 1);
    expect(issueReporter.issues[0].severity, IssueSeverity.warning);
  });

  test('render expands global variables in monitor variables', () {
    final template =
        MonitorTemplate(r'''resource "datadog_monitor" ${{monitor_id}} {
  argument1 = ${{argument1_value}} # comment
}''');

    final var1 =
        MonitorVariable(name: 'monitor_id', value: 'test_\${{global1}}');
    final var2 = MonitorVariable(
        name: 'argument1_value', value: '\${{global1}}, \${{global2}}');
    final configuration = MonitorConfiguration(
      type: MonitorType.logs,
      shouldIgnore: false,
      variables: [var1, var2],
      variants: [],
      codeReference: mockCodeReference,
    );

    final globalVariables = [
      MonitorVariable(name: 'global1', value: 'global_value_1'),
      MonitorVariable(name: 'global2', value: 'second global value'),
    ];

    final expectedResult = r'''resource "datadog_monitor" test_global_value_1 {
  argument1 = global_value_1, second global value # comment
}''';

    final result =
        template.render(configuration, globalVariables, issueReporter).trim();
    expect(result, expectedResult);
  });

  test('render replaces code anchor with code', () {
    final template =
        MonitorTemplate(r'''resource "datadog_monitor" ${{monitor_id}} {
  argument1 = ${{argument1_value}} # comment

  ## MONITOR_CODE ##
}''');

    final var1 =
        MonitorVariable(name: 'monitor_id', value: 'test_\${{global1}}');
    final var2 = MonitorVariable(
        name: 'argument1_value', value: '\${{global1}}, \${{global2}}');
    final configuration = MonitorConfiguration(
      type: MonitorType.logs,
      shouldIgnore: false,
      variables: [var1, var2],
      variants: [],
      codeReference: CodeReference(
          'fake_path', 123, 'test_description', 'Code for the code god.'),
    );

    final globalVariables = [
      MonitorVariable(name: 'global1', value: 'global_value_1'),
      MonitorVariable(name: 'global2', value: 'second global value'),
    ];

    final expectedResult = r'''resource "datadog_monitor" test_global_value_1 {
  argument1 = global_value_1, second global value # comment

  Code for the code god.
}''';

    final result =
        template.render(configuration, globalVariables, issueReporter).trim();
    expect(result, expectedResult);
  });

  test('render escapes code replacement in code anchor', () {
    final template =
        MonitorTemplate(r'''resource "datadog_monitor" ${{monitor_id}} {
  argument1 = ${{argument1_value}} # comment

  ## MONITOR_CODE ##
}''');

    final var1 =
        MonitorVariable(name: 'monitor_id', value: 'test_\${{global1}}');
    final var2 = MonitorVariable(
        name: 'argument1_value', value: '\${{global1}}, \${{global2}}');
    final configuration = MonitorConfiguration(
      type: MonitorType.logs,
      shouldIgnore: false,
      variables: [var1, var2],
      variants: [],
      codeReference: CodeReference('fake_path', 123, 'test_description',
          'Code for the \${variable} code god.'),
    );

    final globalVariables = [
      MonitorVariable(name: 'global1', value: 'global_value_1'),
      MonitorVariable(name: 'global2', value: 'second global value'),
    ];

    final expectedResult = r'''resource "datadog_monitor" test_global_value_1 {
  argument1 = global_value_1, second global value # comment

  Code for the $${variable} code god.
}''';

    final result =
        template.render(configuration, globalVariables, issueReporter).trim();
    expect(result, expectedResult);
  });

  test('render ignores when MonitorConfiguration.shouldIgnore = true', () {
    final template =
        MonitorTemplate(r'''resource "datadog_monitor" ${{monitor_id}} {
  argument1 = ${{argument1_value}} # comment
}''');

    final var1 =
        MonitorVariable(name: 'monitor_id', value: 'test_\${{global1}}');
    final var2 = MonitorVariable(
        name: 'argument1_value', value: '\${{global1}}, \${{global2}}');
    final configuration = MonitorConfiguration(
        type: MonitorType.logs,
        shouldIgnore: true,
        variables: [var1, var2],
        variants: [],
        codeReference: mockCodeReference);

    final globalVariables = [
      MonitorVariable(name: 'global1', value: 'global_value_1'),
      MonitorVariable(name: 'global2', value: 'second global value'),
    ];

    final expectedResult = '';

    final result =
        template.render(configuration, globalVariables, issueReporter).trim();
    expect(result, expectedResult);
  });
}
