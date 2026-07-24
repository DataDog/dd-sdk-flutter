// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../datadog_session_replay.dart';
import '../capture/recorder.dart';
import '../datadog_session_replay_init_stub.dart'
    if (dart.library.io) '../datadog_session_replay_init_mobile.dart';
import '../datadog_session_replay_platform_interface.dart';
import 'processor_worker.dart';

/// How long to wait for the processor isolate to finish any in-flight
/// snapshot and exit on its own before forcibly killing it.
const _shutdownTimeout = Duration(seconds: 2);

/// Spawns a background isolate to process session replay snapshots before
/// sending them to the native platform for serialization and distribution to
/// intake
class SessionReplayProcessor with WidgetsBindingObserver {
  final ReceivePort _mainReceivePort = ReceivePort('sr-replay-port');
  final ReceivePort _shutdownReceivePort = ReceivePort(
    'sr-replay-shutdown-port',
  );
  SendPort? _mainSendPort;
  Isolate? _processorIsolate;

  Future<void> start({
    FontFamilyTransformConfig fontFamilyTransform =
        const FontFamilyTransformConfig(),
  }) async {
    WidgetsBinding.instance.addObserver(this);
    _processorIsolate = await Isolate.spawn(
      _captureProcessor,
      _ProcessorArgs(
        RootIsolateToken.instance!,
        DatadogSessionReplayPlatform.instance.isolateToken,
        _mainReceivePort.sendPort,
        _shutdownReceivePort.sendPort,
        fontFamilyTransform,
      ),
    );

    _mainSendPort = await _mainReceivePort.first;
  }

  void process(CaptureResult captureResult) {
    _mainSendPort?.send(captureResult);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(_shutdown());
    }
  }

  /// Asks the processor isolate to stop, then waits for it to finish any
  /// in-flight snapshot and exit on its own. The isolate is only force
  /// killed as a fallback if it doesn't exit within [_shutdownTimeout] -
  /// killing it while it may still be mid-call into native JNI/ObjC code
  /// can leave those references in a bad state.
  Future<void> _shutdown() async {
    final isolate = _processorIsolate;
    if (isolate == null) {
      return;
    }
    _processorIsolate = null;

    _mainSendPort?.send(null);
    try {
      await _shutdownReceivePort.first.timeout(_shutdownTimeout);
    } catch (_) {
      isolate.kill(priority: Isolate.immediate);
    } finally {
      _shutdownReceivePort.close();
    }
  }

  static Future<void> _captureProcessor(_ProcessorArgs args) async {
    attachSessionReplayToIsolate(args.platformIsolateToken);

    final ReceivePort commandPort = ReceivePort();
    final responsePort = args.sendPort;
    responsePort.send(commandPort.sendPort);

    final internalProcessor = ProcessorWorker(
      fontFamilyTransform: args.fontFamilyTransform,
    );

    await for (final message in commandPort) {
      if (message is CaptureResult) {
        await internalProcessor.processSnapshot(message);
      } else if (message == null) {
        break;
      }
    }

    commandPort.close();
    args.shutdownSendPort.send(null);
    Isolate.exit();
  }
}

@immutable
class _ProcessorArgs {
  final RootIsolateToken rootIsolateToken;
  final Object? platformIsolateToken;
  final SendPort sendPort;
  final SendPort shutdownSendPort;
  final FontFamilyTransformConfig fontFamilyTransform;

  const _ProcessorArgs(
    this.rootIsolateToken,
    this.platformIsolateToken,
    this.sendPort,
    this.shutdownSendPort,
    this.fontFamilyTransform,
  );
}
