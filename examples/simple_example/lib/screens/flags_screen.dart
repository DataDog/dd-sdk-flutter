// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../flags/flags_demo_runtime.dart';

class FlagsScreen extends StatefulWidget {
  final FlagsDemoRuntime runtime;

  const FlagsScreen({super.key, required this.runtime});

  @override
  State<FlagsScreen> createState() => _FlagsScreenState();
}

class _FlagsScreenState extends State<FlagsScreen> {
  static const _targetingKey = String.fromEnvironment('FLAGS_TARGETING_KEY',
      defaultValue: 'test_subject4');
  static const _targetingAttributesJson = String.fromEnvironment(
    'FLAGS_TARGETING_ATTRIBUTES_JSON',
    defaultValue: '{"attr1":"value1","companyId":"1"}',
  );
  static const _booleanKeys = String.fromEnvironment('FLAGS_BOOLEAN_KEYS');
  static const _stringKeys = String.fromEnvironment('FLAGS_STRING_KEYS');
  static const _integerKeys = String.fromEnvironment('FLAGS_INTEGER_KEYS');
  static const _doubleKeys = String.fromEnvironment('FLAGS_DOUBLE_KEYS');
  static const _objectKeys = String.fromEnvironment('FLAGS_OBJECT_KEYS');
  static const _exposureProbeKey = String.fromEnvironment(
    'FLAGS_EXPOSURE_PROBE_KEY',
    defaultValue: 'android-mobile-app-aa-test',
  );

  late final DatadogFlagsClient _client;
  Timer? _counterRefreshTimer;
  String _assignmentState = 'idle';
  int _recordedEvaluationCount = 0;
  List<_EvaluatedFlag> _flags = [];

  @override
  void initState() {
    super.initState();
    _client = DatadogFlagsClient.shared();
    if (widget.runtime.counter != null) {
      _counterRefreshTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) {
          if (mounted) {
            setState(() {});
          }
        },
      );
    }
    _refreshFlags();
  }

  @override
  void dispose() {
    _counterRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshFlags() async {
    setState(() {
      _assignmentState = 'fetching';
    });
    try {
      await _client.setEvaluationContext(DatadogFlagsEvaluationContext(
        targetingKey: _targetingKey,
        attributes: _targetingAttributes(),
      ));
      _evaluate();
      setState(() {
        _assignmentState = 'ready';
      });
    } catch (error) {
      setState(() {
        _assignmentState = 'fetch failed: $error';
        _flags = [];
      });
    }
  }

  void _evaluate() {
    final flags = <_EvaluatedFlag>[];
    for (final key
        in _keys(_booleanKeys, const ['ffe-dogfooding-boolean-flag'])) {
      flags.add(_EvaluatedFlag(
        label: 'Boolean',
        key: key,
        details: _client.getBooleanDetails(
          key: key,
          defaultValue: false,
        ),
      ));
    }
    for (final key
        in _keys(_stringKeys, const ['ffe-dogfooding-string-flag'])) {
      flags.add(_EvaluatedFlag(
        label: 'String',
        key: key,
        details: _client.getStringDetails(
          key: key,
          defaultValue: 'Fallback title',
        ),
      ));
    }
    for (final key
        in _keys(_integerKeys, const ['ffe-dogfooding-integer-flag'])) {
      flags.add(_EvaluatedFlag(
        label: 'Integer',
        key: key,
        details: _client.getIntegerDetails(
          key: key,
          defaultValue: 0,
        ),
      ));
    }
    for (final key in _keys(_doubleKeys, const ['ffe-dogfooding-float-flag'])) {
      flags.add(_EvaluatedFlag(
        label: 'Float',
        key: key,
        details: _client.getDoubleDetails(
          key: key,
          defaultValue: 0,
        ),
      ));
    }
    for (final key in _keys(_objectKeys, const ['ffe-dogfooding-json-flag'])) {
      flags.add(_EvaluatedFlag(
        label: 'JSON',
        key: key,
        details: _client.getObjectDetails(
          key: key,
          defaultValue: const {},
        ),
      ));
    }
    var evaluationCount = flags.length;
    final exposureProbeKey = _exposureProbeKey.trim();
    if (exposureProbeKey.isNotEmpty &&
        !flags.any((flag) => flag.key == exposureProbeKey)) {
      _client.getStringDetails(
        key: exposureProbeKey,
        defaultValue: '',
      );
      evaluationCount += 1;
    }
    setState(() {
      _flags = flags;
      _recordedEvaluationCount += evaluationCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final counter = widget.runtime.counter;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flags'),
        actions: [
          IconButton(
            key: const Key('flags-home-button'),
            tooltip: 'Home',
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 14),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          children: [
            _Row(label: 'Assignments', value: _assignmentState),
            const _Row(label: 'Targeting key', value: _targetingKey),
            _Row(
              label: 'Eval calls',
              value: '$_recordedEvaluationCount',
              valueKey: const Key('flags-recorded-evaluation-count'),
            ),
            if (counter != null) ...[
              _Row(
                label: 'Exposures',
                value: '${counter.exposureCount}',
                valueKey: const Key('flags-exposure-count'),
              ),
              _Row(
                label: 'Flag eval events',
                value: '${counter.evaluationEventCount}',
                valueKey: const Key('flags-evaluation-event-count'),
              ),
            ],
            const SizedBox(height: 8),
            for (final flag in _flags)
              _DetailsRow(
                label: flag.label,
                keyName: flag.key,
                details: flag.details,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _refreshFlags,
                    child: const Text('Refresh'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _evaluate,
                    child: const Text('Evaluate'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<String> _keys(String configured, List<String> defaultKeys) {
    if (configured.trim().isNotEmpty) {
      return configured
          .split(',')
          .map((key) => key.trim())
          .where((key) => key.isNotEmpty)
          .toList(growable: false);
    }
    return defaultKeys;
  }

  static Map<String, Object?> _targetingAttributes() {
    try {
      final decoded = jsonDecode(_targetingAttributesJson);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, Object?>.from(decoded);
      }
    } catch (_) {
      return const {};
    }
    return const {};
  }
}

class _EvaluatedFlag {
  final String label;
  final String key;
  final FlagDetails<dynamic> details;

  const _EvaluatedFlag({
    required this.label,
    required this.key,
    required this.details,
  });
}

class _DetailsRow extends StatelessWidget {
  final String label;
  final String keyName;
  final FlagDetails<dynamic>? details;

  const _DetailsRow({
    required this.label,
    required this.keyName,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    final value = details;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  keyName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value == null ? '-' : _formatValue(value.value),
                  softWrap: true,
                ),
                if (value?.error != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    'error=${value?.error?.name}',
                    style: Theme.of(context).textTheme.bodySmall,
                    softWrap: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(Object? value) {
    if (value is Map || value is List) {
      return jsonEncode(value);
    }
    return '$value';
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
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
