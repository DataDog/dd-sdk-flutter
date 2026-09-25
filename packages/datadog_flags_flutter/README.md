# Datadog Flags Flutter

Use OpenFeature to evaluate Datadog feature flags in Flutter applications.
`datadog_flags` supplies `DatadogOpenFeatureProvider`. This package supplies
`DatadogRumHook` to associate successful evaluations with the active RUM view.

The development integration requires Dart 3.10 and Flutter 3.38 or later.
It uses the pinned OpenFeature development dependency described in the
[core package](../datadog_flags/). Publication is blocked until a compatible
hosted OpenFeature release is validated.

## OpenFeature with RUM

Initialize the Datadog Flutter SDK for RUM, Logs, and Traces. Then configure the
OpenFeature provider and add the RUM hook once:

```dart
import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';

await DatadogSdk.instance.initialize(
  DatadogConfiguration(
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
  // Use cached assignments or defaults while initial loading can recover.
}
final enabled = client.getBooleanValue('checkout.enabled', false);
```

The hook records the variant when available, otherwise the evaluated value.
It skips evaluation errors. The provider handles Datadog exposure and evaluation
telemetry separately. It does not implement the OpenFeature tracking API.

Use `DatadogRumHook(sdk: instance)` when the application supplies a Datadog SDK
instance. Without RUM, use the core provider without this hook.

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
  values, lifecycle events, and Android/iOS integration tests.

Flutter RUM requires the main isolate. For background evaluation, initialize a
separate pure-Dart OpenFeature provider in that isolate.

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md). Licensed under [Apache 2.0](LICENSE).
