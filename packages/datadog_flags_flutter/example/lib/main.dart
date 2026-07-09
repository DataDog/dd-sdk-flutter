// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';

import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';

const _clientToken = String.fromEnvironment('DD_CLIENT_TOKEN');
const _applicationId = String.fromEnvironment('DD_APPLICATION_ID');
const _env = String.fromEnvironment('DD_ENV', defaultValue: 'dev');
const _site = String.fromEnvironment('DD_SITE', defaultValue: 'us1');
const _targetingKey = String.fromEnvironment(
  'DD_TARGETING_KEY',
  defaultValue: 'example-user',
);
const _flagKey = String.fromEnvironment(
  'DD_FLAG_KEY',
  defaultValue: 'checkout.enabled',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isConfigured = _clientToken.isNotEmpty;
  if (isConfigured) {
    final configuration = DatadogConfiguration(
      clientToken: _clientToken,
      env: _env,
      site: _datadogSiteFor(_site),
      rumConfiguration: _applicationId.isEmpty
          ? null
          : DatadogRumConfiguration(applicationId: _applicationId),
    )..addPlugin(const DatadogFlagsPluginConfiguration());

    await DatadogSdk.instance.initialize(
      configuration,
      TrackingConsent.granted,
    );
  }

  runApp(FlagsExampleApp(isConfigured: isConfigured));
}

DatadogSite _datadogSiteFor(String site) {
  return switch (site) {
    'us3' => DatadogSite.us3,
    'us5' => DatadogSite.us5,
    'eu1' => DatadogSite.eu1,
    'ap1' => DatadogSite.ap1,
    'ap2' => DatadogSite.ap2,
    'us1_fed' => DatadogSite.us1Fed,
    _ => DatadogSite.us1,
  };
}

class FlagsExampleApp extends StatefulWidget {
  final bool isConfigured;

  const FlagsExampleApp({
    super.key,
    required this.isConfigured,
  });

  @override
  State<FlagsExampleApp> createState() => _FlagsExampleAppState();
}

class _FlagsExampleAppState extends State<FlagsExampleApp> {
  String _status = 'idle';
  FlagDetails<bool>? _details;

  @override
  void initState() {
    super.initState();
    unawaited(_evaluate());
  }

  Future<void> _evaluate() async {
    if (!widget.isConfigured) {
      setState(() {
        _status = 'Set DD_CLIENT_TOKEN with --dart-define to evaluate flags.';
      });
      return;
    }

    final client = DatadogSdk.instance.flags?.sharedClient();
    if (client == null) {
      setState(() {
        _status = 'Flags plugin is not configured.';
      });
      return;
    }

    setState(() {
      _status = 'loading';
    });

    try {
      await client.initialize(
        const FlagsEvaluationContext(targetingKey: _targetingKey),
      );
      final details = client.getBooleanDetails(
        key: _flagKey,
        defaultValue: false,
      );
      setState(() {
        _details = details;
        _status = 'ready';
      });
    } catch (error) {
      setState(() {
        _details = null;
        _status = 'using defaults: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Datadog Flags')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _InfoRow(label: 'Status', value: _status),
            _InfoRow(label: 'Environment', value: _env),
            _InfoRow(label: 'Site', value: _site),
            _InfoRow(label: 'Targeting key', value: _targetingKey),
            const Divider(height: 32),
            _InfoRow(label: 'Flag key', value: _flagKey),
            _InfoRow(
              label: 'Value',
              value: details == null ? '(none)' : details.value.toString(),
            ),
            _InfoRow(
              label: 'Variant',
              value: details?.variant ?? '(none)',
            ),
            _InfoRow(
              label: 'Error',
              value: details?.error?.name ?? '(none)',
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _evaluate,
              child: const Text('Evaluate flag'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
