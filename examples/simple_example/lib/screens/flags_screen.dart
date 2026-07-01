// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flags/datadog_flags.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../flags/flags_example_config.dart';

class FlagsScreen extends StatefulWidget {
  final FlagsExampleConfig config;

  const FlagsScreen({super.key, required this.config});

  @override
  State<FlagsScreen> createState() => _FlagsScreenState();
}

class _FlagsScreenState extends State<FlagsScreen> {
  late final DatadogFlagsClient _client;
  String _status = 'idle';
  List<_EvaluatedFlag> _flags = [];

  @override
  void initState() {
    super.initState();
    _client = DatadogFlags.instance.sharedClient();
    unawaited(_refreshAssignments());
  }

  Future<void> _refreshAssignments() async {
    setState(() {
      _status = 'loading';
    });
    try {
      await _client.initialize(widget.config.evaluationContext);
      if (!mounted) {
        return;
      }
      _evaluateFlags();
      setState(() {
        _status = 'ready';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _evaluateFlags();
      setState(() {
        _status = 'using defaults: $error';
      });
    }
  }

  void _evaluateFlags() {
    final flags = <_EvaluatedFlag>[];
    for (final flag in widget.config.flags) {
      flags.add(
        _EvaluatedFlag(
          label: flag.label,
          key: flag.key,
          details: _detailsFor(flag),
        ),
      );
    }
    setState(() {
      _flags = flags;
    });
  }

  FlagDetails<dynamic> _detailsFor(FlagsExampleFlag flag) {
    return switch (flag.type) {
      FlagsExampleFlagType.boolean => _client.getBooleanDetails(
          key: flag.key,
          defaultValue: false,
        ),
      FlagsExampleFlagType.string => _client.getStringDetails(
          key: flag.key,
          defaultValue: 'Fallback title',
        ),
      FlagsExampleFlagType.integer => _client.getIntegerDetails(
          key: flag.key,
          defaultValue: 0,
        ),
      FlagsExampleFlagType.float => _client.getDoubleDetails(
          key: flag.key,
          defaultValue: 0,
        ),
      FlagsExampleFlagType.object => _client.getObjectDetails(
          key: flag.key,
          defaultValue: const {},
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final targetingKey =
        widget.config.evaluationContext.targetingKey ?? '(none)';
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoRow(label: 'Status', value: _status),
          _InfoRow(label: 'Targeting key', value: targetingKey),
          const SizedBox(height: 12),
          for (final flag in _flags)
            _FlagDetailsRow(
              label: flag.label,
              keyName: flag.key,
              details: flag.details,
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _refreshAssignments,
                  child: const Text('Refresh assignments'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _evaluateFlags,
                  child: const Text('Evaluate flags'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _FlagDetailsRow extends StatelessWidget {
  final String label;
  final String keyName;
  final FlagDetails<dynamic> details;

  const _FlagDetailsRow({
    required this.label,
    required this.keyName,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    final error = details.error?.name;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
                Text(_formatValue(details.value)),
                if (details.variant != null || details.reason != null)
                  Text(
                    [
                      if (details.variant != null) 'variant ${details.variant}',
                      if (details.reason != null) 'reason ${details.reason}',
                    ].join(' / '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (error != null)
                  Text(
                    error,
                    style: Theme.of(context).textTheme.bodySmall,
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
