# Datadog Flags Flutter

`datadog_flags_flutter` integrates the standalone
[`datadog_flags`](https://pub.dev/packages/datadog_flags) Dart package with
[`datadog_flutter_plugin`](https://pub.dev/packages/datadog_flutter_plugin).

Use this package when your Flutter app already initializes the Datadog Flutter
SDK and you want feature flags to reuse that configuration.

## Getting Started

Add the package:

```bash
flutter pub add datadog_flags_flutter
```

This package requires Dart 3.6 or later and Flutter 3.27 or later. It depends
on `datadog_flutter_plugin` 3.4.0 or later.

Register the plugin before initializing the Datadog Flutter SDK:

```dart
import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';

final configuration = DatadogConfiguration(
  clientToken: '<CLIENT_TOKEN>',
  env: '<ENV_NAME>',
  site: DatadogSite.us1,
  rumConfiguration: DatadogRumConfiguration(
    applicationId: '<RUM_APPLICATION_ID>',
  ),
)..addPlugin(const DatadogFlagsPluginConfiguration());

await DatadogSdk.instance.initialize(configuration, TrackingConsent.granted);
```

Evaluate flags with the same typed API as `datadog_flags`:

```dart
final flags = DatadogSdk.instance.flags;
final client = flags?.sharedClient();

try {
  await client?.initialize(
    const FlagsEvaluationContext(targetingKey: 'user-123'),
  );
} on FlagsInitializationTimeoutException {
  // Continue startup with stored assignments or evaluation defaults.
}

final details = client?.getBooleanDetails(
  key: 'checkout.enabled',
  defaultValue: false,
);
```

Successful evaluations emit feature flag telemetry through `datadog_flags`.
When RUM is enabled, successful evaluations are also added to the active RUM
view with `DatadogRum.addFeatureFlagEvaluation`.

To evaluate flags without adding successful evaluations to the active RUM view,
disable RUM integration when registering the plugin:

```dart
final configuration = DatadogConfiguration(
  clientToken: '<CLIENT_TOKEN>',
  env: '<ENV_NAME>',
  site: DatadogSite.us1,
)..addPlugin(
    const DatadogFlagsPluginConfiguration(
      rumIntegrationEnabled: false,
    ),
  );
```

## Custom Flags Configuration

By default, `datadog_flags_flutter` derives the client token, environment, site,
application ID, service, and version from `DatadogConfiguration`. Pass a
`DatadogFlagsConfiguration` to override the standalone Flags SDK configuration:

```dart
DatadogFlagsPluginConfiguration(
  flagsConfiguration: DatadogFlagsConfiguration(
    initializationTimeout: const Duration(seconds: 5),
    datadogConfig: DatadogFlagsConfig(
      clientToken: '<CLIENT_TOKEN>',
      env: '<ENV_NAME>',
      site: DatadogFlagsSite.us1,
    ),
  ),
);
```

The Flutter integration preserves the core `datadog_flags` initialization
timeout. Set it to the wall-clock budget for the first context. The budget
covers stored assignment loading, network work, JSON decoding, state
publication, and assignment storage. Synchronous work can block the Dart
isolate, so the wait can be longer than this value. The SDK does not limit how
large this value can be. The timeout completes `initialize()` with
`FlagsInitializationTimeoutException`. The assignment operation continues in
the background, and matching stored assignments remain available.

Use `package:datadog_flags/datadog_flags.dart` directly for pure Dart apps or
Flutter apps that need full lifecycle control without Datadog Flutter SDK
integration.

## Cached Evaluation Reasons

For successful evaluations, details report `CACHED` when the installed assignments were restored from the configured store, including an in-memory store. After a network response replaces those assignments, details report the response reason.

## Background Isolates

`datadog_flags_flutter` does not support evaluation from background
isolates. If your app needs to evaluate flags from a background isolate, create
and initialize a standalone `datadog_flags` client in that isolate.

## Contributing

Pull requests are welcome. For more information, read the
[contributing guide](../../CONTRIBUTING.md) in the root repository.

## License

[Apache License, v2.0](LICENSE)

## First installed flags

Register after obtaining a shared client to receive the keys from its first
accepted cache or network configuration. Late registrations receive the same
event, and callbacks run in a later microtask. Evaluating through this client
preserves RUM feature flag tracking.

```dart
final client = DatadogSdk.instance.flags!.sharedClient();
final unregister = client.onFirstFlags((event) {
  debugPrint('First installed flags: ${event.flagsChanged}');
});
// Call unregister() in dispose when the notification is no longer needed.
```

If no usable configuration is installed, the callback remains pending until
you unregister it. See the [example app](example/lib/main.dart) for registration,
evaluation and widget disposal. Configure its `.env` using `melos generate_env`
and set `DD_CLIENT_TOKEN`, `DD_ENV`, and optionally `DD_APPLICATION_ID` for RUM.
