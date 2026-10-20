// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:async';

import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:flutter/material.dart';

/// Shows whether Session Replay is capturing right now, read from
/// [DatadogSessionReplay.isCapturing].
///
/// Capture can start or stop without this screen changing: it waits for the
/// first RUM session at startup, and follows each new session's sampling
/// decision. So the status is re-checked periodically.
class RecordingStatus extends StatefulWidget {
  /// Shown when the screen expected to be recording but isn't.
  final String? notRecordingHint;

  const RecordingStatus({super.key, this.notRecordingHint});

  @override
  State<RecordingStatus> createState() => _RecordingStatusState();
}

class _RecordingStatusState extends State<RecordingStatus> {
  late final Timer _refreshTimer;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _isCapturing = _readIsCapturing();
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final isCapturing = _readIsCapturing();
      if (isCapturing != _isCapturing) {
        setState(() => _isCapturing = isCapturing);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  bool _readIsCapturing() =>
      DatadogSessionReplay.instance?.isCapturing ?? false;

  @override
  Widget build(BuildContext context) {
    final color = _isCapturing ? Colors.red : Colors.grey;
    final hint = widget.notRecordingHint;

    return Column(
      children: [
        Icon(
          _isCapturing ? Icons.fiber_manual_record : Icons.visibility_off,
          color: color,
          size: 40,
        ),
        const SizedBox(height: 4),
        Text(
          _isCapturing ? 'Being recorded' : 'NOT recorded',
          style: TextStyle(color: color),
        ),
        if (!_isCapturing && hint != null) ...[
          const SizedBox(height: 8),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
