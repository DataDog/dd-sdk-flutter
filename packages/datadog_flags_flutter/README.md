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
  service: '<SERVICE_NAME>',
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

await client?.initialize(
  const FlagsEvaluationContext(targetingKey: 'user-123'),
);

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
  service: '<SERVICE_NAME>',
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
    datadogConfig: DatadogFlagsConfig(
      clientToken: '<CLIENT_TOKEN>',
      env: '<ENV_NAME>',
      site: DatadogFlagsSite.us1,
    ),
  ),
);
```

Use `package:datadog_flags/datadog_flags.dart` directly for pure Dart apps or
Flutter apps that need full lifecycle control without Datadog Flutter SDK
integration.

## Background Isolates

`datadog_flags_flutter` does not support evaluation from background
isolates. If your app needs to evaluate flags from a background isolate, create
and initialize a standalone `datadog_flags` client in that isolate.

## Contributing

Pull requests are welcome. For more information, read the
[contributing guide](../../CONTRIBUTING.md) in the root repository.

## License

[Apache License, v2.0](LICENSE)
