// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';

import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';

import 'flags_example_configuration.dart';

String get _clientToken => dotenv.env['DD_CLIENT_TOKEN'] ?? '';
String get _applicationId => dotenv.env['DD_APPLICATION_ID'] ?? '';
String get _env => dotenv.env['DD_ENV'] ?? 'dev';
String get _site => dotenv.env['DD_SITE'] ?? 'us1';
String get _targetingKey => dotenv.env['FLAGS_TARGETING_KEY'] ?? 'example-user';
String get _flagKey =>
    (dotenv.env['FLAGS_BOOLEAN_KEYS'] ?? 'checkout.enabled').split(',').first;

const _service = 'com.datadoghq.flags.example';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  final isConfigured = _clientToken.isNotEmpty;
  final flagsConfiguration = flagsExampleConfiguration(
    service: _service,
    site: _datadogSiteFor(_site),
    clientToken: _clientToken,
    env: _env,
    applicationId: _applicationId.isEmpty ? null : _applicationId,
  );
  if (isConfigured) {
    final configuration = DatadogConfiguration(
      service: _service,
      clientToken: _clientToken,
      env: _env,
      site: _datadogSiteFor(_site),
      rumConfiguration: _applicationId.isEmpty
          ? null
          : DatadogRumConfiguration(applicationId: _applicationId),
    );

    await DatadogSdk.instance.initialize(
      configuration,
      TrackingConsent.granted,
    );
  }

  final api = OpenFeatureAPI.instance;
  api.addHooks([DatadogRumHook()]);
  await api.setEvaluationContextAndWait(
    EvaluationContext(targetingKey: _targetingKey),
  );
  if (flagsConfiguration != null) {
    try {
      await api.setProviderAndWait(
        DatadogProvider.fromConfiguration(
          DatadogFlagsConfiguration(datadogConfig: flagsConfiguration),
        ),
      );
    } on OpenFeatureException {
      // The app can use defaults and recover when initial assignments arrive.
    }
  }
  runApp(
    FlagsExampleApp(
      isConfigured: flagsConfiguration != null,
      configurationError: isConfigured && flagsConfiguration == null
          ? 'Feature Flags is not supported for site $_site.'
          : null,
    ),
  );
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
  final String? configurationError;

  const FlagsExampleApp({
    super.key,
    required this.isConfigured,
    this.configurationError,
  });

  @override
  State<FlagsExampleApp> createState() => _FlagsExampleAppState();
}

class _FlagsExampleAppState extends State<FlagsExampleApp> {
  String _status = 'idle';
  FlagEvaluationDetails<bool>? _details;

  @override
  void initState() {
    super.initState();
    unawaited(_evaluate());
  }

  Future<void> _evaluate() async {
    if (!widget.isConfigured) {
      setState(() {
        _status =
            widget.configurationError ??
            'Set DD_CLIENT_TOKEN in .env to evaluate flags.';
      });
      return;
    }

    final client = OpenFeatureAPI.instance.getClient();
    final status = client.providerStatus.name;
    final details = client.getBooleanDetails(_flagKey, false);
    setState(() {
      _details = details;
      _status = status;
    });
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
            _InfoRow(label: 'Variant', value: details?.variant ?? '(none)'),
            _InfoRow(
              label: 'Error',
              value: details?.errorCode?.name ?? '(none)',
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

  const _InfoRow({required this.label, required this.value});

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
