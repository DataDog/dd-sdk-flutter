// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../datadog_session_replay.dart';
import '../capture/recorder.dart';
import '../datadog_session_replay_init_stub.dart'
    if (dart.library.io) '../datadog_session_replay_init_mobile.dart';
import '../datadog_session_replay_platform_interface.dart';
import 'processor_worker.dart';

/// Spawns a background isolate to process session replay snapshots before
/// sending them to the native platform for serialization and distribution to
/// intake
class SessionReplayProcessor with WidgetsBindingObserver {
  SendPort? _mainSendPort;
  Isolate? _processorIsolate;
  bool _isSpawning = false;
  FontFamilyTransformConfig _fontFamilyTransform =
      const FontFamilyTransformConfig();

  Future<void> start({
    FontFamilyTransformConfig fontFamilyTransform =
        const FontFamilyTransformConfig(),
  }) async {
    _fontFamilyTransform = fontFamilyTransform;
    WidgetsBinding.instance.addObserver(this);
    await _spawnIsolate();
  }

  void process(CaptureResult captureResult) {
    _mainSendPort?.send(captureResult);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _mainSendPort?.send(null);
      _processorIsolate?.kill(priority: Isolate.immediate);
      _mainSendPort = null;
      _processorIsolate = null;
    } else if (state == AppLifecycleState.resumed) {
      // Guard with `_isSpawning` in addition to the null check: `_spawnIsolate`
      // awaits `Isolate.spawn`, so `_processorIsolate` stays null during the spawn.
      // Without the latch, a second `resumed` arriving mid-spawn would start a
      // duplicate isolate and leak the first.
      if (_processorIsolate == null && !_isSpawning) {
        _isSpawning = true;
        // ignore: unawaited_futures
        _spawnIsolate().whenComplete(() => _isSpawning = false);
      }
    }
  }

  // Spawns the capture-processing isolate and completes the handshake. A fresh
  // ReceivePort is created on each call because ReceivePort is single-subscription
  // and cannot be reused after its initial handshake listener is consumed — this
  // is what allows the isolate to be restarted on resume after a detach.
  Future<void> _spawnIsolate() async {
    final port = ReceivePort('sr-replay-port');
    _processorIsolate = await Isolate.spawn(
      _captureProcessor,
      _ProcessorArgs(
        RootIsolateToken.instance!,
        DatadogSessionReplayPlatform.instance.isolateToken,
        port.sendPort,
        _fontFamilyTransform,
      ),
    );
    _mainSendPort = await port.first;
    port.close();
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
    Isolate.exit();
  }
}

@immutable
class _ProcessorArgs {
  final RootIsolateToken rootIsolateToken;
  final Object? platformIsolateToken;
  final SendPort sendPort;
  final FontFamilyTransformConfig fontFamilyTransform;

  const _ProcessorArgs(
    this.rootIsolateToken,
    this.platformIsolateToken,
    this.sendPort,
    this.fontFamilyTransform,
  );
}
