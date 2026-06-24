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
  static const _initialModeName = String.fromEnvironment('FLAGS_MODE');

  late DatadogFlagsClient _client;
  Timer? _counterRefreshTimer;
  late FlagsDemoProviderMode _mode;
  String _assignmentState = 'idle';
  Duration? _lastAssignmentsRefreshDuration;
  late String _configuredEnv;
  late String _obfuscatedClientToken;
  int _recordedEvaluationCount = 0;
  int _refreshRequestId = 0;
  List<_EvaluatedFlag> _flags = [];

  @override
  void initState() {
    super.initState();
    _mode = _initialMode();
    _client = DatadogFlagsClient.shared();
    _configuredEnv = widget.runtime.configuredEnv;
    _obfuscatedClientToken = widget.runtime.obfuscatedClientToken;
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
    if (_mode == FlagsDemoProviderMode.ffeDogfooding) {
      _refreshFlags();
    } else {
      unawaited(_enableProviderAndRefresh(_mode));
    }
  }

  @override
  void dispose() {
    _counterRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshFlags() async {
    final requestId = ++_refreshRequestId;
    final mode = _modeDefinition(_mode);
    final stopwatch = Stopwatch()..start();
    setState(() {
      _assignmentState = 'fetching';
      _lastAssignmentsRefreshDuration = null;
    });
    try {
      await _client.setEvaluationContext(DatadogFlagsEvaluationContext(
        targetingKey: mode.targetingKey,
        attributes: mode.targetingAttributes,
      ));
      stopwatch.stop();
      if (!mounted || requestId != _refreshRequestId) {
        return;
      }
      _evaluate(mode);
      setState(() {
        _assignmentState = 'ready';
        _lastAssignmentsRefreshDuration = stopwatch.elapsed;
      });
    } catch (error) {
      stopwatch.stop();
      if (!mounted || requestId != _refreshRequestId) {
        return;
      }
      setState(() {
        _assignmentState = 'fetch failed: $error';
        _lastAssignmentsRefreshDuration = stopwatch.elapsed;
        _flags = [];
      });
    }
  }

  void _evaluate([_FlagModeDefinition? mode]) {
    final selectedMode = mode ?? _modeDefinition(_mode);
    final flags = <_EvaluatedFlag>[];
    for (final spec in selectedMode.flags) {
      flags.add(_EvaluatedFlag(
        label: spec.label,
        key: spec.key,
        details: _detailsForSpec(spec),
      ));
    }
    setState(() {
      _flags = flags;
      _recordedEvaluationCount += flags.length;
    });
  }

  FlagDetails<dynamic> _detailsForSpec(_FlagSpec spec) {
    return switch (spec.type) {
      _FlagValueType.boolean => _client.getBooleanDetails(
          key: spec.key,
          defaultValue: false,
        ),
      _FlagValueType.string => _client.getStringDetails(
          key: spec.key,
          defaultValue: 'Fallback title',
        ),
      _FlagValueType.integer => _client.getIntegerDetails(
          key: spec.key,
          defaultValue: 0,
        ),
      _FlagValueType.float => _client.getDoubleDetails(
          key: spec.key,
          defaultValue: 0,
        ),
      _FlagValueType.object => _client.getObjectDetails(
          key: spec.key,
          defaultValue: const {},
        ),
    };
  }

  Future<void> _selectMode(FlagsDemoProviderMode mode) async {
    if (_mode == mode) {
      return;
    }
    setState(() {
      _mode = mode;
    });
    await _enableProviderAndRefresh(mode);
  }

  Future<void> _enableProviderAndRefresh(FlagsDemoProviderMode mode) async {
    final requestId = ++_refreshRequestId;
    setState(() {
      _assignmentState = 'switching';
      _flags = [];
    });
    try {
      final diagnostics = await widget.runtime.enableProvider(mode);
      if (!mounted || requestId != _refreshRequestId) {
        return;
      }
      _client = DatadogFlagsClient.shared();
      setState(() {
        _configuredEnv = diagnostics.configuredEnv;
        _obfuscatedClientToken = diagnostics.obfuscatedClientToken;
      });
    } catch (error) {
      if (!mounted || requestId != _refreshRequestId) {
        return;
      }
      setState(() {
        _assignmentState = 'switch failed: $error';
      });
      return;
    }
    await _refreshFlags();
  }

  void _clearExposureCache() {
    _client.clearExposureCache();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exposure cache cleared')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final counter = widget.runtime.counter;
    final selectedMode = _modeDefinition(_mode);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flags'),
        actions: [
          IconButton(
            key: const Key('flags-clear-exposure-cache-button'),
            tooltip: 'Clear exposure cache',
            icon: const Icon(Icons.clear_all),
            onPressed: _clearExposureCache,
          ),
          IconButton(
            key: const Key('flags-home-button'),
            tooltip: 'Home',
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        children: [
          _ModeRow(
            selectedMode: _mode,
            onChanged: _selectMode,
          ),
          _Row(label: 'Assignments', value: _assignmentState),
          _Row(label: 'Targeting key', value: selectedMode.targetingKey),
          _Row(
            label: 'Evaluations',
            value: '$_recordedEvaluationCount',
            valueKey: const Key('flags-recorded-evaluation-count'),
          ),
          if (counter != null) ...[
            _Row(
              label: 'Exposures',
              value: '${counter.exposureCount}',
              valueKey: const Key('flags-exposure-count'),
            ),
          ],
          _DiagnosticsGrid(
            rows: _diagnosticRows(),
            gridKey: const Key('flags-diagnostics'),
          ),
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
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Refresh assignments',
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _evaluate,
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Evaluate flags',
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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

  FlagsDemoProviderMode _initialMode() {
    return switch (_initialModeName) {
      'perplexity' ||
      'perplexity-load-test' =>
        FlagsDemoProviderMode.perplexityLoadTest,
      _ => FlagsDemoProviderMode.ffeDogfooding,
    };
  }

  _FlagModeDefinition _modeDefinition(FlagsDemoProviderMode mode) {
    return switch (mode) {
      FlagsDemoProviderMode.ffeDogfooding => _FlagModeDefinition(
          label: 'FFE dogfooding',
          targetingKey: _targetingKey,
          targetingAttributes: _targetingAttributes(),
          flags: [
            ..._specs(
              configured: _booleanKeys,
              defaultKeys: const ['ffe-dogfooding-boolean-flag'],
              label: 'Boolean',
              type: _FlagValueType.boolean,
            ),
            ..._specs(
              configured: _stringKeys,
              defaultKeys: const ['ffe-dogfooding-string-flag'],
              label: 'String',
              type: _FlagValueType.string,
            ),
            ..._specs(
              configured: _integerKeys,
              defaultKeys: const ['ffe-dogfooding-integer-flag'],
              label: 'Integer',
              type: _FlagValueType.integer,
            ),
            ..._specs(
              configured: _doubleKeys,
              defaultKeys: const ['ffe-dogfooding-float-flag'],
              label: 'Float',
              type: _FlagValueType.float,
            ),
            ..._specs(
              configured: _objectKeys,
              defaultKeys: const ['ffe-dogfooding-json-flag'],
              label: 'JSON',
              type: _FlagValueType.object,
            ),
          ],
        ),
      FlagsDemoProviderMode.perplexityLoadTest => const _FlagModeDefinition(
          label: 'Perplexity load test',
          targetingKey: 'perplexity-load-test-subject',
          targetingAttributes: {
            'attr1': 'value1',
            'companyId': 'perplexity-load-test',
            'org': 'perplexity-load-test',
          },
          flags: [
            _FlagSpec(
              label: 'Boolean',
              key: '2025-nba-playoffs-bracket',
              type: _FlagValueType.boolean,
            ),
            _FlagSpec(
              label: 'String',
              key: 'thread-branching-enabled',
              type: _FlagValueType.string,
            ),
            _FlagSpec(
              label: 'JSON',
              key: 'windows-app-milestone-check-config',
              type: _FlagValueType.object,
            ),
            _FlagSpec(
              label: 'Integer',
              key: 'android-attachment-limit',
              type: _FlagValueType.integer,
            ),
            _FlagSpec(
              label: 'Integer',
              key: 'cf-challenge-reload',
              type: _FlagValueType.integer,
            ),
          ],
        ),
    };
  }

  List<_FlagSpec> _specs({
    required String configured,
    required List<String> defaultKeys,
    required String label,
    required _FlagValueType type,
  }) {
    return _keys(configured, defaultKeys).map((key) {
      return _FlagSpec(label: label, key: key, type: type);
    }).toList(growable: false);
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

  List<List<_DiagnosticMetric>> _diagnosticRows() {
    final counter = widget.runtime.counter;
    return [
      [
        _DiagnosticMetric(
          label: 'Refresh',
          value: _formatDuration(_lastAssignmentsRefreshDuration),
        ),
        _DiagnosticMetric(
          label: 'HTTP',
          value: _formatDuration(counter?.lastPrecomputeHttpDuration),
        ),
        _DiagnosticMetric(
          label: 'Parse JSON',
          value:
              _formatDuration(counter?.lastPrecomputeDeserializationDuration),
        ),
      ],
      [
        _DiagnosticMetric(
          label: 'Payload',
          value: _formatBytes(counter?.lastPrecomputePayloadBytes),
        ),
        _DiagnosticMetric(
          label: 'Flag keys',
          value: _formatNullableCount(counter?.lastPrecomputeFlagCount),
        ),
        _DiagnosticMetric(
          label: 'Env / token',
          value: '$_configuredEnv / $_obfuscatedClientToken',
        ),
      ],
    ];
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) {
      return '-';
    }
    final microseconds = duration.inMicroseconds;
    if (microseconds < 1000) {
      return '$microseconds us';
    }
    final milliseconds = microseconds / 1000;
    if (milliseconds < 1000) {
      return '${milliseconds.toStringAsFixed(1)} ms';
    }
    return '${(milliseconds / 1000).toStringAsFixed(2)} s';
  }

  String _formatNullableCount(int? value) {
    if (value == null) {
      return '-';
    }
    return '$value';
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) {
      return '-';
    }
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kibibytes = bytes / 1024;
    if (kibibytes < 1024) {
      return '${kibibytes.toStringAsFixed(1)} KB';
    }
    return '${(kibibytes / 1024).toStringAsFixed(1)} MB';
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

class _FlagModeDefinition {
  final String label;
  final String targetingKey;
  final Map<String, Object?> targetingAttributes;
  final List<_FlagSpec> flags;

  const _FlagModeDefinition({
    required this.label,
    required this.targetingKey,
    required this.targetingAttributes,
    required this.flags,
  });
}

class _FlagSpec {
  final String label;
  final String key;
  final _FlagValueType type;

  const _FlagSpec({
    required this.label,
    required this.key,
    required this.type,
  });
}

enum _FlagValueType { boolean, string, integer, float, object }

class _ModeRow extends StatelessWidget {
  final FlagsDemoProviderMode selectedMode;
  final ValueChanged<FlagsDemoProviderMode> onChanged;

  const _ModeRow({
    required this.selectedMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 112,
            child: Text(
              'Org',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<FlagsDemoProviderMode>(
                key: const Key('flags-mode-selector'),
                value: selectedMode,
                isExpanded: true,
                items: FlagsDemoProviderMode.values.map((mode) {
                  return DropdownMenuItem(
                    value: mode,
                    child: Text(_modeLabel(mode)),
                  );
                }).toList(growable: false),
                onChanged: (mode) {
                  if (mode != null) {
                    onChanged(mode);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _modeLabel(FlagsDemoProviderMode mode) {
    return switch (mode) {
      FlagsDemoProviderMode.ffeDogfooding => 'FFE dogfooding',
      FlagsDemoProviderMode.perplexityLoadTest => 'Perplexity load test',
    };
  }
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
    final formattedValue = value == null ? '-' : _formatValue(value.value);
    final error = value?.error?.name;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
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
                  error == null ? formattedValue : '$formattedValue · $error',
                  softWrap: true,
                ),
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
            width: 112,
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

class _DiagnosticMetric {
  final String label;
  final String value;

  const _DiagnosticMetric({required this.label, required this.value});
}

class _DiagnosticsGrid extends StatelessWidget {
  final List<List<_DiagnosticMetric>> rows;
  final Key? gridKey;

  const _DiagnosticsGrid({required this.rows, this.gridKey});

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
          height: 1,
        );
    final valueStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.1,
        );
    return Padding(
      key: gridKey,
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  for (final item in row)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.label,
                            style: labelStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                item.value,
                                style: valueStyle,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
