// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flags/datadog_flags.dart';
import 'package:flutter/material.dart';

import '../flags/flags_demo_runtime.dart';

class FlagsScreen extends StatefulWidget {
  final FlagsDemoRuntime runtime;

  const FlagsScreen({super.key, required this.runtime});

  @override
  State<FlagsScreen> createState() => _FlagsScreenState();
}

class _FlagsScreenState extends State<FlagsScreen> {
  static const _targetingKey = String.fromEnvironment('FLAGS_TARGETING_KEY',
      defaultValue: 'flutter-user');

  late final DatadogFlagsClient _client;
  String _status = 'idle';
  FlagDetails<bool>? _enabled;
  FlagDetails<String>? _title;
  FlagDetails<int>? _limit;
  FlagDetails<double>? _ratio;
  FlagDetails<Object?>? _config;

  @override
  void initState() {
    super.initState();
    _client = DatadogFlagsClient.shared();
    _refreshFlags();
  }

  Future<void> _refreshFlags() async {
    setState(() {
      _status = 'fetching';
    });
    await _client.setEvaluationContext(const DatadogFlagsEvaluationContext(
      targetingKey: _targetingKey,
      attributes: {
        'plan': 'dogfood',
        'platform': 'flutter',
      },
    ));
    _evaluate();
  }

  void _evaluate() {
    setState(() {
      _enabled = _client.getBooleanDetails(
        key: 'flutter.demo.enabled',
        defaultValue: false,
      );
      _title = _client.getStringDetails(
        key: 'flutter.demo.title',
        defaultValue: 'Fallback title',
      );
      _limit = _client.getIntegerDetails(
        key: 'flutter.demo.limit',
        defaultValue: 0,
      );
      _ratio = _client.getDoubleDetails(
        key: 'flutter.demo.ratio',
        defaultValue: 0,
      );
      _config = _client.getObjectDetails(
        key: 'flutter.demo.config',
        defaultValue: const {},
      );
      _status = 'evaluated';
    });
  }

  Future<void> _flush() async {
    await _client.flush();
    setState(() {
      _status = 'flushed';
    });
  }

  @override
  Widget build(BuildContext context) {
    final collector = widget.runtime.collector;
    return Scaffold(
      appBar: AppBar(title: const Text('Flags')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Row(label: 'Mode', value: widget.runtime.mode),
          _Row(label: 'Status', value: _status),
          const _Row(label: 'Targeting key', value: _targetingKey),
          if (collector != null) ...[
            _Row(
              label: 'Exposures',
              value: '${collector.exposureCount}',
              valueKey: const Key('flags-exposure-count'),
            ),
            _Row(
              label: 'Evaluation requests',
              value: '${collector.evaluationRequestCount}',
              valueKey: const Key('flags-evaluation-request-count'),
            ),
            _Row(
              label: 'Evaluation events',
              value: '${collector.evaluationEventCount}',
              valueKey: const Key('flags-evaluation-event-count'),
            ),
          ],
          const SizedBox(height: 16),
          _DetailsRow(label: 'Boolean', details: _enabled),
          _DetailsRow(label: 'String', details: _title),
          _DetailsRow(label: 'Integer', details: _limit),
          _DetailsRow(label: 'Double', details: _ratio),
          _DetailsRow(label: 'Object', details: _config),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              ElevatedButton(
                onPressed: _refreshFlags,
                child: const Text('Set context'),
              ),
              ElevatedButton(
                onPressed: _evaluate,
                child: const Text('Evaluate'),
              ),
              ElevatedButton(
                onPressed: _flush,
                child: const Text('Flush'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailsRow extends StatelessWidget {
  final String label;
  final FlagDetails<dynamic>? details;

  const _DetailsRow({required this.label, required this.details});

  @override
  Widget build(BuildContext context) {
    final value = details;
    return _Row(
      label: label,
      value: value == null
          ? '-'
          : '${value.value} | variant=${value.variant ?? '-'} | error=${value.error?.name ?? '-'}',
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Key? valueKey;

  const _Row({required this.label, required this.value, this.valueKey});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value, key: valueKey)),
        ],
      ),
    );
  }
}
