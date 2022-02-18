// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import 'issue_reporter.dart';
import 'monitor_configuration.dart';

class E2ECommentExtractorVisitor extends RecursiveAstVisitor<void> {
  final ResolvedUnitResult context;
  final IssueReporter issueReporter;
  final List<MonitorConfiguration> monitors = [];

  E2ECommentExtractorVisitor(this.context, this.issueReporter);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    var nameNode = node.methodName;
    var nameElement = nameNode.staticElement;
    if (nameElement is! ExecutableElement) {
      return;
    }

    String extractString(NodeList<Expression>? arguments) {
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

    List<Token> getPrecedingComments(Token token) {
      var comments = <Token>[];
      Token? comment = token.precedingComments;
      while (comment != null) {
        comments.add(comment);
        comment = comment.next;
      }
      return comments;
    }

    if (nameElement.hasIsTest) {
      var name = extractString(node.argumentList.arguments);
      var comments = getPrecedingComments(node.beginToken);
      var buffer = StringBuffer();
      for (final comment in comments) {
        buffer.writeln(comment.value());
      }

      final location = context.lineInfo.getLocation(node.beginToken.offset);
      final codeReference =
          CodeReference(context.path.toString(), location.lineNumber, name);
      final methodMonitors = MonitorConfiguration.fromComment(
          buffer.toString(), codeReference, issueReporter);
      monitors.addAll(methodMonitors);
    } else {
      super.visitMethodInvocation(node);
    }
  }
}
