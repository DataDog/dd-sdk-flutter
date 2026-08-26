# Datadog OpenFeature Provider

`datadog_openfeature_provider` connects the vendor-neutral OpenFeature Dart
client API to the pure-Dart `datadog_flags` runtime. It performs assignment
fetching and cached local evaluation without introducing a Flutter dependency.

> **Development status:** the OpenFeature Dart client package is not yet on
> pub.dev. This repository pins the reviewed upstream beta contract for CI.
> Remove `pubspec_overrides.yaml` after `openfeature_dart_client_sdk`
> `0.0.1-beta.1` is published and before publishing this package.

## Usage

```dart
import 'package:datadog_flags/datadog_flags.dart';
import 'package:datadog_openfeature_provider/datadog_openfeature_provider.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';

Future<void> main() async {
  final api = OpenFeatureAPI.instance;
  await api.setEvaluationContextAndWait(
    EvaluationContext(
      targetingKey: 'user-123',
      attributes: const {'plan': 'pro'},
    ),
  );

  await api.setProviderAndWait(
    DatadogOpenFeatureProvider(
      configuration: DatadogFlagsConfiguration(
        datadogConfig: const DatadogFlagsConfig(
          clientToken: 'pub...',
          env: 'production',
          site: DatadogFlagsSite.us1,
          applicationId: 'rum-application-id',
          service: 'shopping-app',
          version: '1.2.3',
        ),
      ),
    ),
  );

  final client = api.getClient();
  final enabled = client.getBooleanValue('checkout.enabled', false);
  print(enabled);

  await api.shutdown();
}
```

Applications evaluate flags through OpenFeature. The provider delegates
assignment retrieval, synchronous typed evaluation, exposure telemetry, and
aggregated evaluation telemetry to `datadog_flags`.

## Lifecycle mapping

| Datadog state | OpenFeature event/status |
| --- | --- |
| Live assignments loaded | `ready` or `contextChanged` / ready |
| Matching stored assignments and refresh failed | terminal ready event followed by `stale` |
| No usable assignments | `error` |
| Context load in progress | `reconciling` |

Context changes use a candidate Datadog runtime. The provider keeps evaluating
against the previous runtime until assignments for the requested identity are
usable, then swaps runtimes atomically. Failed reconciliation does not expose
assignments from another targeting identity.

## Evaluation and telemetry

OpenFeature error codes map directly from Datadog readiness, flag-not-found,
and type-mismatch results. Successful details include the Datadog variant and
reason, plus these provider metadata fields:

* `datadog.allocation_key`
* `datadog.serial_id`, when supplied by the assignment

Normal flag evaluation continues to generate Datadog exposure and aggregated
evaluation telemetry. The provider intentionally does not implement
OpenFeature's arbitrary tracking API because that is not equivalent to Datadog
feature-flag evaluation telemetry.

Flutter applications can use this pure-Dart provider directly. This initial
package does not bridge successful evaluations into a Flutter RUM view; that
requires a separate optional adapter over `datadog_flags_flutter` so the core
provider remains Flutter-independent.
