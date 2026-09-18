// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2024-Present Datadog, Inc.
import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_inappwebview_tracking/datadog_inappwebview_tracking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('user script has proper functions', () {
    final userScript = DatadogInAppWebViewUserScript(
      datadog: DatadogSdk.instance,
      allowedHosts: {},
    );

    // Split by lines ane check for specific functions
    final lines = userScript.source.split('\n').map((e) => e.trim());
    expect(lines, contains('send(msg) {'));
    expect(lines, contains('getAllowedWebViewHosts() {'));
    expect(lines, contains('getCapabilities() {'));
    expect(lines, contains('getPrivacyLevel() {'));
  });

  test('user script replaces bridge name', () {
    final bridgeName = randomString();
    final userScript = DatadogInAppWebViewUserScript(
      datadog: DatadogSdk.instance,
      bridgeName: bridgeName,
      allowedHosts: {},
    );

    final lines = userScript.source.split('\n').map((e) => e.trim()).toList();
    final sendIndex = lines.indexOf('send(msg) {');
    for (var i = sendIndex + 1; i < lines.length; ++i) {
      // Expect all lines that access 'window.' in 'send()' to be accessing the bridge,
      // and ensure that they've replaced the name properly.
      final line = lines[i];
      if (line == '},') break; // end of send function

      if (line.contains('window.')) {
        expect(lines[i], contains('window.$bridgeName'));
      }
    }
  });

  test('user script returns allowed hosts', () {
    final userScript = DatadogInAppWebViewUserScript(
      datadog: DatadogSdk.instance,
      allowedHosts: {'shopist.io'},
    );

    final lines = userScript.source.split('\n').map((e) => e.trim()).toList();
    final sendIndex = lines.indexOf('getAllowedWebViewHosts() {');
    expect(lines[sendIndex + 1], contains('return \'["shopist.io"]\''));
  });

  test('user script returns multiple allowed hosts', () {
    final userScript = DatadogInAppWebViewUserScript(
      datadog: DatadogSdk.instance,
      allowedHosts: {'shopist.io', 'datadoghq.com'},
    );

    final lines = userScript.source.split('\n').map((e) => e.trim()).toList();
    final sendIndex = lines.indexOf('getAllowedWebViewHosts() {');
    expect(lines[sendIndex + 1],
        contains('return \'["shopist.io","datadoghq.com"]\''));
  });

  test('user script sanitizes hosts', () {
    final userScript = DatadogInAppWebViewUserScript(
      datadog: DatadogSdk.instance,
      allowedHosts: {'https://shopist.io', '::Not valid URI::'},
    );

    final lines = userScript.source.split('\n').map((e) => e.trim()).toList();
    final sendIndex = lines.indexOf('getAllowedWebViewHosts() {');
    expect(lines[sendIndex + 1], contains('return \'["shopist.io"]\''));
  });
}
