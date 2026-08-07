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
  SendPort? _mainSendPort;
  Isolate? _processorIsolate;
  bool _isSpawning = false;
  // The port the current isolate signals on once it has finished shutting down.
  // Recreated per spawn, because a ReceivePort is single-subscription and cannot
  // be reused after `_shutdown` has consumed its first event.
  ReceivePort? _shutdownReceivePort;
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
      unawaited(_shutdown());
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

  /// Asks the processor isolate to stop, then waits for it to finish any
  /// in-flight snapshot and exit on its own. The isolate is only force
  /// killed as a fallback if it doesn't exit within [_shutdownTimeout] -
  /// killing it while it may still be mid-call into native JNI/ObjC code
  /// can leave those references in a bad state.
  Future<void> _shutdown() async {
    final isolate = _processorIsolate;
    final shutdownReceivePort = _shutdownReceivePort;
    if (isolate == null) {
      return;
    }
    // Cleared before awaiting so a `resumed` arriving mid-shutdown sees no
    // isolate and spawns a fresh one instead of reusing this dying one.
    _processorIsolate = null;
    _shutdownReceivePort = null;

    _mainSendPort?.send(null);
    _mainSendPort = null;
    try {
      await shutdownReceivePort?.first.timeout(_shutdownTimeout);
    } catch (_) {
      isolate.kill(priority: Isolate.immediate);
    } finally {
      shutdownReceivePort?.close();
    }
  }

  // Spawns the capture-processing isolate and completes the handshake. A fresh
  // ReceivePort is created on each call because ReceivePort is single-subscription
  // and cannot be reused after its initial handshake listener is consumed — this
  // is what allows the isolate to be restarted on resume after a detach.
  Future<void> _spawnIsolate() async {
    final port = ReceivePort('sr-replay-port');
    final shutdownPort = ReceivePort('sr-replay-shutdown-port');
    _shutdownReceivePort = shutdownPort;
    _processorIsolate = await Isolate.spawn(
      _captureProcessor,
      _ProcessorArgs(
        RootIsolateToken.instance!,
        DatadogSessionReplayPlatform.instance.isolateToken,
        port.sendPort,
        shutdownPort.sendPort,
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
