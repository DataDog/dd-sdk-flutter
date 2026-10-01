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

## Background Isolates

`datadog_flags_flutter` does not support evaluation from background
isolates. If your app needs to evaluate flags from a background isolate, create
and initialize a standalone `datadog_flags` client in that isolate.

## Contributing

Pull requests are welcome. For more information, read the
[contributing guide](../../CONTRIBUTING.md) in the root repository.

## License

[Apache License, v2.0](LICENSE)

## Observe the first installed flags

Register `onFirstFlags` before initialization to use assignments as soon as the
first matching cache or network configuration is installed. This is independent
of the initialization Future and is not a READY event.

```dart
final configuration = DatadogConfiguration(
  clientToken: '<CLIENT_TOKEN>', env: 'production', site: DatadogSite.us1,
)..addPlugin(DatadogFlagsPluginConfiguration(
  flagsConfiguration: DatadogFlagsConfiguration(
    onFirstFlags: (client, event) {
      // This is the public Flutter client; evaluations retain RUM integration.
      // Use client directly, without relying on a variable assigned after init.
    },
  ),
));
await DatadogSdk.instance.initialize(configuration, TrackingConsent.granted);
final client = DatadogSdk.instance.flags!.sharedClient();
await client.initialize(const FlagsEvaluationContext(targetingKey: 'user-123'));
```

The default client is created eagerly during SDK setup, so its callback must be
supplied in `DatadogFlagsConfiguration`. The configuration callback is captured
independently for each client. `sharedClient(name: 'other', onFirstFlags: ...)`
replaces that callback only when creating a new named client. Looking up an
existing client ignores the supplied callback; it does not register or replay it.

Delivery runs in a microtask on the client's Dart isolate, after accepted
installation and without waiting for persistence or network completion. It occurs
at most once per client instance lifetime. Reset and context changes do not rearm
it; a newly constructed client has a new hook. Shutdown suppresses delivery that
has not started; an already running callback may finish. Callback failures,
including errors from a returned Future, do not affect SDK initialization.

The immutable `FlagsClientEvent` has type `configurationChanged`, provider name
`Datadog`, and a detached complete key list in `flagsChanged`. An accepted empty
configuration supplies `[]`. Missing, invalid, mismatched, superseded, or timed-out
cache reads do not count as installations. Metadata is empty, and message and
error code are absent. No source indicator or readiness transition is implied.
Keys describe the first installation; the live client may contain newer values
when read. Collecting the keys performs no evaluations or telemetry; application
evaluations retain normal exposure, evaluation, and RUM behavior.
