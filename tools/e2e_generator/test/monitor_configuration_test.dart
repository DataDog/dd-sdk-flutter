// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:e2e_generator/issue_reporter.dart';
import 'package:e2e_generator/monitor_configuration.dart';
import 'package:test/test.dart';

void main() {
  final mockCodeReference =
      CodeReference('fakeFile', 223, 'fake test description');
  final issueReporter = IssueReporter();

  setUp(() {
    issueReporter.clear();
  });

  test('Monitor parses correctly', () {
    final testComment = r'''/// ```logs
/// $foo = bar1
/// ```
''';

    final configList = MonitorConfiguration.fromComment(
        testComment, mockCodeReference, issueReporter);

    expect(configList, isNotNull);
    expect(configList.length, 1);

    var config = configList[0];
    expect(config.type, MonitorType.logs);
    expect(config.shouldIgnore, false);
    expect(config.variables.length, 1);
    expect(config.variables[0].name, 'foo');
    expect(config.variables[0].value, 'bar1');

    expect(config.codeReference, mockCodeReference);
  });

  test('Monitor with multiple variables parses correctly', () {
    final testComment = r'''/// ```apm
/// $foo = bar1
/// $var = bar2
/// ```
''';

    final configList = MonitorConfiguration.fromComment(
        testComment, mockCodeReference, issueReporter);
    expect(configList, isNotNull);
    expect(configList.length, 1);

    var config = configList[0];
    expect(config.type, MonitorType.apm);

    var var1 = config.variables[0];
    expect(var1.name, 'foo');
    expect(var1.value, 'bar1');

    var var2 = config.variables[1];
    expect(var2.name, 'var');
    expect(var2.value, 'bar2');
  });

  test('Multiple monitors with multiple variables parses correctly', () {
    final testComment = r'''/// ```logs
/// $foo = bar1
/// $var = bar2
/// ```
/// ```apm
/// $baz = bar3
/// $lul = bar4
/// ```
''';

    final configList = MonitorConfiguration.fromComment(
        testComment, mockCodeReference, issueReporter);
    expect(configList, isNotNull);
    expect(configList.length, 2);

    var config1 = configList[0];
    expect(config1.type, MonitorType.logs);
    expect(config1.variables[0].name, 'foo');
    expect(config1.variables[0].value, 'bar1');
    expect(config1.variables[1].name, 'var');
    expect(config1.variables[1].value, 'bar2');

    var config2 = configList[1];
    expect(config2.type, MonitorType.apm);
    expect(config2.variables[0].name, 'baz');
    expect(config2.variables[0].value, 'bar3');
    expect(config2.variables[1].name, 'lul');
    expect(config2.variables[1].value, 'bar4');
  });

  test('Multiple monitors with multiple variables parses correctly', () {
    final testComment = r'''/// ```logs
/// $foo = bar1
/// $var = bar2
/// ```
/// ```rum
/// $baz = bar3
/// $lul = bar4
/// ```
''';

    final configList = MonitorConfiguration.fromComment(
        testComment, mockCodeReference, issueReporter);
    expect(configList, isNotNull);
    expect(configList.length, 2);

    var config1 = configList[0];
    expect(config1.type, MonitorType.logs);
    expect(config1.variables[0].name, 'foo');
    expect(config1.variables[0].value, 'bar1');
    expect(config1.variables[1].name, 'var');
    expect(config1.variables[1].value, 'bar2');

    var config2 = configList[1];
    expect(config2.type, MonitorType.rum);
    expect(config2.variables[0].name, 'baz');
    expect(config2.variables[0].value, 'bar3');
    expect(config2.variables[1].name, 'lul');
    expect(config2.variables[1].value, 'bar4');
  });

  test('Parsing monitors with variant indicators', () {
    final testComment = r'''/// ```logs(ios, android)
/// $foo = bar1
/// $var2 = bar2
/// ```
''';

    final configList = MonitorConfiguration.fromComment(
        testComment, mockCodeReference, issueReporter);
    expect(configList, isNotNull);
    expect(configList.length, 1);

    var config = configList[0];
    expect(config.shouldIgnore, false);
    expect(config.variants, ['ios', 'android']);
  });

  test('Monitors with IGNORE set should ignore', () {
    final testComment = r'''/// ```logs IGNORE
/// $foo = bar1
/// $var2 = bar2
/// ```
''';

    final configList = MonitorConfiguration.fromComment(
        testComment, mockCodeReference, issueReporter);
    expect(configList, isNotNull);
    expect(configList.length, 1);

    var config = configList[0];
    expect(config.shouldIgnore, true);
  });

  test('Monitors with variants and IGNORE set should ignore', () {
    final testComment = r'''/// ```logs(ios, android) IGNORE
/// $foo = bar1
/// $var2 = bar2
/// ```
''';

    final configList = MonitorConfiguration.fromComment(
        testComment, mockCodeReference, issueReporter);
    expect(configList, isNotNull);
    expect(configList.length, 1);

    var config = configList[0];
    expect(config.shouldIgnore, true);
  });

  test('Parser ignores comments between monitors', () {
    final testComment = r'''/// Testing comment number 1
/// ```logs
/// $foo = bar1
/// $var = bar2
/// ```
/// Testing number 2
/// ```apm
/// $baz = bar3
/// $lul = bar4
/// ```
''';

    final configList = MonitorConfiguration.fromComment(
        testComment, mockCodeReference, issueReporter);
    expect(configList, isNotNull);
    expect(configList.length, 2);

    var config1 = configList[0];
    expect(config1.type, MonitorType.logs);
    expect(config1.variables[0].name, 'foo');
    expect(config1.variables[0].value, 'bar1');
    expect(config1.variables[1].name, 'var');
    expect(config1.variables[1].value, 'bar2');

    var config2 = configList[1];
    expect(config2.type, MonitorType.apm);
    expect(config2.variables[0].name, 'baz');
    expect(config2.variables[0].value, 'bar3');
    expect(config2.variables[1].name, 'lul');
    expect(config2.variables[1].value, 'bar4');
  });

  test('Parser ignores unknown region types', () {
    final testComment = r'''/// Testing comment number 1
/// ```bad
/// $foo = bar1
/// $var = bar2
/// ```
/// Testing number 2
/// ```apm
/// $baz = bar3
/// $lul = bar4
/// ```
''';
    final configList = MonitorConfiguration.fromComment(
        testComment, mockCodeReference, issueReporter);
    expect(configList, isNotNull);
    expect(configList.length, 1);

    var config1 = configList[0];
    expect(config1.type, MonitorType.apm);
    expect(config1.variables[0].name, 'baz');
    expect(config1.variables[0].value, 'bar3');
    expect(config1.variables[1].name, 'lul');
    expect(config1.variables[1].value, 'bar4');
  });

  test('Unknown region type reports issue', () {
    final testComment = r'''/// Testing comment number 1
/// ```bad
/// $foo = bar1
/// $var = bar2
/// ```
''';
    MonitorConfiguration.fromComment(
        testComment, mockCodeReference, issueReporter);

    expect(issueReporter.issues.length, 1);
    expect(issueReporter.issues[0].severity, IssueSeverity.warning);
    expect(issueReporter.issues[0].codeReference, mockCodeReference);
    expect(issueReporter.issues[0].message, isNotNull);
  });

  test('Missing monitor type emits error', () {
    final testComment = r'''/// Testing comment number 1
/// ```
/// $foo = bar1
/// $var = bar2
/// ```
''';

    var config = MonitorConfiguration.fromComment(
        testComment, mockCodeReference, issueReporter);

    expect(issueReporter.issues.length, 2);
    expect(issueReporter.issues[0].severity, IssueSeverity.error);
    expect(issueReporter.issues[0].codeReference, mockCodeReference);

    // Reports once for the start, once for the bottom.
    expect(issueReporter.issues[1].severity, IssueSeverity.error);
    expect(issueReporter.issues[1].codeReference, mockCodeReference);

    expect(config.isEmpty, isTrue);
  });

  test('Bad variable definition emits error', () {
    final testComment = r'''/// ```apm
/// foo = bar1
/// ```
''';

    MonitorConfiguration.fromComment(
        testComment, mockCodeReference, issueReporter);

    expect(issueReporter.issues.length, 1);
    expect(issueReporter.issues[0].severity, IssueSeverity.error);
    expect(issueReporter.issues[0].codeReference, mockCodeReference);
  });

  test('Missing monitor end emits error', () {
    final testComment = r'''/// ```apm
/// $foo = bar1''';

    MonitorConfiguration.fromComment(
        testComment, mockCodeReference, issueReporter);

    expect(issueReporter.issues.length, 1);
    expect(issueReporter.issues[0].severity, IssueSeverity.error);
    expect(issueReporter.issues[0].codeReference, mockCodeReference);
  });

  test('Parsing ignores blank lines and other whitespace in definition', () {
    final testComment = r'''/// ```apm
/// $foo = bar1
/// 
///   $baz =  bar2  
/// ```''';

    var config = MonitorConfiguration.fromComment(
        testComment, mockCodeReference, issueReporter);

    expect(issueReporter.issues.length, 0);

    expect(config.length, 1);
    expect(config[0].variables.length, 2);
    expect(config[0].variables[0].name, 'foo');
    expect(config[0].variables[0].value, 'bar1');

    expect(config[0].variables[1].name, 'baz');
    expect(config[0].variables[1].value, 'bar2');
  });

  test('Parsing group contains all monitors', () {
    final testComment = r'''/// ```logs
/// $foo = bar1
/// $var = bar2
/// ```
/// ```apm
/// $baz = bar3
/// $lul = bar4
/// ```
''';

    final group =
        MonitorGroup.fromComment(testComment, mockCodeReference, issueReporter);

    expect(group.monitors.length, 2);

    var config1 = group.monitors[0];
    expect(config1.type, MonitorType.logs);
    expect(config1.variables[0].name, 'foo');
    expect(config1.variables[0].value, 'bar1');
    expect(config1.variables[1].name, 'var');
    expect(config1.variables[1].value, 'bar2');

    var config2 = group.monitors[1];
    expect(config2.type, MonitorType.apm);
    expect(config2.variables[0].name, 'baz');
    expect(config2.variables[0].value, 'bar3');
    expect(config2.variables[1].name, 'lul');
    expect(config2.variables[1].value, 'bar4');
  });

  test('Parsing group with global pull out global variables', () {
    final testComment = r'''/// ```global
/// $global1 = global value
/// $global2 = other global value
/// ```
/// ```logs
/// $log1 = ${{global1}}
/// ```
/// ```apm
/// $baz = bar3
/// $lul = bar4
/// ```
''';

    final group =
        MonitorGroup.fromComment(testComment, mockCodeReference, issueReporter);

    expect(group.monitors.length, 2);

    expect(group.variables.length, 2);
    expect(group.variables[0].name, 'global1');
    expect(group.variables[0].value, 'global value');
    expect(group.variables[1].name, 'global2');
    expect(group.variables[1].value, 'other global value');

    var config1 = group.monitors[0];
    expect(config1.type, MonitorType.logs);
    expect(config1.variables[0].name, 'log1');
    expect(config1.variables[0].value, '\${{global1}}');

    var config2 = group.monitors[1];
    expect(config2.type, MonitorType.apm);
    expect(config2.variables[0].name, 'baz');
    expect(config2.variables[0].value, 'bar3');
    expect(config2.variables[1].name, 'lul');
    expect(config2.variables[1].value, 'bar4');
  });
}
