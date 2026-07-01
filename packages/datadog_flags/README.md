# Datadog Flags

`datadog_flags` is the native Dart SDK for Datadog Feature Flags and
Experimentation in client applications. It fetches precomputed assignments from
Datadog, evaluates typed flag values locally, and reports exposure and flag
evaluation events back to Datadog.

This package is Dart-only. It does not bridge to the Datadog iOS or Android
flagging SDKs, and it does not require a Flutter dependency. Flutter
applications can use it directly from Dart code.

The API follows the same client-side concepts used by OpenFeature providers:
configure the provider, initialize a client for an evaluation context, evaluate
typed details with a programmatic default, and shut the client down when the app
no longer needs it.

## Installation

For Dart:

```bash
dart pub add datadog_flags
```

For Flutter:

```bash
flutter pub add datadog_flags
```

Then import the public API:

```dart
import 'package:datadog_flags/datadog_flags.dart';
```

## Quick Start

Enable Datadog Flags, initialize a client with an evaluation context, and
evaluate typed details from the current assignment state:

```dart
final datadogFlags = DatadogFlags.instance;

await datadogFlags.enable(
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
);

final flags = datadogFlags.sharedClient();
await flags.initialize(
  const FlagsEvaluationContext(
    targetingKey: 'user-123',
    attributes: {
      'plan': 'pro',
      'companyId': 'company-456',
    },
  ),
);

final details = flags.getBooleanDetails(
  key: 'checkout.enabled',
  defaultValue: false,
);

if (details.error == null && details.value) {
  showNewCheckout();
}
```

Call `shutdown()` when a client is no longer needed, or call
`DatadogFlags.instance.disable()` when the application is tearing down the
flags SDK:

```dart
await flags.shutdown();
await DatadogFlags.instance.disable();
```

`shutdown()` drains pending exposure and flag evaluation uploads before clearing
the client's in-memory assignments.

## Configuration

`DatadogFlagsConfig` contains the Datadog identity and routing information used
for precompute and intake requests:

```dart
const DatadogFlagsConfig(
  clientToken: 'pub...',
  env: 'production',
  site: DatadogFlagsSite.us1,
  applicationId: 'rum-application-id',
  service: 'shopping-app',
  version: '1.2.3',
);
```

- `clientToken` is the public Datadog client token used for client-side SDKs.
- `env` is sent as `dd_env` to the precompute assignments API and included in
  flag evaluation intake context.
- `site` selects the Datadog site for both precompute and intake requests. Use
  the site that matches the Datadog organization.
- `applicationId` is optional. When present, intake context includes the RUM
  application ID.
- `service` and `version` are optional intake context fields.

`DatadogFlagsConfiguration` controls SDK behavior:

```dart
DatadogFlagsConfiguration(
  datadogConfig: datadogConfig,
  trackExposures: true,
  trackEvaluations: true,
  evaluationFlushInterval: const Duration(seconds: 10),
  store: myStore,
);
```

- `trackExposures` enables exposure events for assignments marked `doLog`.
- `trackEvaluations` enables aggregated flag evaluation events.
- `evaluationFlushInterval` controls periodic flag evaluation uploads and is
  bounded to 1-60 seconds.
- `store` is optional last-known assignment storage.
- `httpClient` and custom endpoints are available for tests and advanced
  embedding.

If `enable()` is called without a `datadogConfig`, the SDK creates no live
provider. Evaluations still return the caller-provided default with
`FlagEvaluationError.providerNotReady`.

## Evaluation Context

Each client evaluates flags for one current `FlagsEvaluationContext`.

```dart
const FlagsEvaluationContext(
  targetingKey: 'user-123',
  attributes: {
    'companyId': 'company-456',
    'plan': 'enterprise',
    'loggedIn': true,
  },
);
```

`targetingKey` is optional so applications can initialize contexts before a user
or organization ID is known. For the precompute request, a missing targeting key
is sent as an empty string. Targeting attributes must be JSON-compatible values.

Use separate named clients for separate mobile subjects, such as logged-out and
logged-in users or org-level and user-level targeting:

```dart
final orgFlags = datadogFlags.sharedClient(name: 'org');
await orgFlags.initialize(
  const FlagsEvaluationContext(targetingKey: 'org-123'),
);

final userFlags = datadogFlags.sharedClient(name: 'user');
await userFlags.initialize(
  const FlagsEvaluationContext(targetingKey: 'user-456'),
);
```

Clients are local to the Dart isolate where they are created. Background
isolates do not share `DatadogFlags` state or client assignment caches with the
main isolate, so each background isolate must call
`DatadogFlags.instance.enable()`, create the clients it needs, and initialize
them independently.

## Typed Evaluation

The SDK evaluates details for the supported Datadog flag value types:

```dart
final enabled = flags.getBooleanDetails(
  key: 'checkout.enabled',
  defaultValue: false,
);

final title = flags.getStringDetails(
  key: 'checkout.title',
  defaultValue: 'Checkout',
);

final maxItems = flags.getIntegerDetails(
  key: 'checkout.max_items',
  defaultValue: 10,
);

final discount = flags.getDoubleDetails(
  key: 'checkout.discount',
  defaultValue: 0,
);

final config = flags.getObjectDetails(
  key: 'checkout.config',
  defaultValue: const {},
);
```

Every evaluation method requires a caller-provided default. Evaluation methods
do not throw for provider readiness, missing flags, or type mismatches. They
return a `FlagDetails<T>` value:

```dart
final details = flags.getStringDetails(
  key: 'checkout.copy',
  defaultValue: 'Continue',
);

print(details.value);
print(details.variant);
print(details.reason);
print(details.error?.code);
```

`FlagDetails.error` is set when the SDK returns the default because of one of
these conditions:

- `FlagEvaluationError.providerNotReady`: the client has no initialized
  assignment state.
- `FlagEvaluationError.flagNotFound`: the flag key is not present in the
  current assignment state.
- `FlagEvaluationError.typeMismatch`: the assignment value does not match the
  typed evaluation method.

Successful details include the evaluated value plus assignment metadata such as
`variant` and `reason` when Datadog returned it.

## Assignment Fetching and Fallbacks

`initialize(context)` fetches assignments with
`POST /precompute-assignments`. Requests use
`Content-Type: application/vnd.api+json` and `dd-client-token`.
`dd-application-id` is included only when configured.

Assignment fetch and response decoding failures are contained by the SDK. If no
matching stored assignments are available, later evaluations return defaults
with `providerNotReady` or `flagNotFound` details.

Unknown or malformed individual flag assignments are ignored so that one
invalid assignment does not prevent other assignments from loading.

## Exposure Events

A successful typed evaluation emits an exposure event when all of the following
are true:

- `trackExposures` is enabled.
- The assignment has `doLog: true`.
- The same targeting key and flag key have not already emitted the same
  allocation and variant during the client's current lifetime.

If the assignment changes to a different allocation or variant, the next
evaluation emits a new exposure. Pending exposures are uploaded automatically and
are also drained by `shutdown()`.

## Flag Evaluation Events

The SDK records aggregated flag evaluation events for successful evaluations,
defaulted evaluations, and evaluation errors when `trackEvaluations` is
enabled.

Evaluations are aggregated by flag key, assignment metadata, evaluation context,
and error state. The SDK uploads batches on the configured flush interval, when
the batch boundary is reached, and during `shutdown()`.

## Last-Known Assignment Storage

The SDK keeps assignments in memory after `initialize()` succeeds. To restore
last-known assignments across SDK instances, provide a `DatadogFlagsStore`:

```dart
class MyFlagsStore implements DatadogFlagsStore {
  @override
  Future<FlagsData?> read(String clientName) async {
    // Read and decode persisted FlagsData for this client name.
    return null;
  }

  @override
  Future<void> write(String clientName, FlagsData data) async {
    // Encode and persist successful assignments for this client name.
  }

  @override
  Future<void> delete(String clientName) async {
    // Delete persisted assignments for this client name.
  }
}
```

Stored assignments are used only when their evaluation context matches the
active context. A live successful fetch always moves the client to the newest
assignment state and writes that state back to the store.

This package does not choose a disk location or ship a Flutter-specific disk
store. Flutter apps can implement `DatadogFlagsStore` with their preferred app
storage mechanism.

## Reset and Disable

`DatadogFlags.instance.reset()` clears all clients' in-memory assignment state
and deletes stored assignments without shutting down the shared HTTP client.

`DatadogFlags.instance.disable()` shuts down all clients, drains pending
telemetry, closes the shared HTTP client when the SDK created it, clears all
named clients, and returns the SDK to an unconfigured state.

## Examples

This package includes a command-line example:

```bash
DD_CLIENT_TOKEN=<client-token> \
dart run datadog_flags_example:typed_evaluation \
  --env production \
  --site us1 \
  --flag-key checkout.enabled \
  --flag-type boolean \
  --targeting-key user-123 \
  --targeting-attributes '{"companyId":"company-456"}'
```

The repository also includes a Flutter example screen in `examples/simple_example`
that can initialize the SDK, refresh assignments, and evaluate multiple flag
types.
