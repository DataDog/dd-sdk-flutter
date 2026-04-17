// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:async';
import 'dart:math';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../datadog_session_replay.dart';
import 'capture/recorder.dart';
import 'datadog_session_replay_platform_interface.dart';
import 'processor/processor.dart';
import 'rum_context.dart';

class DatadogSessionReplay {
  // The minimum amount of time that needs to pass before we perform another
  // tree capture.
  static const minCaptureTiming = Duration(milliseconds: 100);
  // The number of times in quick succession thar SR capture can throw before
  // we shut it down completely.
  static const errorTollerance = 10;

  static DatadogSessionReplay? _instance;
  static DatadogSessionReplay? get instance => _instance;

  final DatadogSessionReplayConfiguration _configuration;
  @internal
  final InternalLogger internalLogger;

  final SessionReplayProcessor _processor = SessionReplayProcessor();
  final SessionReplayRecorder _recorder;

  final TouchPrivacyLevel defaultTouchPrivacyLevel;

  int _errorCounter = 0;
  bool _newFrameBuilt = true;

  /// Whether [platform.enable] succeeded during [_start].
  bool _platformEnabled = false;

  /// Whether periodic tree capture is active (timer running).
  bool _isRecording = false;

  Timer? _captureTimer;

  @internal
  static Future<DatadogSessionReplay> init(
    DatadogSessionReplayConfiguration configuration,
    InternalLogger logger, {
    DatadogTimeProvider timeProvider = const DefaultTimeProvider(),
  }) async {
    _instance = DatadogSessionReplay._(configuration, logger);
    await _instance!._start();
    return _instance!;
  }

  DatadogSessionReplay._(this._configuration, this.internalLogger)
      : defaultTouchPrivacyLevel = _configuration.touchPrivacyLevel,
        _recorder = SessionReplayRecorder(
          defaultCapturePrivacy: TreeCapturePrivacy(
            textAndInputPrivacyLevel: _configuration.textAndInputPrivacyLevel,
            imagePrivacyLevel: _configuration.imagePrivacyLevel,
          ),
          touchPrivacyLevel: _configuration.touchPrivacyLevel,
        );

  void addElement(Key key, Element e) {
    _recorder.addElement(key, e);
  }

  void removeElement(Key key) {
    _recorder.removeElement(key);
  }

  void _onContextChanged(RUMContext context) {
    _recorder.onContextChanged(context);
  }

  /// Starts periodic tree capture. Idempotent while already recording.
  void startRecording() {
    if (!_platformEnabled) {
      internalLogger.log(
        CoreLoggerLevel.warn,
        'DatadogSessionReplay.startRecording() ignored: Session Replay is not '
        'enabled (initialization did not succeed).',
      );
      return;
    }
    if (_isRecording) {
      return;
    }
    _isRecording = true;
    _startPeriodicCapture();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _newFrameBuilt = true;
    });
  }

  /// Stops periodic tree capture. The processor isolate keeps running.
  /// Idempotent while not recording.
  void stopRecording() {
    if (!_isRecording) {
      return;
    }
    _isRecording = false;
    _captureTimer?.cancel();
    _captureTimer = null;
  }

  /// Clears the singleton and stops capture. For tests only.
  @visibleForTesting
  static void resetForTest() {
    final inst = _instance;
    _instance = null;
    inst?.stopRecording();
  }

  /// Whether periodic capture is considered active (timer created and not cancelled).
  @visibleForTesting
  bool get debugIsRecordingForTest => _isRecording;

  /// Whether the periodic capture [Timer] exists and is still active.
  @visibleForTesting
  bool get debugIsCaptureTimerActiveForTest =>
      _captureTimer != null && _captureTimer!.isActive;

  Future<void> _start() async {
    final platform = DatadogSessionReplayPlatform.instance;
    bool success = false;
    await wrapAsync('enable', internalLogger, {}, () async {
      success = await platform.enable(_configuration, _onContextChanged);
    });

    _platformEnabled = success;
    if (success) {
      await _processor.start();

      if (_configuration.startRecordingImmediately) {
        startRecording();
      }
    }
  }

  void _startPeriodicCapture() {
    /// This timer periodically checks if a tree capture is necessary, which it
    /// only is if _newFrameBuilt has been set by a call to `postFrameCallback`
    ///
    /// Using the timer (instead of as part of addPostFrameCallback) allows
    /// Flutter to schedule this outside of the build phase, which means our
    /// tree capture shouldn't affect tree build time.
    _captureTimer?.cancel();
    _captureTimer = Timer.periodic(minCaptureTiming, (timer) async {
      if (!_isRecording) {
        return;
      }
      bool shouldWatchForNextFrame = true;
      if (_newFrameBuilt) {
        try {
          final captureResult = await _recorder.performCapture();
          if (captureResult != null) {
            _processor.process(captureResult);
          }
          _errorCounter = max(0, _errorCounter - 1);
        } catch (e, st) {
          internalLogger.sendToDatadog(
            'Exception during session replay capture: $e',
            st,
            e.runtimeType.toString(),
          );
          internalLogger.log(
            CoreLoggerLevel.warn,
            'Exception during session replay capture: $e',
          );
          _errorCounter += 1;
          if (_errorCounter > errorTollerance) {
            internalLogger.sendToDatadog(
              'Flutter SR has exceeded its error tollerance of $errorTollerance. Shutting down.',
              null,
              null,
            );
            // Too many errors, cancel this periodic timer and don't schedule
            // another post frame callback
            timer.cancel();
            _captureTimer = null;
            _isRecording = false;
            shouldWatchForNextFrame = false;
          }
        }
        _newFrameBuilt = false;
      }

      // If we've received too many errors, don't request any more post frame callbacks
      if (shouldWatchForNextFrame && _isRecording) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _newFrameBuilt = true;
        });
      }
    });
  }
}
