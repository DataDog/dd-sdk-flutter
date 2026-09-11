# Datadog OpenFeature Provider

`datadog_openfeature_provider` connects the vendor-neutral OpenFeature Dart
client API to the pure-Dart `datadog_flags` runtime. It performs assignment
fetching and cached local evaluation without introducing a Flutter dependency.

> **Development status:** this package uses the official
> `openfeature_dart_client_sdk` `0.0.1-beta.1` release. The local dependency
> override uses the repository version of `datadog_flags` during development.

## Choose an integration

| Application | Evaluation API | Use |
| --- | --- | --- |
| Dart | OpenFeature | `openfeature_dart_client_sdk` and `datadog_openfeature_provider` |
| Flutter | OpenFeature | The same Dart OpenFeature packages |
| Flutter with Datadog Flutter SDK integration | Datadog | `datadog_flags_flutter` instead of this provider |

Flutter runs Dart, so Flutter applications can use this provider directly. The
provider is independent from `datadog_flags_flutter`. It requires explicit
Datadog Flags configuration and does not add evaluations to the active Flutter
RUM view.

Do not use both integrations for the same flag evaluations. Each integration
owns a separate Flags runtime and sends its own assignment requests and
telemetry.

## Architecture

The OpenFeature client calls this provider. The provider creates an isolated
`datadog_flags` runtime. The Flutter plugin is not part of this path.

The Flutter-native path uses `datadog_flags_flutter`. That plugin configures the
shared `datadog_flags` runtime from the Datadog Flutter SDK and adds successful
evaluations to the active RUM view.

Both integrations use the same core initialization deadline. The deadline
covers stored assignment loading, request encoding, the network response and
body, JSON decoding, assignment storage, and state publication.

## Installation

For Dart applications, add the OpenFeature client, the provider, and the
configuration types that the application imports:

```bash
dart pub add openfeature_dart_client_sdk datadog_openfeature_provider datadog_flags
```

For Flutter applications that use the OpenFeature API, add the same packages:

```bash
flutter pub add openfeature_dart_client_sdk datadog_openfeature_provider datadog_flags
```

## Usage with Dart or Flutter

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

In a Flutter application, initialize the Datadog Flutter SDK separately when
the application also uses RUM, Logs, or Traces. Pass the required Flags values
to `DatadogFlagsConfiguration` as shown above. The provider does not read
`DatadogSdk.instance` configuration.

## Lifecycle mapping

| Datadog state | OpenFeature event/status |
| --- | --- |
| Live assignments loaded | `ready` or `contextChanged` / ready |
| Matching stored assignments and refresh failed | terminal ready event followed by `stale` |
| No usable assignments | `error` |
| Context load in progress | `reconciling` |

If the first initialization reaches the Datadog deadline, the provider reports
`error` and returns customer defaults. The assignment operation continues. A
late successful response activates the runtime and emits `ready`.

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

Normal flag evaluation generates Datadog exposure and aggregated evaluation
telemetry. The provider intentionally does not implement
OpenFeature's arbitrary tracking API because that is not equivalent to Datadog
feature-flag evaluation telemetry.
