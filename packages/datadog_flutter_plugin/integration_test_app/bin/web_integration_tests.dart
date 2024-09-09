// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

// Not all functionality is available in Flutter web. These integration tests
// are skipped because they do not work in Flutter web yet.
const fileExclude = [
  // Not a test
  'common.dart',
  // Web does not support configuraiton telemetry the same as mobile
  'configuration_telemetry_test.dart',
  // Web does not yet support mapping
  'logging_mapping_test.dart',
  // Web Kiosk support does not start new sessions on manual view starts or SPA
  // navigation
  'rum_kiosk_test.dart',
  // Web does not yet support mapping
  'rum_mapping_test.dart',
];

const testDriver = 'test_driver/integration_test.dart';

void main() async {
  // Check path
  var testDirectory = Directory('integration_test');
  if (!testDirectory.existsSync()) {
    print(
        'Could not find the "integration_test" directory. Make sure you are running this from the integration_test_app root');
    exit(1);
  }

  for (final file in testDirectory.listSync()) {
    if (file is File) {
      final baseName = path.basename(file.path);
      if (fileExclude.contains(baseName)) {
        continue;
      }

      final args = [
        'drive',
        '--driver=$testDriver',
        '--target=integration_test/$baseName',
        '-d',
        'web-server',
        '--browser-name=chrome',
        '--web-port=8080',
      ];
      final chromeExecutable = Platform.environment['CHROME_EXECUTABLE'];
      if (chromeExecutable != null) {
        args.add('--chrome-binary=$chromeExecutable');        
      }
      print('flutter ${args.join(' ')}');
      final process = await Process.start('flutter', args);
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((event) {
        print(event);
      });
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((event) {
        print(event);
      });

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        print('Command failed');
        exit(exitCode);
      }
    }
  }
}
