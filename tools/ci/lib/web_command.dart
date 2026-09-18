// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:args/command_runner.dart';
import 'package:ci_helpers/shell_helpers.dart';
import 'package:ci_helpers/web_helpers.dart';

class WebCommand extends Command {
  @override
  String get name => 'chrome_driver';

  WebCommand() {
    argParser.addFlag('extract', defaultsTo: false);
  }

  @override
  String get description => 'Download Chrome and chromedriver';

  @override
  Future<void> run() async {
    final args = argResults;
    if (args == null) {
      return;
    }

    await downloadChromeAndDriver();

    if (args['extract'] as bool) {
      print('📖 Unzipping chrome at .tmp/chrome.zip');
      await shellRun('unzip', ['chrome.zip'],
          writeStdOut: true, workingDirectory: '.tmp');

      print('📖 Unzipping driver at .tmp/chromedriver.zip');
      await shellRun('unzip', ['chromedriver.zip'],
          writeStdOut: true, workingDirectory: '.tmp');
    }
  }
}
