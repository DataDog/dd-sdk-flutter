# Datadog Flags

`datadog_flags` provides the Datadog OpenFeature provider for Dart and Flutter.
The provider fetches precomputed assignments, evaluates flags locally, and sends
Datadog exposure and evaluation telemetry. It does not use the native iOS or
Android Flags SDKs.

Use OpenFeature as the application API. The legacy Datadog evaluation API is
deprecated and is scheduled for removal in the next major version.

## Development dependency

This development integration requires **Dart 3.10 or later**. The OpenFeature SDK
and shared provider contract are pinned to development commit
`c57c285590ab87088cdc116cdb804adf6acab2a4`. This commit includes the Dart 3.10 minimum (#168), reconciliation event ordering
(#192), and provider contract v2 (#193).

Use the checked-out package and its example while validation is in progress:

```sh
cd packages/datadog_flags/example
dart pub get
dart run datadog_flags_example:typed_evaluation --help
```

Both Flags packages have `publish_to: none`. Before release, replace the Git
SDK dependency with a compatible hosted release. Validate it on Dart 3.10
without dependency overrides, then remove the publication blocks. The
`publish_dry_run:flags` command rejects the development configuration.

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
`DatadogOpenFeatureProvider.allocationKeyMetadata` and `serialIdMetadata` identify
Datadog assignment metadata. These namespaced keys are provider-specific; they
are not part of the OpenFeature specification.

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
loading fails. Register a replacement provider if the application requires the
same immediate retirement for every identity switch.

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

The provider catches the core timeout and reports availability through
OpenFeature events. Matching cached assignments produce `stale`. With no
assignments, registration fails and evaluations return defaults. Initial late
success emits `ready` and makes assignments available. State publication occurs
before cache persistence, so a slow store cannot hide a successful response.

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
  for evaluation telemetry. The interval is constrained to 1–60 seconds.
- `dateProvider` for application-controlled timestamps.

The store loads a `FlagsData` snapshot only when its context matches the request.
Cache writes and deletes are serialized per store instance and client name.
A store operation that never completes can block later persistence operations.
The application must implement store operations that eventually complete.

Exposure telemetry follows the assignment's logging policy. Evaluation telemetry
records successes, defaults, and errors. OpenFeature `track()` is not implemented;
it must not be used as a replacement for Datadog exposure telemetry.

## Migrate the legacy API

| Deprecated API | OpenFeature replacement |
| --- | --- |
| `DatadogFlags.enable` and `sharedClient` | `setProviderAndWait` and `getClient` |
| `DatadogFlagsClient.initialize` | `setEvaluationContextAndWait` |
| `FlagsEvaluationContext` for evaluation | `EvaluationContext` |
| `FlagDetails` | `FlagEvaluationDetails` |
| `FlagEvaluationError` | `ErrorCode` |
| `getObjectDetails` | `getStructureDetails` for JSON objects |
| `DatadogFlags.disable` | `OpenFeatureAPI.shutdown` |

Configuration and store interfaces remain available. Legacy clients remain
functional during migration. After a legacy client's `shutdown()`, obtain a new
client with `sharedClient()`; the old client cannot be initialized again.

For Flutter RUM, add `DatadogRumHook` from `datadog_flags_flutter` to the
OpenFeature client. Do not initialize the deprecated plugin for the same flags.
Each Dart isolate must create its own OpenFeature API and provider state.

## Validation

The real provider implements the upstream shared contract with controlled HTTP
responses. Run the package suite with `dart test`. Run the browser scenarios with:

```sh
dart test --platform chrome test/datadog_openfeature_provider_test.dart test/shared_contract_test.dart
```

From the repository root, record a reproducible upstream receipt:

```sh
python3 tools/ci/run_openfeature_contract.py --platform vm
python3 tools/ci/run_openfeature_contract.py --platform chrome
```

Receipts are written to `.build/openfeature-evidence`. Controlled transport
results do not establish live Datadog connectivity or maintainer acceptance.
