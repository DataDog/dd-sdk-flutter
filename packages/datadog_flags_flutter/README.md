# Datadog Flags Flutter

Use OpenFeature to evaluate Datadog feature flags in Flutter applications.
`datadog_flags` supplies `DatadogOpenFeatureProvider`. This package supplies
`DatadogRumHook` to associate successful evaluations with the active RUM view.

This integration requires Flutter 3.38.1 or later, which includes stable Dart 3.10.
It uses the published OpenFeature `0.0.1` dependency described in the
[core package](../datadog_flags/).

## OpenFeature with RUM

Initialize the Datadog Flutter SDK for RUM. RUM controls distributed tracing.
Then configure the OpenFeature provider and add the RUM hook one time:

```dart
import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';

await DatadogSdk.instance.initialize(
  DatadogConfiguration(
    service: 'my-flutter-app',
    clientToken: '<CLIENT_TOKEN>',
    env: 'production',
    site: DatadogSite.us1,
    rumConfiguration: DatadogRumConfiguration(applicationId: '<RUM_APP_ID>'),
  ),
  TrackingConsent.granted,
);

final api = OpenFeatureAPI.instance;
final client = api.getClient();
client.addHooks([DatadogRumHook()]);
await api.setEvaluationContextAndWait(EvaluationContext(targetingKey: 'user-123'));
try {
  await api.setProviderAndWait(DatadogOpenFeatureProvider(
    configuration: DatadogFlagsConfiguration(
      datadogConfig: DatadogFlagsConfig(
        clientToken: '<CLIENT_TOKEN>',
        env: 'production',
        site: DatadogFlagsSite.us1,
      ),
    ),
  ));
} on OpenFeatureException {
  // Continue with cached assignments or defaults. Initial loading can still succeed later.
}
final enabled = client.getBooleanValue('checkout.enabled', false);
```

The hook adds the variant to the active RUM view, or the evaluated value if no
variant is available. It skips evaluations that return errors. The provider
handles Datadog exposure and evaluation telemetry separately. It does not
implement the OpenFeature tracking API.

If you create your own `DatadogSdk` instance, pass it with
`DatadogRumHook(sdk: instance)`. If you do not use RUM, use the provider from
`datadog_flags` without this hook.

Flutter RUM requires the main isolate. For background evaluation, initialize a
separate pure-Dart OpenFeature provider in that isolate.

## Legacy API migration

`DatadogFlagsPluginConfiguration`, `DatadogFlagsPlugin`,
`DatadogFlutterFlagsClient`, and the `DatadogSdk.flags` extension are deprecated.
Removal is planned for the next major version. Existing users can continue to
use the plugin during migration.

Replace plugin registration with `DatadogOpenFeatureProvider`. Replace
`sharedClient()` with `OpenFeatureAPI.instance.getClient()`. Replace client
initialization with `setEvaluationContextAndWait()`. Add `DatadogRumHook` to
preserve RUM association. Do not run both integrations for the same evaluations.

Legacy client shutdown is terminal. Obtain another client from `sharedClient()`
to restart. Shutdown does not wait indefinitely for plugin readiness. A delegate
that resolves after shutdown is released without initialization or subscription.

## Examples

- [`example`](example/) shows OpenFeature evaluation with the RUM hook.
- [`simple_example`](../../examples/simple_example/) includes refresh, typed
  values, and lifecycle events.

## Cached evaluation reasons

For successful evaluations, details report `CACHED` when the installed assignments
were restored from the configured store, including an in-memory store. After a
network response replaces those assignments, details report the response reason.

## First installed flags

This notification uses the native client API, which is deprecated in favour of OpenFeature. The OpenFeature examples above remain the recommended setup for normal evaluations.

Register after obtaining a shared client to receive the keys from its first
accepted cache or network configuration: logical keys for plain configurations,
including `[]` when empty, and `null` when logical keys are unavailable due to
obfuscation. Late registrations receive the same
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
you unregister it. See the [example app](example/lib/first_flags.dart) for registration,
evaluation and widget disposal. Configure its `.env` using `melos generate_env`
and set `DD_CLIENT_TOKEN`, `DD_ENV`, and optionally `DD_APPLICATION_ID` for RUM.
Run this entrypoint with `flutter run -t lib/first_flags.dart` from `example`.

## Contributing

See the [contributing guide](../../CONTRIBUTING.md) and
[OpenFeature validation instructions](../datadog_flags/OPENFEATURE_VALIDATION.md).
Licensed under [Apache 2.0](LICENSE).
