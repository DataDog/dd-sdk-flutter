// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test(
    'relaunches a missing CI emulator and retains the process log',
    () async {
      final root = await Directory.systemTemp.createTemp('android-recovery-');
      addTearDown(() => root.delete(recursive: true));
      final sdkPath = path.join(root.path, 'android sdk');
      final ciProjectPath = path.join(root.path, 'CI project');
      final log = File(path.join(ciProjectPath, 'tools', 'ci', 'emulator.log'));
      await log.create(recursive: true);
      await log.writeAsString('Output from the original emulator\n');

      final fakeExecutables = {
        'platform-tools/adb': r'''#!/bin/sh
case "$*" in
  devices)
    echo 'List of devices attached'
    if [ -f "$ANDROID_HOME/launched" ]; then
      printf 'emulator-5554\tdevice\n'
    fi
    ;;
  '-s emulator-5554 shell getprop sys.boot_completed')
    if [ -f "$ANDROID_HOME/boot-queried" ]; then
      touch "$ANDROID_HOME/booted"
      echo 1
    else
      touch "$ANDROID_HOME/boot-queried"
      echo 0
    fi
    ;;
  *) exit 1 ;;
esac
''',
        'emulator/emulator': r'''#!/bin/sh
[ "$1" = '-accel-check' ] && exit 0
printf '%s\n' "$@" > "$ANDROID_HOME/launched"
echo 'Output from the relaunched emulator'
attempts=0
while [ "$attempts" -lt 150 ]; do
  [ -f "$ANDROID_HOME/booted" ] && exit 23
  attempts=$((attempts + 1))
  sleep 0.1
done
exit 1
''',
      };
      for (final entry in fakeExecutables.entries) {
        final executable = File(path.join(sdkPath, entry.key));
        await executable.create(recursive: true);
        await executable.writeAsString(entry.value);
        final chmod = await Process.run('chmod', ['+x', executable.path]);
        expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
      }

      final script = File(path.join(root.path, 'recover.dart'));
      await script.writeAsString('''
import 'package:ci_helpers/integration_test_platform.dart';

Future<void> main() => TestPlatform.android.recoverDevice!();
''');
      final packageConfig = (await Isolate.packageConfig)!;
      final result = await Process.run(
        Platform.resolvedExecutable,
        ['--packages=${packageConfig.toFilePath()}', script.path],
        workingDirectory: root.path,
        environment: {
          'ANDROID_HOME': sdkPath,
          'ANDROID_EMULATOR_SDK': '33',
          'CI_PROJECT_DIR': ciProjectPath,
        },
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final arguments = await File(
        path.join(sdkPath, 'launched'),
      ).readAsLines();
      expect(arguments.first, '@ci_emu_api_33');
      expect(
        arguments,
        containsAllInOrder(['-gpu', 'swiftshader', '-feature', '-Vulkan']),
      );
      expect(await File(path.join(sdkPath, 'booted')).exists(), isTrue);

      const exitLog = 'Android emulator exited with status 23';
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      var output = await log.readAsString();
      while (!output.contains(exitLog) && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        output = await log.readAsString();
      }
      expect(output, contains('Output from the original emulator'));
      expect(output, contains('Output from the relaunched emulator'));
      expect(output, contains(exitLog));
    },
    skip: Platform.isWindows,
  );
}
