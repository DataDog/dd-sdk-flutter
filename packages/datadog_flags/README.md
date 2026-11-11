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
final provider = DatadogProvider(
  clientToken: '<CLIENT_TOKEN>',
  env: 'production',
  site: DatadogFlagsSite.us1,
);
final client = api.getClient();
client.addHandler(ProviderEventType.ready, (_) {
  // Reevaluate flags after initial readiness or recovery.
});
try {
  await api.setProviderAndWait(provider);
} on OpenFeatureException {
  // Evaluations return defaults until initial assignments become available.
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
The provider supplies `allocationKey`, `doLog`, `variationType`,
`__dd_allocation_key`, `__dd_do_log`, and an optional `__dd_split_serial_id`.
The provider name is `datadog`. The allocation, logging, and serial keys are
available through `DatadogProvider.allocationKeyMetadata`, `doLogMetadata`,
and `serialIdMetadata`.

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
with `setProviderForDomainAndWait(domain, provider)` and use `getClient(domain)`.
The provider uses the domain name as its Datadog client name, or `default` for
the default domain.

When only targeting attributes change, evaluations retain the previous assignments
while loading or after failure. When the targeting key changes, including sign-out,
evaluations return application defaults until assignments for the new key load.
A missing targeting key and an empty key identify the same subject.
If reconciliation fails, OpenFeature retains the previous active context.
The provider discards late results from that failed reconciliation.

Set the boolean context attribute `dd_strict_evaluation_context_switching: true`
to require matching targeting attributes as well as the targeting key.
Strict mode returns defaults during an attribute change and after a failed fetch.
An unchanged-context refresh keeps assignments while pending, then returns defaults
if loading fails. Retries keep withheld assignments unavailable until a successful
fetch. The control attribute stays local and is excluded from targeting and telemetry.
Only the boolean value `true` enables strict mode.

`refresh()` reloads the committed context and emits `configurationChanged` after
success. By default, failure emits error followed by `stale` and retains usable
assignments. Strict failure emits error and returns defaults until recovery.
Before the first successful load, `refresh()` retries initialization and replaces
any pending initial request. Avoid calling `refresh()` from every error event:
repeated retries can prevent a slow request from completing.
Retry failed context reconciliation through `setEvaluationContextAndWait` before
refreshing. This lets OpenFeature commit the requested context after success.
Each `setEvaluationContextAndWait` call reloads assignments, even when the context
is unchanged. The provider does not poll automatically.

Shutdown clears active assignments, cancels pending assignment publication,
and drains pending telemetry. Repeated shutdown is safe. A caller-supplied
HTTP client remains owned by the caller. The provider closes its own client.

## Initialization deadline

`DatadogFlagsConfiguration.initializationTimeout` defaults to five seconds.
The provider requires a positive value of at most 20 seconds. This leaves time
before the default OpenFeature lifecycle deadline of 30 seconds. Applications
using an isolated API with a shorter deadline must choose a smaller budget.

The provider applies this budget to initialization, each context change, and
each refresh. The core budget covers cache loading, the request, decoding, state publication,
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

Snapshots contain the targeting key and attributes. Context changes and shutdown
do not delete stored snapshots. A successful load for the same client name replaces
the snapshot. To remove stored data, call `delete` on your store with the domain
name, or `default` for the default domain.

OpenFeature `DateTime` attributes become UTC ISO-8601 strings. Non-finite numbers
become `null`. These conversions also apply inside structures and lists.

Exposure telemetry follows the assignment's logging policy. Evaluation telemetry
records successes, defaults, and errors when assignments are active. Evaluations
without active assignments return `ErrorCode.providerNotReady` and are not recorded.
The provider does not implement
OpenFeature `track()`. Do not use it in place of Datadog exposure telemetry.

## Migrate the legacy API

See the [migration guide](MIGRATING.md) for deprecated APIs and their OpenFeature
replacements.

## Cached evaluation reasons

For successful evaluations, details report `CACHED` when the installed assignments
were restored from the configured store, including an in-memory store. After a
network response replaces those assignments, details report the response reason.

## Contributing

See the [contributing guide](../../CONTRIBUTING.md) and
[package contributing guide](CONTRIBUTING.md).
