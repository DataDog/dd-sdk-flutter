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
  final ReceivePort _mainReceivePort = ReceivePort('sr-replay-port');
  SendPort? _mainSendPort;
  Isolate? _processorIsolate;
  FontFamilyTransformConfig _fontFamilyTransform =
      const FontFamilyTransformConfig();

  Future<void> start({
    FontFamilyTransformConfig fontFamilyTransform =
        const FontFamilyTransformConfig(),
  }) async {
    _fontFamilyTransform = fontFamilyTransform;
    WidgetsBinding.instance.addObserver(this);
    _processorIsolate = await Isolate.spawn(
      _captureProcessor,
      _ProcessorArgs(
        RootIsolateToken.instance!,
        DatadogSessionReplayPlatform.instance.isolateToken,
        _mainReceivePort.sendPort,
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
      _mainSendPort?.send(null);
      _processorIsolate?.kill(priority: Isolate.immediate);
      _mainSendPort = null;
      _processorIsolate = null;
    } else if (state == AppLifecycleState.resumed) {
      if (_processorIsolate == null) {
        // ignore: unawaited_futures
        _spawnIsolate();
      }
    }
  }

  // Called on resume to restart the isolate after detach. A new ReceivePort is
  // required because ReceivePort is single-subscription and cannot be reused
  // after the initial handshake listener is consumed.
  //
  // A new ReceivePort is required because ReceivePort is single-subscription
  // and cannot be reused after the initial handshake listener is consumed.
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
