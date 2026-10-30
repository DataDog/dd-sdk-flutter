# Datadog Flags

`datadog_flags` provides the Datadog OpenFeature provider for Dart and Flutter.
The provider fetches precomputed assignments, evaluates flags locally, and sends
Datadog exposure and evaluation telemetry. It does not use the native iOS or
Android Flags SDKs.

Use OpenFeature as the application API. The legacy Datadog evaluation API is
deprecated and is scheduled for removal in the next major version.

The SDK automatically supports assignment responses with obfuscated flag keys.
Applications continue to evaluate flags with their original keys.
Flag values and telemetry identifiers do not change.

## Requirements

This integration requires Dart 3.10 or later and the published
`openfeature_dart_client_sdk: ^0.0.1` package.

## Initialize and evaluate

```dart
import 'package:datadog_flags/datadog_flags.dart';
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';

final api = OpenFeatureAPI.instance;
await api.setEvaluationContextAndWait(
  EvaluationContext(
    targetingKey: 'user-123',
    attributes: {'plan': 'pro'},
  ),
);
final provider = DatadogOpenFeatureProvider(
  configuration: DatadogFlagsConfiguration(
    datadogConfig: DatadogFlagsConfig(
      clientToken: '<CLIENT_TOKEN>',
      env: 'production',
      site: DatadogFlagsSite.us1,
    ),
  ),
);
final client = api.getClient();
client.addHandler(ProviderEventType.ready, (_) {
  // Reevaluate flags after initial readiness or recovery.
});
try {
  await api.setProviderAndWait(provider);
} on OpenFeatureException {
  // Continue startup with matching cached assignments or defaults.
}
final enabled = client.getBooleanValue('checkout.enabled', false);
final details = client.getStringDetails('checkout.copy', 'Continue');
```

Evaluations are synchronous. OpenFeature handles hooks, events, defaults,
provider registration, and context reconciliation. Use `getBooleanValue`,
`getStringValue`, `getIntegerValue`, `getDoubleValue`, or `getStructureValue`.
Each method also has a corresponding `get...Details` method.

Structure evaluations accept JSON objects (`Map<String, Object?>`). A list or
scalar assignment returns the default with `ErrorCode.typeMismatch`. Failed
evaluations do not emit exposures. Successful structure values are immutable.

Details include the variant, reason, error code, and provider metadata.
The provider sets the metadata keys `datadog.allocation_key` and
`datadog.serial_id`, available as
`DatadogOpenFeatureProvider.allocationKeyMetadata` and `serialIdMetadata`.
These namespaced keys are provider-specific and are not part of the OpenFeature
specification.

## Identity, refresh, and shutdown

```dart
await api.setEvaluationContextAndWait(
  EvaluationContext(targetingKey: 'another-user'),
);
await provider.refresh();
await api.setEvaluationContextAndWait(EvaluationContext.empty); // Sign out.
await api.shutdown();
```

Each provider instance owns one OpenFeature domain. For a named domain, register
with `domain:` and use `getClient(domain)`. Unless `clientName` is supplied,
the provider uses the domain name as its Datadog client name.

A normal context change retains the previous context until the new assignments
are usable. If reconciliation fails, OpenFeature retains the previous active
context. The provider discards late results from that failed reconciliation.
Sign-out retires private assignments immediately, including when anonymous
loading fails. If your application needs assignments cleared immediately on every
identity switch, register a replacement provider.

`refresh()` reloads the active context and emits `configurationChanged` after
success. Refresh failure emits an error and retains usable active assignments.
An unchanged `setEvaluationContextAndWait` call does not trigger a refresh.
The provider does not poll automatically.

Shutdown clears active assignments, cancels pending assignment publication,
and drains pending telemetry. Repeated shutdown is safe. A caller-supplied
HTTP client remains owned by the caller. The provider closes its own client.

## Initialization deadline

`DatadogFlagsConfiguration.initializationTimeout` defaults to five seconds.
The provider requires a positive value of at most 20 seconds. This leaves time
before the default OpenFeature lifecycle deadline of 30 seconds. Applications
using an isolated API with a shorter deadline must choose a smaller budget.

The core budget covers cache loading, the request, decoding, state publication,
and cache storage. Synchronous work can delay timer delivery. The deadline bounds
the caller's wait; it does not cancel the underlying HTTP or store operation.

The provider catches the initialization timeout and reports availability through
OpenFeature events. Matching cached assignments produce `stale`. With no
assignments, registration fails and evaluations return defaults.

If the initial request succeeds after the deadline, the provider emits `ready`
and makes assignments available. The provider publishes assignments before it
writes to the cache, so a slow store cannot hide a successful response.

`stale` means assignments are usable but fresh assignments are unavailable. It
can indicate a pending refresh or a failed refresh.

## Configuration and storage

`DatadogFlagsConfig` contains the client token, environment, site, and optional
application ID, service, and version. The environment is sent as `dd_env`.

`DatadogFlagsConfiguration` supports:

- `customFlagsEndpoint` and `customFlagsHeaders` for assignment transport.
- `httpClient` for an application-owned HTTP client.
- `store` for a `DatadogFlagsStore` implementation.
- `initializationTimeout` for the lifecycle budget described above.
- `trackExposures` and `customExposureEndpoint` for exposure telemetry.
- `trackEvaluations`, `customEvaluationEndpoint`, and `evaluationFlushInterval`
  for evaluation telemetry. The interval must be between 1 and 60 seconds.
  The default is 10 seconds.
- `dateProvider` for application-controlled timestamps.

The store loads a `FlagsData` snapshot only when its context matches the request.
Cache writes and deletes are serialized per store instance and client name.
A store operation that never completes can block later persistence operations.
Implement store operations so they always complete.

Storage adapters must preserve the complete `FlagsData.toJson()` result and
restore it with `FlagsData.fromJson()`. These methods retain the metadata needed
to evaluate obfuscated assignments.

Exposure telemetry follows the assignment's logging policy. Evaluation telemetry
records successes, defaults, and errors. The provider does not implement
OpenFeature `track()`. Do not use it in place of Datadog exposure telemetry.

## Migrate the legacy API

See the [migration guide](MIGRATING.md) for deprecated APIs and their OpenFeature
replacements.

## Cached evaluation reasons

For successful evaluations, details report `CACHED` when the installed assignments
were restored from the configured store, including an in-memory store. After a
network response replaces those assignments, details report the response reason.

## First installed flags

This notification uses the native client API, which is deprecated in favour of OpenFeature. The OpenFeature examples above remain the recommended setup for normal evaluations.

Register after obtaining the client, before or after initializing its context:

```dart
final client = DatadogFlags.instance.sharedClient();
final unregister = client.onFirstFlags((event) {
  print('First installed flags: ${event.flagsChanged}');
  final details = client.getBooleanDetails(
    key: 'checkout.enabled',
    defaultValue: false,
  );
  print(details.value);
});
// Call unregister() when the application no longer needs this notification.
```

The callback receives the keys from the first accepted cache or network
configuration: logical keys for plain configurations, including `[]` when empty,
and `null` when logical keys are unavailable due to obfuscation. Late
registrations receive the same event. Delivery runs in a later microtask;
evaluations in the callback read current flag values. If no usable configuration
is installed, the callback remains pending until you unregister it.

Call the returned function to cancel delivery before the callback starts.
Generate `example/.env` with `melos generate_env`. It copies `DD_CLIENT_TOKEN`
and optional `DD_APPLICATION_ID` from the environment, writes `DD_ENV=prod`,
and omits `DD_SITE`. Edit the generated file to set `DD_ENV` and optional `DD_SITE`.
The CLI loads `.env` over environment variables; `--env` and `--site` override
those values.
Run `dart run bin/first_flags.dart --help` from `example` for its options.
See the [First Flags CLI example](example/bin/first_flags.dart) and
`DatadogFlagsClient.onFirstFlags` API documentation for details.

## Contributing

See the [contributing guide](../../CONTRIBUTING.md) and
[OpenFeature validation instructions](OPENFEATURE_VALIDATION.md).
