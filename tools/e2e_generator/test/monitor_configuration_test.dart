// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:e2e_generator/issue_reporter.dart';
import 'package:e2e_generator/monitor_configuration.dart';
import 'package:test/test.dart';

void main() {
  final mockCodeReference =
      CodeReference('fakeFile', 223, 'fake test description');

  void nullIssueReporter(
      IssueSeverity severity, CodeReference codeReference, String message) {}

  test('Monitor parses correctly', () {
    final testComment = r'''/// ```logs
/// $foo = bar1
/// ```
''';

    final configList = MonitorConfiguration.fromComment(
        testComment, mockCodeReference, nullIssueReporter);

    expect(configList, isNotNull);
    expect(configList.length, 1);

    var config = configList[0];
    expect(config.type, MonitorType.logs);
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
        testComment, mockCodeReference, nullIssueReporter);
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
        testComment, mockCodeReference, nullIssueReporter);
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
        testComment, mockCodeReference, nullIssueReporter);
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
        testComment, mockCodeReference, nullIssueReporter);
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
        testComment, mockCodeReference, nullIssueReporter);
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
    IssueSeverity? reportedIssueSeverity;
    CodeReference? reportedCodeReference;
    String? reportedMessage;
    void issueReporter(
        IssueSeverity severity, CodeReference reference, String message) {
      reportedIssueSeverity = severity;
      reportedCodeReference = reference;
      reportedMessage = message;
    }

    MonitorConfiguration.fromComment(
        testComment, mockCodeReference, issueReporter);

    expect(reportedIssueSeverity, IssueSeverity.warning);
    expect(reportedCodeReference, mockCodeReference);
    expect(reportedMessage, isNotNull);
  });

  test('Missing monitor type emits error', () {
    final testComment = r'''/// Testing comment number 1
/// ```
/// $foo = bar1
/// $var = bar2
/// ```
''';

    final reportedSeverities = <IssueSeverity>[];
    final reportedRefs = <CodeReference>[];
    void issueReporter(
        IssueSeverity severity, CodeReference reference, String message) {
      reportedSeverities.add(severity);
      reportedRefs.add(reference);
    }

    var config = MonitorConfiguration.fromComment(
        testComment, mockCodeReference, issueReporter);

    expect(reportedSeverities.length, 2);
    expect(reportedSeverities[0], IssueSeverity.error);
    expect(reportedRefs[0], mockCodeReference);

    // Reports once for the start, once for the bottom.
    expect(reportedSeverities[1], IssueSeverity.error);
    expect(reportedRefs[1], mockCodeReference);

    expect(config.isEmpty, isTrue);
  });

  test('Bad variable definition emits error', () {
    final testComment = r'''/// ```apm
/// foo = bar1
/// ```
''';

    final reportedSeverities = <IssueSeverity>[];
    final reportedRefs = <CodeReference>[];
    void issueReporter(
        IssueSeverity severity, CodeReference reference, String message) {
      reportedSeverities.add(severity);
      reportedRefs.add(reference);
    }

    MonitorConfiguration.fromComment(
        testComment, mockCodeReference, issueReporter);

    expect(reportedSeverities.length, 1);
    expect(reportedSeverities[0], IssueSeverity.error);
    expect(reportedRefs[0], mockCodeReference);
  });

  test('Missing monitor end emits error', () {
    final testComment = r'''/// ```apm
/// $foo = bar1''';

    final reportedSeverities = <IssueSeverity>[];
    final reportedRefs = <CodeReference>[];
    void issueReporter(
        IssueSeverity severity, CodeReference reference, String message) {
      reportedSeverities.add(severity);
      reportedRefs.add(reference);
    }

    MonitorConfiguration.fromComment(
        testComment, mockCodeReference, issueReporter);

    expect(reportedSeverities.length, 1);
    expect(reportedSeverities[0], IssueSeverity.error);
    expect(reportedRefs[0], mockCodeReference);
  });

  test('Parsing ignores blank lines and other whitespace in definition', () {
    final testComment = r'''/// ```apm
/// $foo = bar1
/// 
///   $baz =  bar2  
/// ```''';

    final reportedSeverities = <IssueSeverity>[];
    final reportedRefs = <CodeReference>[];
    void issueReporter(
        IssueSeverity severity, CodeReference reference, String message) {
      reportedSeverities.add(severity);
      reportedRefs.add(reference);
    }

    var config = MonitorConfiguration.fromComment(
        testComment, mockCodeReference, issueReporter);

    expect(reportedSeverities.length, 0);

    expect(config.length, 1);
    expect(config[0].variables.length, 2);
    expect(config[0].variables[0].name, 'foo');
    expect(config[0].variables[0].value, 'bar1');

    expect(config[0].variables[1].name, 'baz');
    expect(config[0].variables[1].value, 'bar2');
  });
}
