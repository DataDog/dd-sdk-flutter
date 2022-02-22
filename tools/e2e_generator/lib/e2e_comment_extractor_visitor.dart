// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:dart_style/dart_style.dart';

import 'issue_reporter.dart';
import 'monitor_configuration.dart';

class E2ECommentExtractorVisitor extends RecursiveAstVisitor<void> {
  final ResolvedUnitResult context;
  final IssueReporter issueReporter;
  final DartFormatter formatter = DartFormatter();
  // FUTURE IMPROVEMENT: Have Monitor Groups hold child monitor groups and have each
  // file return one. Variables from each group would then be passed down to
  // children instead of assuming one global set of variables added to each
  // sub-group
  final List<MonitorVariable> globalVariables = [];
  final List<MonitorGroup> groups = [];

  E2ECommentExtractorVisitor(this.context, this.issueReporter);

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    var nameNode = node.name;
    var nameElement = nameNode.staticElement;
    if (nameElement is FunctionElement && nameElement.isEntryPoint) {
      final location = context.lineInfo.getLocation(node.beginToken.offset);
      final codeReference =
          CodeReference(context.path.toString(), location.lineNumber, 'main');

      if (node.documentationComment != null) {
        final comments =
            _getCommentString(node.documentationComment!.beginToken);

        var group =
            MonitorGroup.fromComment(comments, codeReference, issueReporter);
        globalVariables.addAll(group.variables);
        if (group.monitors.isNotEmpty) {
          issueReporter.pushReference(codeReference);
          issueReporter.report(IssueSeverity.warning,
              'Top level function (main) specifies non-global monitor. This is not supported.');
          issueReporter.popReference();
        }
      }
    }
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    var nameNode = node.methodName;
    var nameElement = nameNode.staticElement;
    if (nameElement is! ExecutableElement) {
      return;
    }

    var comments = _getCommentString(node.beginToken.precedingComments);

    if (nameElement.hasIsTest) {
      var name = _extractTestDescription(node.argumentList.arguments);

      // Need the extra ; at the end because the AST doesn't have it
      var formattedCode = formatter.formatStatement('${node.toSource()};');

      final location = context.lineInfo.getLocation(node.beginToken.offset);
      final codeReference = CodeReference(
        context.path.toString(),
        location.lineNumber,
        name,
        formattedCode,
      );
      final group =
          MonitorGroup.fromComment(comments, codeReference, issueReporter);
      group.variables.addAll(globalVariables);
      group.variables.add(MonitorVariable(
          name: 'test_description', value: codeReference.testDescription));
      groups.add(group);
    } else {
      super.visitMethodInvocation(node);
    }
  }

  String _extractTestDescription(NodeList<Expression>? arguments) {
    if (arguments != null && arguments.isNotEmpty) {
      var argument = arguments[0];
      if (argument is StringLiteral) {
        var value = argument.stringValue;
        if (value != null) {
          return value;
        }
      }
      return argument.toSource();
    }
    return 'unnamed';
  }

  String _getCommentString(Token? comment) {
    final commentString = StringBuffer();
    while (comment != null) {
      commentString.writeln(comment.value());
      comment = comment.next;
    }

    return commentString.toString();
  }
}
