#!/usr/bin/env python3
# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2026-Present Datadog, Inc.

"""Apply the VM discovery experiment to the disposable CI Flutter SDK.

Job 2115239749 emitted its VM service URL 660ms before log stream started.
Wait for log stream to report startup before launching each app, and bound
readiness and VM discovery so startup failures cannot hang the job.

Apply only to a disposable CI SDK. Use --check to inspect without changing files.
"""

import argparse
from pathlib import Path
import shutil

PATCHES = (
    (
        "    ProtocolDiscovery? vmServiceDiscovery;",
        """    ProtocolDiscovery? vmServiceDiscovery;
    Future<void>? logReaderReady;""",
    ),
    (
        """      vmServiceDiscovery = ProtocolDiscovery.vmService(
        getLogReader(app: package),""",
        """      final DeviceLogReader logReader = getLogReader(app: package);
      vmServiceDiscovery = ProtocolDiscovery.vmService(
        logReader,""",
    ),
    (
        """        logger: globals.logger,
      );
    }

    // Launch the updated application in the simulator.""",
        """        logger: globals.logger,
      );
      if (logReader is _IOSSimulatorLogReader) {
        logReaderReady = logReader.ready;
      }
    }

    // Launch the updated application in the simulator.""",
    ),
    (
        "      await _simControl.launch(id, bundleIdentifier, launchArguments);",
        """      // The app can announce its VM service before log stream starts.
      await logReaderReady?.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException(
          'iOS simulator log stream readiness timed out after 30 seconds.',
        ),
      );
      await _simControl.launch(id, bundleIdentifier, launchArguments);""",
    ),
    (
        """    } on Exception catch (error) {
      globals.printError('$error');
      return LaunchResult.failed();
    }

    if (!debuggingOptions.debuggingEnabled)""",
        """    } on Exception catch (error) {
      globals.printError('$error');
      await vmServiceDiscovery?.cancel();
      return LaunchResult.failed();
    }

    if (!debuggingOptions.debuggingEnabled)""",
    ),
    (
        "      final Uri? deviceUri = await vmServiceDiscovery?.uri;",
        """      final Uri? deviceUri = await vmServiceDiscovery?.uri.timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException(
          'iOS VM Service discovery timed out after 60 seconds.',
        ),
      );""",
    ),
    (
        """  final String? _appName;

  late final _linesController""",
        """  final String? _appName;

  Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  late final _linesController""",
    ),
    (
        """  Future<void> _start() async {
    // Unified logging""",
        """  Future<void> _start() async {
    _ready = Completer<void>();
    // Unified logging""",
    ),
    (
        """      _deviceProcess?.stderr.transform(utf8LineDecoder).listen(_onSysLogDeviceLine);
    }

    // Track system.log crashes.""",
        """      _deviceProcess?.stderr.transform(utf8LineDecoder).listen(_onSysLogDeviceLine);
      _ready.complete();
    }

    // Track system.log crashes.""",
    ),
    (
        """  void _onUnifiedLoggingLine(String line) {
    // The log command predicate""",
        """  void _onUnifiedLoggingLine(String line) {
    if (line.startsWith('Filtering the log data using ')) {
      if (!_ready.isCompleted) {
        _ready.complete();
        globals.printTrace('iOS simulator log stream is ready.');
      }
      return;
    }
    // The log command predicate""",
    ),
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sdk-root', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()

    flutter = shutil.which('flutter')
    if args.sdk_root is None and flutter is None:
        parser.error('flutter is not on PATH; pass --sdk-root')
    sdk_root = (args.sdk_root or Path(flutter).resolve().parent.parent).resolve()
    source = sdk_root / 'packages/flutter_tools/lib/src/ios/simulators.dart'
    original = source.read_text()
    updated = original
    for before, after in PATCHES:
        if updated.count(before) != 1:
            parser.error(f'Unexpected Flutter source at {source}; expected one match for {before!r}')
        updated = updated.replace(before, after, 1)

    if args.check:
        print(f'VM discovery patch matches {source}')
        return
    source.write_text(updated)
    # Flutter caches the tool snapshot by Git revision, not source contents.
    for name in ('flutter_tools.snapshot', 'flutter_tools.stamp'):
        (sdk_root / 'bin/cache' / name).unlink(missing_ok=True)
    print(f'Patched {source}: wait for log stream startup (30s), VM discovery timeout (60s)')


if __name__ == '__main__':
    main()
