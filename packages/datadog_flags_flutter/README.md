# Datadog Flags Flutter

Use OpenFeature to evaluate Datadog feature flags in Flutter applications.
`datadog_flags` supplies `DatadogProvider`. This package supplies
`DatadogRumHook` to associate successful evaluations with the active RUM view.

This integration requires Flutter 3.38.1 or later, which includes stable Dart 3.10.
It uses the published OpenFeature `0.0.1` dependency described in the
[core package](../datadog_flags/).
Use `datadog_flutter_plugin` 3.4.0 or later and earlier than 5.0.0, and
`datadog_flags` 1.2.0 or later and earlier than 2.0.0.

## OpenFeature with RUM

Initialize the Datadog Flutter SDK for RUM.
Then configure the OpenFeature provider and register the RUM hook:

```dart
import 'package:datadog_flags_flutter/datadog_flags_flutter.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter/widgets.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';

WidgetsFlutterBinding.ensureInitialized();
final configuration = DatadogConfiguration(
  service: 'my-flutter-app',
  clientToken: '<CLIENT_TOKEN>',
  env: 'production',
  site: DatadogSite.us1,
  version: '1.0.0',
  rumConfiguration: DatadogRumConfiguration(applicationId: '<RUM_APP_ID>'),
);
await DatadogSdk.instance.initialize(configuration, TrackingConsent.granted);
final api = OpenFeatureAPI.instance;
api.addHooks([DatadogRumHook()]);
await api.setEvaluationContextAndWait(EvaluationContext(targetingKey: 'user-123'));
try {
  await api.setProviderAndWait(
    DatadogProvider.fromConfiguration(
      DatadogFlagsConfiguration(
        datadogConfig: DatadogFlagsConfig(
          clientToken: configuration.clientToken,
          env: configuration.env,
          site: DatadogFlagsSite.us1,
          applicationId: configuration.rumConfiguration?.applicationId,
          service: configuration.service,
          version: configuration.versionTag,
        ),
      ),
    ),
  );
} on OpenFeatureException {
  // Evaluations return defaults until initial assignments become available.
}
final enabled = api.getClient().getBooleanValue('checkout.enabled', false);
```

The hook adds the variant from a successful evaluation to the active RUM view.
It runs in the OpenFeature `finally` stage and tags only the final result.
It skips errors and results without a variant.
Register it with `OpenFeatureAPI.addHooks`, and register it again after shutdown.
A hook registered on a client applies only to that client object.
Each `getClient()` call returns a new client.
The provider handles Datadog exposure and evaluation telemetry separately.

If you create your own `DatadogSdk` instance, pass it with
`DatadogRumHook(sdk: instance)`. If you do not use RUM, use the provider from
`datadog_flags` without this hook.

Flutter RUM requires the main isolate. For background evaluation, initialize a
separate pure-Dart OpenFeature provider in that isolate.

## Exposures in your own data store

This package exports `ExposureHook` from `datadog_flags`. Use it to record
exposures in your own data store, even when `trackExposures` is `false`. See
[Exposures in your own data store](https://pub.dev/packages/datadog_flags#exposures-in-your-own-data-store).

## Legacy API migration

`DatadogFlagsPluginConfiguration`, `DatadogFlagsPlugin`,
`DatadogFlutterFlagsClient`, and the `DatadogSdk.flags` extension are deprecated.
Removal is planned for the next major version. Existing users can continue to
use the plugin during migration.

Replace plugin registration with `DatadogProvider`. Replace
`sharedClient()` with `OpenFeatureAPI.instance.getClient()`. Replace client
initialization with `setEvaluationContextAndWait()`. Add `DatadogRumHook` to
preserve RUM association. Do not run both integrations for the same evaluations.
The provider does not read the Datadog SDK configuration. Pass `applicationId`,
`service`, and `version` as shown above to retain these fields in evaluation telemetry.

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

## Contributing

See the [contributing guide](../../CONTRIBUTING.md) and
[OpenFeature validation instructions](../datadog_flags/CONTRIBUTING.md#openfeature-validation).
Licensed under [Apache 2.0](LICENSE).
