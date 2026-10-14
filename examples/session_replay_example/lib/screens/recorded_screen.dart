// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:flutter/material.dart';

import 'recording_status.dart';

/// A screen that is fine to record. Recording starts when it is shown.
class RecordedScreen extends StatefulWidget {
  final double replaySampleRate;

  const RecordedScreen({super.key, required this.replaySampleRate});

  @override
  State<RecordedScreen> createState() => _RecordedScreenState();
}

class _RecordedScreenState extends State<RecordedScreen> {
  static const _colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
  ];

  int _counter = 0;
  int _colorIndex = 0;
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Capture runs while the current RUM session is sampled for replay, and
    // starts automatically when a later session is.
    DatadogSessionReplay.instance?.startRecording();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // 50.0 -> "50", 12.5 -> "12.5"
  static String _formatRate(double rate) =>
      rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : '$rate';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          RecordingStatus(
            notRecordingHint: 'The current RUM session was not selected by '
                'replaySampleRate (${_formatRate(widget.replaySampleRate)}%). '
                'Recording starts when a sampled session begins.',
          ),
          const SizedBox(height: 24),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _colors[_colorIndex],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => setState(
              () => _colorIndex = (_colorIndex + 1) % _colors.length,
            ),
            child: const Text('Change Color'),
          ),
          const SizedBox(height: 24),
          Text(
            'Counter: $_counter',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton(
                onPressed: () => setState(() => _counter--),
                child: const Icon(Icons.remove),
              ),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: () => setState(() => _counter++),
                child: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _textController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Type something…',
            ),
          ),
        ],
      ),
    );
  }
}
