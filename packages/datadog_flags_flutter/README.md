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

Successful evaluation details report `CACHED` when the installed assignments
were restored from the configured store, including an in-memory store. Once a
network response replaces them, details report the response reason.

## First installed flags

Call `client.onFirstFlags((event) { ... })` after obtaining a shared client. It
returns an ordinary unregister function; there is no subscription object. The
callback receives only `FlagsClientEvent` and always runs in a microtask,
including when the first event is already retained. The wrapper resolves its
existing core delegate before forwarding registration, without initializing a
context or starting an assignment fetch. Callback evaluations use the existing
RUM-integrated wrapper and current assignments.

Unregister immediately releases the app callback and prevents delivery not yet
started, even while the delegate is resolving or a callback microtask is queued.
After forwarding, unregister invokes the core cancellation function. Each
registration forwards once to its resolved core; resolver failure does not
fabricate success or retry. Reacquire `sharedClient` after SDK re-enable; old
wrappers have no new lifecycle guarantee and registrations do not migrate.

The [actual example app](example/lib/main.dart) registers once in `initState`,
logs `event.flagsChanged`, evaluates its existing `DD_FLAG_KEY`, displays the
first result, and unregisters in `dispose`. Its initialization/context flow
remains explicit. Run fixture app tests from `example` with
`flutter test --dart-define=DD_CLIENT_TOKEN=test-token`. They use fixture HTTP
and the SDK's no-op native platform, not a live service or device.

Run the VM-only capture-release proof with
`flutter test --enable-vmservice test_vm/first_flags_capture_test.dart`.

### Coordinated release requirement

Adding the method breaks external `implements DatadogFlagsClient` classes and
fakes. The repository releaser assigns an explicit release version; this change
does not select one. Before publishing the integration, publish the coordinated
core containing this API and update its minimum dependency accordingly. The
current `^1.1.0` constraint alone does not ensure this method exists. Local path
overrides validate the companion source only and are not registry compatibility
proof. No package publication is part of this change.
